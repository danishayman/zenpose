import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../models/account_access.dart';
import '../models/admin_user_profile.dart';
import '../models/exercise_definition.dart';
import '../models/exercise_step_definition.dart';
import 'auth_service.dart';

class AdminManagementService {
  final AuthService _authService;

  AdminManagementService({AuthService? authService})
    : _authService = authService ?? AuthService.instance;

  bool get _isConfigured => _authService.isConfigured;

  Future<List<AdminUserProfile>> listUsers({String query = ''}) async {
    _ensureConfigured();
    _ensureAdmin();
    final client = supa.Supabase.instance.client;
    final rows = await client
        .from('user_profiles')
        .select()
        .order('created_at', ascending: false);
    final profiles = (rows as List<dynamic>)
        .map((row) => AdminUserProfile.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return profiles;
    return profiles.where((profile) {
      final email = profile.email.toLowerCase();
      final displayName = profile.displayName?.toLowerCase() ?? '';
      return email.contains(q) || displayName.contains(q);
    }).toList(growable: false);
  }

  Future<void> updateUserAccess({
    required String userId,
    required AccountRole role,
    required AccountStatus status,
  }) async {
    _ensureConfigured();
    _ensureAdmin();
    final client = supa.Supabase.instance.client;
    await client.rpc(
      'admin_update_user_profile',
      params: <String, Object?>{
        'target_user_id': userId,
        'new_role': role.dbValue,
        'new_status': status.dbValue,
      },
    );
  }

  Future<List<ExerciseDefinition>> listExercises({bool activeOnly = false}) async {
    _ensureConfigured();
    final client = supa.Supabase.instance.client;
    var query = client
        .from('exercises')
        .select('''
          id,
          name,
          description,
          is_active,
          created_by,
          created_at,
          updated_at,
          exercise_steps (
            step_index,
            pose_name,
            hold_seconds,
            rest_seconds,
            updated_at
          )
        ''');
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    final rows = await query.order('updated_at', ascending: false);
    final exercises = (rows as List<dynamic>)
        .map((row) => ExerciseDefinition.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
    return exercises;
  }

  Future<ExerciseDefinition> upsertExercise(ExerciseDefinition draft) async {
    _ensureConfigured();
    _ensureAdmin();
    _validateExerciseDraft(draft);

    final client = supa.Supabase.instance.client;
    final userId = _authService.authState.value.userId;
    if (userId == null || userId.trim().isEmpty) {
      throw StateError('Missing authenticated user context.');
    }

    String exerciseId = draft.id ?? '';
    if (exerciseId.trim().isEmpty) {
      final inserted = await client
          .from('exercises')
          .insert(draft.toExerciseMutationMap(currentUserId: userId))
          .select('id')
          .single();
      exerciseId = inserted['id'].toString();
    } else {
      await client
          .from('exercises')
          .update(draft.toExerciseMutationMap(currentUserId: userId))
          .eq('id', exerciseId);
    }

    await client.from('exercise_steps').delete().eq('exercise_id', exerciseId);
    await client.from('exercise_steps').insert([
      for (final step in _normalizedSteps(draft.steps))
        step.toInsertMap(exerciseId: exerciseId),
    ]);

    final refreshedRows = await client
        .from('exercises')
        .select('''
          id,
          name,
          description,
          is_active,
          created_by,
          created_at,
          updated_at,
          exercise_steps (
            step_index,
            pose_name,
            hold_seconds,
            rest_seconds,
            updated_at
          )
        ''')
        .eq('id', exerciseId)
        .single();
    return ExerciseDefinition.fromMap(Map<String, dynamic>.from(refreshedRows));
  }

  Future<void> deleteExercise(String exerciseId) async {
    _ensureConfigured();
    _ensureAdmin();
    await supa.Supabase.instance.client
        .from('exercises')
        .delete()
        .eq('id', exerciseId);
  }

  List<ExerciseStepDefinition> _normalizedSteps(List<ExerciseStepDefinition> steps) {
    return <ExerciseStepDefinition>[
      for (var i = 0; i < steps.length; i++)
        steps[i].copyWith(stepIndex: i, poseName: steps[i].poseName.trim()),
    ];
  }

  void _validateExerciseDraft(ExerciseDefinition draft) {
    final name = draft.name.trim();
    if (name.isEmpty) {
      throw StateError('Exercise name is required.');
    }
    if (draft.steps.isEmpty) {
      throw StateError('Exercise must have at least one step.');
    }
    final normalized = _normalizedSteps(draft.steps);
    for (var i = 0; i < normalized.length; i++) {
      final step = normalized[i];
      if (step.stepIndex != i) {
        throw StateError('Step order is invalid.');
      }
      if (step.poseName.trim().isEmpty) {
        throw StateError('Step ${i + 1} pose is required.');
      }
      if (step.holdSeconds <= 0) {
        throw StateError('Step ${i + 1} hold seconds must be > 0.');
      }
      if (step.restSeconds < 0) {
        throw StateError('Step ${i + 1} rest seconds must be >= 0.');
      }
    }
  }

  void _ensureConfigured() {
    if (!_isConfigured) {
      throw StateError('Supabase is not configured.');
    }
  }

  void _ensureAdmin() {
    final authState = _authService.authState.value;
    if (!authState.isAdmin || !authState.isAccountActive) {
      throw StateError('Admin privileges are required.');
    }
  }
}
