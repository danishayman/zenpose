import 'package:flutter/material.dart';

import '../models/account_access.dart';
import '../models/admin_user_profile.dart';
import '../models/exercise_definition.dart';
import '../models/exercise_step_definition.dart';
import '../models/pose_template.dart';
import '../services/admin_management_service.dart';
import '../services/auth_service.dart';
import '../services/pose_template_service.dart';
import '../theme/zen_theme.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final AdminManagementService _adminService = AdminManagementService();
  final PoseTemplateService _poseTemplateService = PoseTemplateService();
  final AuthService _authService = AuthService.instance;
  final TextEditingController _userSearchController = TextEditingController();

  List<AdminUserProfile> _users = const <AdminUserProfile>[];
  List<ExerciseDefinition> _exercises = const <ExerciseDefinition>[];
  List<PoseTemplate> _poseTemplates = const <PoseTemplate>[];
  bool _loadingUsers = true;
  bool _loadingExercises = true;
  String? _usersError;
  String? _exercisesError;

  @override
  void initState() {
    super.initState();
    _userSearchController.addListener(() {
      _loadUsers(query: _userSearchController.text);
    });
    _loadPoseTemplates();
    _loadUsers();
    _loadExercises();
  }

  @override
  void dispose() {
    _userSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadPoseTemplates() async {
    try {
      final templates = await _poseTemplateService.loadTemplates();
      if (!mounted) return;
      setState(() => _poseTemplates = templates);
    } catch (_) {
      // Keep templates optional for admin editor fallback.
    }
  }

  Future<void> _loadUsers({String query = ''}) async {
    if (!_authService.isConfigured || !_authService.authState.value.isAdmin) {
      if (!mounted) return;
      setState(() {
        _loadingUsers = false;
        _users = const <AdminUserProfile>[];
      });
      return;
    }

    setState(() {
      _loadingUsers = true;
      _usersError = null;
    });
    try {
      final users = await _adminService.listUsers(query: query);
      if (!mounted) return;
      setState(() => _users = users);
    } catch (error) {
      if (!mounted) return;
      setState(() => _usersError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _loadExercises() async {
    if (!_authService.isConfigured || !_authService.authState.value.isAdmin) {
      if (!mounted) return;
      setState(() {
        _loadingExercises = false;
        _exercises = const <ExerciseDefinition>[];
      });
      return;
    }

    setState(() {
      _loadingExercises = true;
      _exercisesError = null;
    });
    try {
      final exercises = await _adminService.listExercises();
      if (!mounted) return;
      setState(() => _exercises = exercises);
    } catch (error) {
      if (!mounted) return;
      setState(() => _exercisesError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingExercises = false);
    }
  }

  Future<void> _updateUser(
    AdminUserProfile user, {
    AccountRole? role,
    AccountStatus? status,
  }) async {
    try {
      await _adminService.updateUserAccess(
        userId: user.userId,
        role: role ?? user.role,
        status: status ?? user.status,
      );
      if (!mounted) return;
      await _loadUsers(query: _userSearchController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User access updated.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update user: $error')));
    }
  }

  Future<void> _openExerciseEditor({ExerciseDefinition? initial}) async {
    final poseNames = _poseTemplates
        .map((template) => template.name)
        .toSet()
        .toList(growable: false)
      ..sort();
    final result = await showDialog<ExerciseDefinition>(
      context: context,
      builder: (_) => _ExerciseEditorDialog(initial: initial, poseNames: poseNames),
    );
    if (result == null) return;
    try {
      await _adminService.upsertExercise(result);
      if (!mounted) return;
      await _loadExercises();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            initial == null ? 'Exercise created.' : 'Exercise updated.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save exercise: $error')),
      );
    }
  }

  Future<void> _deleteExercise(ExerciseDefinition exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Exercise'),
        content: Text(
          'Delete "${exercise.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _adminService.deleteExercise(exercise.id ?? '');
      if (!mounted) return;
      await _loadExercises();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Exercise deleted.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete exercise: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = _authService.authState.value;
    if (!_authService.isConfigured) {
      return _buildInfoCard(
        title: 'Admin Unavailable',
        message: 'Supabase is not configured for this build.',
      );
    }
    if (!auth.isAdmin) {
      return _buildInfoCard(
        title: 'Admin Access Required',
        message: 'Your account does not have admin privileges.',
      );
    }

    return SafeArea(
      bottom: false,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Admin', style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Manage users and pose-based exercises.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: ZenColors.surface1,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const TabBar(
                      indicatorColor: ZenColors.teal,
                      labelColor: ZenColors.textPrimary,
                      unselectedLabelColor: ZenColors.textMuted,
                      tabs: [
                        Tab(text: 'Users'),
                        Tab(text: 'Exercises'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildUsersTab(),
                  _buildExercisesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({required String title, required String message}) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          decoration: ZenDecor.elevatedCard(),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    return RefreshIndicator(
      onRefresh: () => _loadUsers(query: _userSearchController.text),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [
          TextField(
            controller: _userSearchController,
            decoration: const InputDecoration(
              hintText: 'Search users by email or display name',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 14),
          if (_loadingUsers)
            const Center(child: CircularProgressIndicator())
          else if (_usersError != null)
            _ErrorCard(
              message: _usersError!,
              onRetry: () => _loadUsers(query: _userSearchController.text),
            )
          else if (_users.isEmpty)
            const _EmptyCard(message: 'No users found.')
          else
            ..._users.map(_buildUserCard),
        ],
      ),
    );
  }

  Widget _buildUserCard(AdminUserProfile user) {
    final selfId = _authService.authState.value.userId;
    final isSelf = selfId != null && selfId == user.userId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: ZenDecor.elevatedCard(),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.displayName?.trim().isNotEmpty == true
                  ? user.displayName!.trim()
                  : user.email,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(user.email, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<AccountRole>(
                    value: user.role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(
                        value: AccountRole.user,
                        child: Text('User'),
                      ),
                      DropdownMenuItem(
                        value: AccountRole.admin,
                        child: Text('Admin'),
                      ),
                    ],
                    onChanged: isSelf
                        ? null
                        : (value) {
                            if (value == null || value == user.role) return;
                            _updateUser(user, role: value);
                          },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<AccountStatus>(
                    value: user.status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(
                        value: AccountStatus.active,
                        child: Text('Active'),
                      ),
                      DropdownMenuItem(
                        value: AccountStatus.inactive,
                        child: Text('Inactive'),
                      ),
                    ],
                    onChanged: isSelf
                        ? null
                        : (value) {
                            if (value == null || value == user.status) return;
                            _updateUser(user, status: value);
                          },
                  ),
                ),
              ],
            ),
            if (isSelf) ...[
              const SizedBox(height: 8),
              Text(
                'Current account (self role/status changes are blocked).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ZenColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExercisesTab() {
    return RefreshIndicator(
      onRefresh: _loadExercises,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [
          ElevatedButton.icon(
            onPressed: () => _openExerciseEditor(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Exercise'),
          ),
          const SizedBox(height: 14),
          if (_loadingExercises)
            const Center(child: CircularProgressIndicator())
          else if (_exercisesError != null)
            _ErrorCard(message: _exercisesError!, onRetry: _loadExercises)
          else if (_exercises.isEmpty)
            const _EmptyCard(message: 'No exercises yet. Add your first one.')
          else
            ..._exercises.map(_buildExerciseCard),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(ExerciseDefinition exercise) {
    final stepSummary = exercise.steps
        .map((step) => '${step.stepIndex + 1}. ${step.poseName}')
        .join('  •  ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: ZenDecor.elevatedCard(),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: exercise.isActive
                        ? ZenColors.successLight
                        : ZenColors.surface2,
                  ),
                  child: Text(
                    exercise.isActive ? 'Active' : 'Inactive',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: exercise.isActive
                          ? ZenColors.success
                          : ZenColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (exercise.description.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                exercise.description.trim(),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${exercise.steps.length} steps',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              stepSummary,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openExerciseEditor(initial: exercise),
                    child: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _deleteExercise(exercise),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ZenColors.error,
                    ),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseEditorDialog extends StatefulWidget {
  final ExerciseDefinition? initial;
  final List<String> poseNames;

  const _ExerciseEditorDialog({required this.initial, required this.poseNames});

  @override
  State<_ExerciseEditorDialog> createState() => _ExerciseEditorDialogState();
}

class _ExerciseEditorDialogState extends State<_ExerciseEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late bool _isActive;
  late List<ExerciseStepDefinition> _steps;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _isActive = initial?.isActive ?? true;
    _steps = initial?.steps.isNotEmpty == true
        ? List<ExerciseStepDefinition>.from(initial!.steps)
        : <ExerciseStepDefinition>[
            ExerciseStepDefinition(
              stepIndex: 0,
              poseName: widget.poseNames.isNotEmpty ? widget.poseNames.first : '',
              holdSeconds: 20,
              restSeconds: 30,
              updatedAt: null,
            ),
          ];
    _normalizeSteps();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _normalizeSteps() {
    _steps = <ExerciseStepDefinition>[
      for (var i = 0; i < _steps.length; i++) _steps[i].copyWith(stepIndex: i),
    ];
  }

  void _moveStep(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _steps.length) return;
    final reordered = List<ExerciseStepDefinition>.from(_steps);
    final moving = reordered.removeAt(index);
    reordered.insert(target, moving);
    setState(() {
      _steps = reordered;
      _normalizeSteps();
    });
  }

  void _removeStep(int index) {
    if (_steps.length <= 1) {
      setState(() => _error = 'Exercise must contain at least one step.');
      return;
    }
    setState(() {
      _steps = List<ExerciseStepDefinition>.from(_steps)..removeAt(index);
      _normalizeSteps();
    });
  }

  void _addStep() {
    setState(() {
      _steps = List<ExerciseStepDefinition>.from(_steps)
        ..add(
          ExerciseStepDefinition(
            stepIndex: _steps.length,
            poseName: widget.poseNames.isNotEmpty ? widget.poseNames.first : '',
            holdSeconds: 20,
            restSeconds: 30,
            updatedAt: null,
          ),
        );
      _normalizeSteps();
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Exercise name is required.');
      return;
    }
    if (_steps.isEmpty) {
      setState(() => _error = 'Exercise must contain at least one step.');
      return;
    }
    final hasEmptyPose = _steps.any((step) => step.poseName.trim().isEmpty);
    if (hasEmptyPose) {
      setState(() => _error = 'Each step must include a pose.');
      return;
    }
    final hasInvalidHold = _steps.any((step) => step.holdSeconds <= 0);
    if (hasInvalidHold) {
      setState(() => _error = 'Hold seconds must be greater than zero.');
      return;
    }
    final hasInvalidRest = _steps.any((step) => step.restSeconds < 0);
    if (hasInvalidRest) {
      setState(() => _error = 'Rest seconds must be zero or greater.');
      return;
    }

    final model = ExerciseDefinition(
      id: widget.initial?.id,
      name: name,
      description: _descriptionController.text.trim(),
      isActive: _isActive,
      createdBy: widget.initial?.createdBy,
      createdAt: widget.initial?.createdAt,
      updatedAt: widget.initial?.updatedAt,
      steps: _steps,
    );
    Navigator.of(context).pop(model);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.initial == null ? 'Create Exercise' : 'Edit Exercise';
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Exercise name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: const Text('Only active exercises are used by users.'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Steps', style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addStep,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Step'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ..._steps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                final availablePoses = widget.poseNames.isNotEmpty
                    ? widget.poseNames
                    : <String>[step.poseName];
                final selectedPose = availablePoses.contains(step.poseName)
                    ? step.poseName
                    : availablePoses.first;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ZenColors.surface0,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ZenColors.surface2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Step ${index + 1}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: index == 0 ? null : () => _moveStep(index, -1),
                              icon: const Icon(Icons.arrow_upward_rounded),
                              tooltip: 'Move up',
                            ),
                            IconButton(
                              onPressed: index == _steps.length - 1
                                  ? null
                                  : () => _moveStep(index, 1),
                              icon: const Icon(Icons.arrow_downward_rounded),
                              tooltip: 'Move down',
                            ),
                            IconButton(
                              onPressed: () => _removeStep(index),
                              icon: const Icon(Icons.delete_outline_rounded),
                              tooltip: 'Delete step',
                            ),
                          ],
                        ),
                        DropdownButtonFormField<String>(
                          value: selectedPose.isEmpty ? null : selectedPose,
                          decoration: const InputDecoration(labelText: 'Pose'),
                          items: availablePoses
                              .map(
                                (pose) => DropdownMenuItem(
                                  value: pose,
                                  child: Text(pose),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _steps[index] = _steps[index].copyWith(
                                poseName: value,
                              );
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _IntStepperField(
                                label: 'Hold (s)',
                                value: step.holdSeconds,
                                min: 1,
                                onChanged: (next) {
                                  setState(() {
                                    _steps[index] = _steps[index].copyWith(
                                      holdSeconds: next,
                                    );
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _IntStepperField(
                                label: 'Rest (s)',
                                value: step.restSeconds,
                                min: 0,
                                onChanged: (next) {
                                  setState(() {
                                    _steps[index] = _steps[index].copyWith(
                                      restSeconds: next,
                                    );
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: const TextStyle(color: ZenColors.error, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _IntStepperField extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  const _IntStepperField({
    required this.label,
    required this.value,
    required this.min,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZenColors.surface1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ZenColors.surface2),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: value <= min ? null : () => onChanged(value - 1),
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                onPressed: () => onChanged(value + 1),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;

  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ZenDecor.elevatedCard(),
      padding: const EdgeInsets.all(16),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ZenDecor.elevatedCard(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Failed to load data',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(message, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextButton(onPressed: () => onRetry(), child: const Text('Retry')),
        ],
      ),
    );
  }
}
