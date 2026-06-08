import '../models/workout_guidance_snapshot.dart';

/// Computes a stable per-frame workout guidance state for the UI.
class WorkoutGuidanceService {
  final Duration lostTrackingGrace;
  final double enterHoldDelta;
  final double exitHoldDelta;
  final Duration stateMinDwell;
  final Duration unstableDebounce;
  final Duration cueMinDisplayDuration;
  final int maxVisualCues;

  DateTime? _lastPoseSeenAt;
  double _lastScore = 0;
  double _lastHoldProgress = 0;
  bool _resetIssuedForCurrentLoss = false;

  WorkoutGuidanceState _state = WorkoutGuidanceState.initializing;
  DateTime? _stateChangedAt;
  DateTime? _holdCandidateSince;
  DateTime? _unstableSince;
  DateTime? _stableSince;

  String? _activeCue;
  DateTime? _activeCueSince;
  int _activeCuePriority = 99;

  final Map<String, _CueMemory> _recentCueByTarget = <String, _CueMemory>{};
  static const Duration _contradictionWindow = Duration(milliseconds: 1500);

  WorkoutGuidanceService({
    this.lostTrackingGrace = const Duration(seconds: 2),
    this.enterHoldDelta = 3.0,
    this.exitHoldDelta = 5.0,
    this.stateMinDwell = const Duration(milliseconds: 350),
    this.unstableDebounce = const Duration(milliseconds: 280),
    this.cueMinDisplayDuration = const Duration(milliseconds: 1200),
    this.maxVisualCues = 1,
  });

  WorkoutGuidanceSnapshot evaluate({
    required bool cameraReady,
    required bool hasPose,
    required bool poseStable,
    required bool poseCompleted,
    required double score,
    required double holdProgress,
    required double scoreThreshold,
    required List<String> feedbackMessages,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final normalizedScore = score.clamp(0.0, 100.0).toDouble();
    final normalizedHold = holdProgress.clamp(0.0, 1.0).toDouble();
    final cleanedFeedback = feedbackMessages
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toList(growable: false);
    _pruneCueMemory(at);

    if (!cameraReady) {
      _transitionState(
        WorkoutGuidanceState.initializing,
        at,
        enforceDwell: false,
      );
      _clearCueState();
      return const WorkoutGuidanceSnapshot.initializing();
    }

    if (poseCompleted) {
      _lastScore = normalizedScore;
      _lastHoldProgress = normalizedHold;
      _transitionState(WorkoutGuidanceState.completed, at, enforceDwell: false);
      _clearCueState();
      return WorkoutGuidanceSnapshot(
        score: normalizedScore,
        holdProgress: normalizedHold,
        state: WorkoutGuidanceState.completed,
        primaryCue: null,
        secondaryCue: null,
        shouldResetSession: false,
      );
    }

    if (hasPose) {
      _lastPoseSeenAt = at;
      _resetIssuedForCurrentLoss = false;
      _lastScore = normalizedScore;
      _lastHoldProgress = normalizedHold;

      _updateStabilityTimers(poseStable, at);

      final unstableConfirmed = _isUnstableConfirmed(at);
      final stableConfirmed = _isStableConfirmed(at);

      if (unstableConfirmed) {
        _holdCandidateSince = null;
        _transitionState(
          WorkoutGuidanceState.unstablePose,
          at,
          enforceDwell: false,
        );
      } else if (_state == WorkoutGuidanceState.unstablePose &&
          !stableConfirmed) {
        // Keep the unstable state latched until stability is sustained.
      } else {
        final canEnterHolding =
            poseStable &&
            normalizedScore >= scoreThreshold + enterHoldDelta &&
            normalizedHold > 0;

        if (_state == WorkoutGuidanceState.holding) {
          final shouldExitHolding =
              normalizedScore < scoreThreshold - exitHoldDelta ||
              (!poseStable && _isUnstableConfirmed(at));
          if (shouldExitHolding) {
            _holdCandidateSince = null;
            _transitionState(
              WorkoutGuidanceState.aligning,
              at,
              enforceDwell: true,
            );
          }
        } else if (canEnterHolding) {
          _holdCandidateSince ??= at;
          final holdCandidateReady =
              at.difference(_holdCandidateSince!) >= stateMinDwell;
          if (holdCandidateReady) {
            _transitionState(
              WorkoutGuidanceState.holding,
              at,
              enforceDwell: false,
            );
          } else {
            _transitionState(
              WorkoutGuidanceState.aligning,
              at,
              enforceDwell: true,
            );
          }
        } else {
          _holdCandidateSince = null;
          _transitionState(
            WorkoutGuidanceState.aligning,
            at,
            enforceDwell: true,
          );
        }
      }

      if (_state == WorkoutGuidanceState.unstablePose) {
        final selected = _selectCue(
          cue: 'Hold still',
          priority: 0,
          at: at,
          safetyCue: true,
        );
        return WorkoutGuidanceSnapshot(
          score: normalizedScore,
          holdProgress: normalizedHold,
          state: WorkoutGuidanceState.unstablePose,
          primaryCue: selected,
          secondaryCue: null,
          shouldResetSession: false,
        );
      }

      if (_activeCuePriority == 0) {
        _clearCueState();
      }
      final rankedFeedback = _rankFeedback(cleanedFeedback, at);
      final selectedPrimary = maxVisualCues <= 0
          ? null
          : _selectFeedbackCue(rankedFeedback, at: at);
      final secondary = maxVisualCues > 1 && rankedFeedback.length > 1
          ? rankedFeedback[1].message
          : null;

      return WorkoutGuidanceSnapshot(
        score: normalizedScore,
        holdProgress: normalizedHold,
        state: _state == WorkoutGuidanceState.initializing
            ? WorkoutGuidanceState.aligning
            : _state,
        primaryCue: selectedPrimary,
        secondaryCue: secondary,
        shouldResetSession: false,
      );
    }

    final graceExpired =
        _lastPoseSeenAt == null ||
        at.difference(_lastPoseSeenAt!) > lostTrackingGrace;
    if (graceExpired) {
      _lastScore = 0;
      _lastHoldProgress = 0;
    }
    _holdCandidateSince = null;
    _unstableSince = null;
    _stableSince = null;
    _transitionState(
      WorkoutGuidanceState.noUserDetected,
      at,
      enforceDwell: false,
    );
    final shouldReset = graceExpired && !_resetIssuedForCurrentLoss;
    if (shouldReset) {
      _resetIssuedForCurrentLoss = true;
    }
    final selected = _selectCue(
      cue: 'Step into frame',
      priority: 0,
      at: at,
      safetyCue: true,
    );

    return WorkoutGuidanceSnapshot(
      score: graceExpired ? 0 : _lastScore,
      holdProgress: graceExpired ? 0 : _lastHoldProgress,
      state: WorkoutGuidanceState.noUserDetected,
      primaryCue: selected,
      secondaryCue: null,
      shouldResetSession: shouldReset,
    );
  }

  void reset() {
    _lastPoseSeenAt = null;
    _lastScore = 0;
    _lastHoldProgress = 0;
    _resetIssuedForCurrentLoss = false;
    _state = WorkoutGuidanceState.initializing;
    _stateChangedAt = null;
    _holdCandidateSince = null;
    _unstableSince = null;
    _stableSince = null;
    _clearCueState();
    _recentCueByTarget.clear();
  }

  void _updateStabilityTimers(bool poseStable, DateTime at) {
    if (poseStable) {
      _stableSince ??= at;
      _unstableSince = null;
      return;
    }
    _unstableSince ??= at;
    _stableSince = null;
  }

  bool _isUnstableConfirmed(DateTime at) =>
      _unstableSince != null &&
      at.difference(_unstableSince!) >= unstableDebounce;

  bool _isStableConfirmed(DateTime at) =>
      _stableSince != null && at.difference(_stableSince!) >= unstableDebounce;

  void _transitionState(
    WorkoutGuidanceState next,
    DateTime at, {
    required bool enforceDwell,
  }) {
    if (_state == next) return;
    if (enforceDwell &&
        _stateChangedAt != null &&
        at.difference(_stateChangedAt!) < stateMinDwell) {
      return;
    }
    _state = next;
    _stateChangedAt = at;
  }

  String? _selectCue({
    required String? cue,
    required int priority,
    required DateTime at,
    required bool safetyCue,
  }) {
    if (cue == null || cue.isEmpty) {
      _clearCueState();
      return null;
    }

    if (_activeCue == null) {
      _setActiveCue(cue, priority, at);
      return cue;
    }
    if (_activeCue == cue) {
      _activeCuePriority = priority;
      return cue;
    }

    final activeAge = _activeCueSince == null
        ? cueMinDisplayDuration
        : at.difference(_activeCueSince!);
    final shouldOverride = safetyCue || priority < _activeCuePriority;
    if (!shouldOverride && activeAge < cueMinDisplayDuration) {
      return _activeCue;
    }

    _setActiveCue(cue, priority, at);
    return cue;
  }

  String? _selectFeedbackCue(
    List<_CueCandidate> rankedFeedback, {
    required DateTime at,
  }) {
    if (rankedFeedback.isEmpty) {
      return _selectCue(cue: null, priority: 99, at: at, safetyCue: false);
    }

    final activeCue = _activeCue;
    final activeAge = _activeCueSince == null
        ? cueMinDisplayDuration
        : at.difference(_activeCueSince!);
    if (activeCue != null && activeAge < cueMinDisplayDuration) {
      final activeCandidate = _candidateForCue(rankedFeedback, activeCue);
      final bestCandidate = rankedFeedback.first;
      if (activeCandidate != null &&
          bestCandidate.priority >= activeCandidate.priority) {
        return activeCue;
      }
    }

    final activeTarget = activeCue == null ? null : _parseCue(activeCue).target;
    final chosen = activeTarget == null
        ? rankedFeedback.first
        : rankedFeedback.firstWhere(
            (candidate) => _parseCue(candidate.message).target != activeTarget,
            orElse: () => rankedFeedback.first,
          );

    return _selectCue(
      cue: chosen.message,
      priority: chosen.priority,
      at: at,
      safetyCue: false,
    );
  }

  _CueCandidate? _candidateForCue(List<_CueCandidate> candidates, String cue) {
    for (final candidate in candidates) {
      if (candidate.message == cue) return candidate;
    }
    return null;
  }

  void _setActiveCue(String cue, int priority, DateTime at) {
    _activeCue = cue;
    _activeCuePriority = priority;
    _activeCueSince = at;
    final parsed = _parseCue(cue);
    if (parsed.target != null && parsed.action != null) {
      _recentCueByTarget[parsed.target!] = _CueMemory(
        action: parsed.action!,
        at: at,
      );
    }
  }

  void _clearCueState() {
    _activeCue = null;
    _activeCueSince = null;
    _activeCuePriority = 99;
  }

  List<_CueCandidate> _rankFeedback(List<String> feedback, DateTime at) {
    final deduped = <String>{};
    final ranked = <_CueCandidate>[];
    for (var index = 0; index < feedback.length; index++) {
      final message = feedback[index];
      final normalized = message.trim().toLowerCase();
      if (normalized.isEmpty || deduped.contains(normalized)) continue;
      deduped.add(normalized);

      final parsed = _parseCue(message);
      if (_isContradictingRecent(parsed, at)) continue;
      ranked.add(
        _CueCandidate(
          message: message,
          priority: _priorityForMessage(normalized),
          sourceIndex: index,
        ),
      );
    }
    ranked.sort((a, b) {
      return a.sourceIndex.compareTo(b.sourceIndex);
    });
    return ranked;
  }

  bool _isContradictingRecent(_ParsedCue cue, DateTime at) {
    final target = cue.target;
    final action = cue.action;
    if (target == null || action == null) return false;
    final previous = _recentCueByTarget[target];
    if (previous == null) return false;
    final recentEnough = at.difference(previous.at) < _contradictionWindow;
    return recentEnough && _isOppositeAction(previous.action, action);
  }

  void _pruneCueMemory(DateTime at) {
    final staleKeys = _recentCueByTarget.entries
        .where((entry) => at.difference(entry.value.at) > _contradictionWindow)
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final key in staleKeys) {
      _recentCueByTarget.remove(key);
    }
  }

  bool _isOppositeAction(String a, String b) {
    const opposite = <String, String>{
      'raise': 'lower',
      'lower': 'raise',
      'straighten': 'bend',
      'bend': 'straighten',
      'open': 'close',
      'close': 'open',
    };
    return opposite[a] == b;
  }

  int _priorityForMessage(String normalized) {
    if (normalized.contains('elbow') || normalized.contains('knee')) {
      return 1;
    }
    if (normalized.contains('torso') ||
        normalized.contains('shoulder') ||
        normalized.contains('hip')) {
      return 2;
    }
    if (normalized.contains('arm') ||
        normalized.contains('leg') ||
        normalized.contains('wrist') ||
        normalized.contains('ankle')) {
      return 3;
    }
    return 4;
  }

  _ParsedCue _parseCue(String message) {
    final normalized = message.toLowerCase();

    String? action;
    if (normalized.contains('raise')) action = 'raise';
    if (normalized.contains('lower')) action = 'lower';
    if (normalized.contains('straighten')) action = 'straighten';
    if (normalized.contains('bend')) action = 'bend';
    if (normalized.contains('open')) action = 'open';
    if (normalized.contains('close')) action = 'close';

    String? target;
    if (normalized.contains('left arm')) target = 'left arm';
    if (normalized.contains('right arm')) target = 'right arm';
    if (normalized.contains('left elbow')) target = 'left elbow';
    if (normalized.contains('right elbow')) target = 'right elbow';
    if (normalized.contains('left leg')) target = 'left leg';
    if (normalized.contains('right leg')) target = 'right leg';
    if (normalized.contains('left knee')) target = 'left knee';
    if (normalized.contains('right knee')) target = 'right knee';
    if (normalized.contains('left shoulder')) target = 'left shoulder';
    if (normalized.contains('right shoulder')) target = 'right shoulder';
    if (normalized.contains('left hip')) target = 'left hip';
    if (normalized.contains('right hip')) target = 'right hip';
    if (normalized.contains('torso')) target = 'torso';

    return _ParsedCue(action: action, target: target);
  }
}

class _CueCandidate {
  final String message;
  final int priority;
  final int sourceIndex;

  const _CueCandidate({
    required this.message,
    required this.priority,
    required this.sourceIndex,
  });
}

class _CueMemory {
  final String action;
  final DateTime at;

  const _CueMemory({required this.action, required this.at});
}

class _ParsedCue {
  final String? action;
  final String? target;

  const _ParsedCue({required this.action, required this.target});
}
