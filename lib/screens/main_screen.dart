import 'dart:async';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/pose_frame.dart';
import '../models/pose_result.dart';
import '../models/challenge_step_result.dart';
import '../models/unlocked_badge.dart';
import '../models/pose_session_config.dart';
import '../models/pose_template.dart';
import '../models/punishment_models.dart';
import '../models/workout_guidance_snapshot.dart';
import '../services/angle_calculation_service.dart';
import '../services/camera_service.dart';
import '../services/landmark_smoothing_service.dart';
import '../services/pose_normalization_service.dart';
import '../services/cosine_similarity_service.dart';
import '../services/pose_distance_similarity_service.dart';
import '../services/limb_similarity_service.dart';
import '../services/pose_correction_service.dart';
import '../services/pose_detection_service.dart';
import '../services/pose_form_gate_service.dart';
import '../services/pose_hold_eligibility_service.dart';
import '../services/pose_mirror_service.dart';
import '../services/pose_session_service.dart';
import '../services/pose_stability_service.dart';
import '../services/score_smoothing_service.dart';
import '../services/workout_guidance_service.dart';
import '../services/voice_cue_service.dart';
import '../services/voice_instruction_composer.dart';
import '../models/landmark.dart';
import '../painters/skeleton_overlay_painter.dart';
import '../services/database_service.dart';
import '../services/gamification_service.dart';
import '../services/punishment_service.dart';
import '../theme/zen_theme.dart';
import '../widgets/rank_up_dialog.dart';
import '../widgets/workout_session_widgets.dart';
import '../widgets/xp_deduction_dialog.dart';

/// MainScreen composes the camera preview and skeleton overlay.
///
/// It orchestrates:
///  1. Camera initialisation and image streaming via [CameraService].
///  2. Pose detection on each frame via [PoseDetectionService].
///  3. Overlay rendering via [SkeletonOverlayPainter] on a [CustomPaint].
///  4. Lifecycle management (pause / resume camera on app state changes).
///
/// Receives a [PoseTemplate] from the Pose Selection Screen.  The template's
/// [PoseTemplate.meanVector] is used as the reference vector for cosine
/// similarity scoring — replacing the old hardcoded reference.
class MainScreen extends StatefulWidget {
  /// The yoga pose the user selected from the Pose Library.
  /// Its [meanVector] is fed to [CosineSimilarityService] as the target.
  final PoseTemplate poseTemplate;
  final PoseSessionConfig? sessionConfig;
  final String? completionActionLabel;
  final bool returnResultOnCompletion;

  const MainScreen({
    super.key,
    required this.poseTemplate,
    this.sessionConfig,
    this.completionActionLabel,
    this.returnResultOnCompletion = false,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  // ── Services ──────────────────────────────────────────────────────────────

  final CameraService _cameraService = CameraService();
  final PoseDetectionService _poseDetectionService = PoseDetectionService();
  final AngleCalculationService _angleService = AngleCalculationService();
  final LandmarkSmoothingService _smoothingService = LandmarkSmoothingService();
  final PoseNormalizationService _normalizationService =
      PoseNormalizationService();
  final PoseCorrectionService _poseCorrectionService = PoseCorrectionService();
  final PoseDistanceSimilarityService _distanceSimilarityService =
      PoseDistanceSimilarityService();
  final PoseFormGateService _poseFormGateService = PoseFormGateService();
  final PoseHoldEligibilityService _poseHoldEligibilityService =
      const PoseHoldEligibilityService();
  final PoseStabilityService _poseStabilityService = PoseStabilityService(
    stabilityThreshold: 0.015,
  );
  final WorkoutGuidanceService _guidanceService = WorkoutGuidanceService();
  final ScoreSmoothingService _scoreSmoothingService = ScoreSmoothingService(
    windowSize: 5,
  );
  final DatabaseService _databaseService = DatabaseService.instance;
  final GamificationService _gamificationService = GamificationService();
  final PunishmentService _punishmentService = PunishmentService();
  late final VoiceCueService _voiceCueService;
  final VoiceInstructionComposer _voiceInstructionComposer =
      const VoiceInstructionComposer();

  // CosineSimilarityService and LimbSimilarityService are initialised
  // lazily in initState() so we can inject the selected pose's meanVector.
  late final CosineSimilarityService _similarityService;
  late final LimbSimilarityService _limbSimilarityService;
  late final CosineSimilarityService _mirroredSimilarityService;
  late final LimbSimilarityService _mirroredLimbSimilarityService;
  late final PoseSessionService _poseSessionService;
  late final PoseCorrectionService _mirroredPoseCorrectionService;
  late final List<double> _mirroredTemplateVector;

  PoseSessionConfig get _sessionConfig =>
      widget.sessionConfig ?? PoseSessionConfig.defaultPractice;
  bool get _isTimedMode => _sessionConfig.mode == PoseSessionMode.timed;

  // ── State ─────────────────────────────────────────────────────────────────

  /// Use ValueNotifier so only the skeleton overlay repaints, not the whole tree.
  final ValueNotifier<List<Pose>> _posesNotifier = ValueNotifier([]);

  /// Computed joint angles for the current frame.
  final ValueNotifier<Map<String, double>> _anglesNotifier = ValueNotifier({});

  /// Normalized pose vector (24 elements) for the current frame, or null.
  final ValueNotifier<List<double>?> _normalizedVectorNotifier = ValueNotifier(
    null,
  );

  /// Raw similarity score (0–100 %) for the current frame (debug).
  final ValueNotifier<double> _rawSimilarityNotifier = ValueNotifier(0.0);

  /// Smoothed similarity score (0–100 %) for the current frame (used for logic).
  final ValueNotifier<double> _smoothedSimilarityNotifier = ValueNotifier(0.0);

  /// Smoothed HUD score display (cadence + deadband controlled).
  final ValueNotifier<double> _hudScoreNotifier = ValueNotifier(0.0);

  /// Smoothed HUD progress display (updated at ~5 Hz).
  final ValueNotifier<double> _hudProgressNotifier = ValueNotifier(0.0);

  /// Pose hold progress (0.0–1.0) for the current frame.
  final ValueNotifier<double> _holdProgressNotifier = ValueNotifier(0.0);

  /// Current hold time in seconds.
  final ValueNotifier<double> _holdSecondsNotifier = ValueNotifier(0.0);

  /// Whether the user has completed the hold duration.
  final ValueNotifier<bool> _poseCompletedNotifier = ValueNotifier(false);

  /// Completed pose result (shown as a completion card).
  final ValueNotifier<PoseResult?> _poseResultNotifier = ValueNotifier(null);

  /// Whether the pose is stable between frames.
  final ValueNotifier<bool> _poseStableNotifier = ValueNotifier(false);

  /// Average inter-frame movement across key joints.
  final ValueNotifier<double> _movementScoreNotifier = ValueNotifier(0.0);

  /// Per-limb similarity scores (0–100 %) for the current frame.
  final ValueNotifier<Map<String, double>> _limbScoresNotifier = ValueNotifier(
    {},
  );

  /// Corrective feedback messages for the current frame.
  final ValueNotifier<List<String>> _feedbackNotifier = ValueNotifier([]);

  /// Angle-based corrective feedback from [PoseCorrectionService].
  final ValueNotifier<List<String>> _angleFeedbackNotifier = ValueNotifier([]);

  /// Single source of truth for workout guidance UI.
  final ValueNotifier<WorkoutGuidanceSnapshot> _guidanceNotifier =
      ValueNotifier(const WorkoutGuidanceSnapshot.initializing());

  /// Session rewards displayed on completion card.
  final ValueNotifier<int> _lastXpGainedNotifier = ValueNotifier(0);
  final ValueNotifier<List<UnlockedBadge>> _lastUnlockedBadgesNotifier =
      ValueNotifier(const <UnlockedBadge>[]);

  /// Whether the camera has finished initialising.
  bool _isCameraReady = false;

  /// Error message to show if initialisation fails.
  String? _errorMessage;

  /// Simple FPS counter for debug overlay.
  final ValueNotifier<double> _fpsNotifier = ValueNotifier(0);
  int _frameCount = 0;
  DateTime _lastFpsUpdate = DateTime.now();
  DateTime? _lastHudScoreUpdateAt;
  DateTime? _lastHudProgressUpdateAt;
  bool _isSavingResult = false;
  bool _resultDelivered = false;
  Timer? _timedUiTicker;

  static const Duration _hudScoreCadence = Duration(milliseconds: 250);
  static const Duration _hudProgressCadence = Duration(milliseconds: 200);
  static const Duration _normalizedFallbackGrace = Duration(milliseconds: 450);

  List<double>? _lastReliableNormalizedVector;
  DateTime? _lastReliableNormalizedAt;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voiceCueService = VoiceCueService(speaker: FlutterTtsVoiceSpeaker());

    // Inject the selected pose template's meanVector as the reference
    // for cosine similarity scoring.  This is the core link between the
    // Pose Library and the real-time evaluation pipeline.
    _similarityService = CosineSimilarityService(
      referenceVector: widget.poseTemplate.meanVector,
    );
    _limbSimilarityService = LimbSimilarityService(
      cosineSimilarityService: _similarityService,
    );
    _mirroredTemplateVector = PoseMirrorService.mirrorVector(
      widget.poseTemplate.meanVector,
    );
    _mirroredSimilarityService = CosineSimilarityService(
      referenceVector: _mirroredTemplateVector,
    );
    _mirroredLimbSimilarityService = LimbSimilarityService(
      cosineSimilarityService: _mirroredSimilarityService,
    );

    // Pre-compute reference joint angles from the template's mean vector.
    _poseCorrectionService.computeReferenceAngles(
      widget.poseTemplate.meanVector,
    );
    _mirroredPoseCorrectionService = PoseCorrectionService();
    _mirroredPoseCorrectionService.computeReferenceAngles(
      _mirroredTemplateVector,
    );
    _poseSessionService = PoseSessionService(
      poseName: widget.poseTemplate.name,
      sessionConfig: _sessionConfig,
    );
    if (_isTimedMode) {
      _poseSessionService.startTimedSession();
      _startTimedUiTicker();
    }

    _initCamera();
  }

  @override
  void dispose() {
    // Allow the screen to turn off again.
    WakelockPlus.disable();
    WidgetsBinding.instance.removeObserver(this);
    _posesNotifier.dispose();
    _anglesNotifier.dispose();
    _normalizedVectorNotifier.dispose();
    _rawSimilarityNotifier.dispose();
    _smoothedSimilarityNotifier.dispose();
    _hudScoreNotifier.dispose();
    _hudProgressNotifier.dispose();
    _holdProgressNotifier.dispose();
    _holdSecondsNotifier.dispose();
    _poseCompletedNotifier.dispose();
    _poseResultNotifier.dispose();
    _poseStableNotifier.dispose();
    _movementScoreNotifier.dispose();
    _limbScoresNotifier.dispose();
    _feedbackNotifier.dispose();
    _angleFeedbackNotifier.dispose();
    _guidanceNotifier.dispose();
    _lastXpGainedNotifier.dispose();
    _lastUnlockedBadgesNotifier.dispose();
    _fpsNotifier.dispose();
    _timedUiTicker?.cancel();
    unawaited(_voiceCueService.dispose());
    _cameraService.dispose();
    _poseDetectionService.dispose();
    super.dispose();
  }

  /// Pause/resume camera when the app goes to background / foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_cameraService.isInitialised) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _cameraService.stopImageStream();
        break;
      case AppLifecycleState.resumed:
        _startDetection();
        break;
      default:
        break;
    }
  }

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      await _cameraService.initialise();
      // Keep the screen awake while the camera is in use.
      WakelockPlus.enable();
      if (!mounted) return;
      setState(() => _isCameraReady = true);
      _guidanceNotifier.value = _guidanceService.evaluate(
        cameraReady: true,
        hasPose: false,
        poseStable: false,
        poseCompleted: false,
        score: 0,
        holdProgress: 0,
        scoreThreshold: _sessionConfig.scoreThreshold,
        feedbackMessages: const <String>[],
      );
      _updateHudMetrics(at: DateTime.now(), score: 0, progress: 0, force: true);
      _startDetection();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    }
  }

  /// Begin streaming frames to the pose detector.
  void _startDetection() {
    _cameraService.startImageStream((InputImage inputImage) async {
      // Run pose detection (async, off the UI thread).
      final poses = await _poseDetectionService.detectPose(inputImage);
      final now = DateTime.now();

      // ── Smooth landmarks & compute joint angles ──────────────────────
      if (poses.isNotEmpty) {
        final poseFrame = PoseFrame.fromMLKitPose(poses.first);

        // Apply One Euro Filter smoothing to reduce jitter.
        final smoothedLandmarks = _smoothingService.smooth(poseFrame.landmarks);

        // Compute angles from the smoothed landmarks.
        final angles = _angleService.calculateAngles(smoothedLandmarks);
        _anglesNotifier.value = angles;

        // ── Normalize pose vector (translation + scale invariant) ────
        final normalized = _normalizedForScoring(
          _normalizationService.normalize(smoothedLandmarks),
          now,
        );
        _normalizedVectorNotifier.value = normalized;

        // ── Distance + angle similarity against reference pose ──────
        final hasDistanceScore = normalized != null;
        final maxDistance = _distanceMaxDistanceForPose();
        final distanceScore = _distanceSimilarityService.computeScore(
          normalized,
          widget.poseTemplate.meanVector,
          maxDistance: maxDistance,
        );
        final mirroredDistanceScore = _distanceSimilarityService.computeScore(
          normalized,
          _mirroredTemplateVector,
          maxDistance: maxDistance,
        );
        final cosineScore = normalized == null
            ? null
            : _similarityService.compareToPose(normalized);
        final mirroredCosineScore = normalized == null
            ? null
            : _mirroredSimilarityService.compareToPose(normalized);
        final angleScore = _poseCorrectionService.computeAngleScore(angles);
        final mirroredAngleScore = _mirroredPoseCorrectionService
            .computeAngleScore(angles);
        final similarity = _combineScores(
          distanceScore: distanceScore,
          cosineScore: cosineScore,
          angleScore: angleScore,
          hasDistanceScore: hasDistanceScore,
        );
        final mirroredSimilarity = _combineScores(
          distanceScore: mirroredDistanceScore,
          cosineScore: mirroredCosineScore,
          angleScore: mirroredAngleScore,
          hasDistanceScore: hasDistanceScore,
        );
        final useMirrored = mirroredSimilarity > similarity;
        final baseSimilarity = useMirrored ? mirroredSimilarity : similarity;
        final formGate = _poseFormGateService.evaluate(
          poseKey: widget.poseTemplate.templateKey,
          normalizedVector: normalized,
          angles: angles,
          scoreThreshold: _poseSessionService.scoreThreshold,
        );
        final selectedSimilarity = formGate.applyToScore(baseSimilarity);
        _rawSimilarityNotifier.value = selectedSimilarity;
        final smoothedScore = _scoreSmoothingService.addScore(
          selectedSimilarity,
        );
        _smoothedSimilarityNotifier.value = smoothedScore;

        // ── Pose stability check ────────────────────────────────────────
        final stabilityResult = _poseStabilityService.update(smoothedLandmarks);
        final poseStable =
            stabilityResult.movementScore > 0 &&
            stabilityResult.movementScore < _stabilityThresholdForPose();
        _poseStableNotifier.value = poseStable;
        _movementScoreNotifier.value = stabilityResult.movementScore;
        final poseStableForHold = _poseHoldEligibilityService.poseStableForHold(
          mode: _sessionConfig.mode,
          poseStable: poseStable,
          score: smoothedScore,
          scoreThreshold: _poseSessionService.scoreThreshold,
        );

        // ── Pose hold timer ───────────────────────────────────────────
        final poseResult = _poseSessionService.update(
          smoothedScore,
          poseStable: poseStableForHold,
        );
        if (poseResult != null) {
          if (_isTimedMode) {
            _handleTimedSessionResult(poseResult);
          } else {
            _poseResultNotifier.value = poseResult;
            if (_sessionConfig.persistResult) {
              unawaited(_persistPoseResult(poseResult));
            }
          }
        }
        _holdProgressNotifier.value = _isTimedMode
            ? _poseSessionService.timedProgress
            : _poseSessionService.holdProgress;
        _holdSecondsNotifier.value = _isTimedMode
            ? _poseSessionService.timedElapsedSeconds
            : _poseSessionService.holdTimeSeconds;
        _poseCompletedNotifier.value = _poseSessionService.poseCompleted;

        // ── Per-limb similarity scores ──────────────────────────────
        final limbScores = useMirrored
            ? _mirroredLimbSimilarityService.computeLimbScores(normalized)
            : _limbSimilarityService.computeLimbScores(normalized);
        _limbScoresNotifier.value = limbScores;

        // ── Corrective feedback (limb similarity) ──────────────────
        final feedback = useMirrored
            ? _mirroredLimbSimilarityService.generateFeedback(limbScores)
            : _limbSimilarityService.generateFeedback(limbScores);
        _feedbackNotifier.value = feedback;

        // ── Angle-based corrective feedback ─────────────────────────
        final angleCorrections = useMirrored
            ? _mirroredPoseCorrectionService.generateCorrections(angles)
            : _poseCorrectionService.generateCorrections(angles);
        _angleFeedbackNotifier.value = angleCorrections;
        final guidanceFeedback = <String>[
          ...formGate.feedbackMessages,
          ...angleCorrections,
          ...feedback,
        ];

        final guidance = _guidanceService.evaluate(
          cameraReady: _isCameraReady,
          hasPose: true,
          poseStable: poseStableForHold,
          poseCompleted: _poseSessionService.poseCompleted,
          score: smoothedScore,
          holdProgress: _isTimedMode
              ? _poseSessionService.timedProgress
              : _poseSessionService.holdProgress,
          scoreThreshold: _poseSessionService.scoreThreshold,
          feedbackMessages: guidanceFeedback,
          now: now,
        );
        _guidanceNotifier.value = guidance;
        _updateHudMetrics(
          at: now,
          score: guidance.score,
          progress: guidance.holdProgress,
        );
        _speakPrimaryCue(guidance, poseStable: poseStableForHold);

        // Debug: print the normalized vector to console.
        if (normalized != null) {
          debugPrint(
            '[PoseNorm] vector(${normalized.length}): '
            '${normalized.map((v) => v.toStringAsFixed(3)).join(", ")}',
          );
          debugPrint(
            '[PoseScore] distance=${distanceScore.toStringAsFixed(1)} '
            'cos=${cosineScore?.toStringAsFixed(1) ?? '-'} '
            'angle=${angleScore?.toStringAsFixed(1) ?? '-'} '
            'mirrorDist=${mirroredDistanceScore.toStringAsFixed(1)} '
            'mirrorCos=${mirroredCosineScore?.toStringAsFixed(1) ?? '-'} '
            'mirrorAngle=${mirroredAngleScore?.toStringAsFixed(1) ?? '-'} '
            'base=${baseSimilarity.toStringAsFixed(1)}% '
            'raw=${selectedSimilarity.toStringAsFixed(1)}% '
            'smooth=${smoothedScore.toStringAsFixed(1)}% '
            'gate=${formGate.passes ? 'pass' : 'cap'} '
            'maxDist=${maxDistance.toStringAsFixed(2)} '
            'hasDistance=$hasDistanceScore '
            'mirrored=$useMirrored',
          );
        }

        // Build a smoothed Pose so the skeleton painter also uses
        // smoothed coordinates (eliminates visual jitter).
        final rawPose = poses.first;
        final smoothedPoseLandmarks = <PoseLandmarkType, PoseLandmark>{};
        for (final entry in rawPose.landmarks.entries) {
          final idx = entry.key.index;
          if (idx < smoothedLandmarks.length) {
            final sl = smoothedLandmarks[idx];
            smoothedPoseLandmarks[entry.key] = PoseLandmark(
              type: entry.key,
              x: sl.x,
              y: sl.y,
              z: sl.z,
              likelihood: entry.value.likelihood,
            );
          } else {
            smoothedPoseLandmarks[entry.key] = entry.value;
          }
        }
        final smoothedPose = Pose(landmarks: smoothedPoseLandmarks);

        if (mounted) {
          _posesNotifier.value = [smoothedPose];
        }
      } else {
        _feedbackNotifier.value = [];
        _angleFeedbackNotifier.value = [];
        if (_isTimedMode) {
          final timedResult = _poseSessionService.update(
            0.0,
            poseStable: false,
            timestamp: now,
          );
          if (timedResult != null) {
            _handleTimedSessionResult(timedResult);
          }
          _holdProgressNotifier.value = _poseSessionService.timedProgress;
          _holdSecondsNotifier.value = _poseSessionService.timedElapsedSeconds;
        }
        final guidance = _guidanceService.evaluate(
          cameraReady: _isCameraReady,
          hasPose: false,
          poseStable: false,
          poseCompleted: _poseSessionService.poseCompleted,
          score: _smoothedSimilarityNotifier.value,
          holdProgress: _holdProgressNotifier.value,
          scoreThreshold: _poseSessionService.scoreThreshold,
          feedbackMessages: const <String>[],
          now: now,
        );
        _guidanceNotifier.value = guidance;
        _updateHudMetrics(
          at: now,
          score: guidance.score,
          progress: guidance.holdProgress,
        );
        if (guidance.shouldResetSession &&
            _poseResultNotifier.value == null &&
            !_isTimedMode) {
          _anglesNotifier.value = {};
          _normalizedVectorNotifier.value = null;
          _lastReliableNormalizedVector = null;
          _lastReliableNormalizedAt = null;
          _rawSimilarityNotifier.value = 0.0;
          _smoothedSimilarityNotifier.value = 0.0;
          _scoreSmoothingService.reset();
          _poseSessionService.reset();
          _poseStabilityService.reset();
          _holdProgressNotifier.value = 0.0;
          _holdSecondsNotifier.value = 0.0;
          _poseCompletedNotifier.value = false;
          _poseResultNotifier.value = null;
          _poseStableNotifier.value = false;
          _movementScoreNotifier.value = 0.0;
          _limbScoresNotifier.value = {};
        }
        if (mounted) {
          _posesNotifier.value = poses;
        }
      }

      // Update FPS counter.
      _frameCount++;
      final frameNow = DateTime.now();
      final elapsed = frameNow.difference(_lastFpsUpdate).inMilliseconds;
      if (elapsed >= 1000) {
        _fpsNotifier.value = _frameCount / (elapsed / 1000.0);
        _frameCount = 0;
        _lastFpsUpdate = frameNow;
      }

      // Release the busy-guard so the next frame can be processed.
      _cameraService.isProcessing = false;
    });
  }

  void _speakPrimaryCue(
    WorkoutGuidanceSnapshot snapshot, {
    bool poseStable = true,
  }) {
    if (snapshot.state == WorkoutGuidanceState.aligning && !poseStable) {
      return;
    }

    final spokenCue = _voiceInstructionComposer.compose(
      snapshot: snapshot,
      baseCue: snapshot.primaryCue,
    );
    if (spokenCue == null || spokenCue.isEmpty) return;
    unawaited(_voiceCueService.speakIfAllowed(spokenCue, snapshot.state));
  }

  void _resetSession() {
    _scoreSmoothingService.reset();
    _poseSessionService.reset();
    _poseStabilityService.reset();
    _guidanceService.reset();
    _lastReliableNormalizedVector = null;
    _lastReliableNormalizedAt = null;
    _rawSimilarityNotifier.value = 0.0;
    _smoothedSimilarityNotifier.value = 0.0;
    _holdProgressNotifier.value = 0.0;
    _holdSecondsNotifier.value = 0.0;
    _poseCompletedNotifier.value = false;
    _poseResultNotifier.value = null;
    _poseStableNotifier.value = false;
    _movementScoreNotifier.value = 0.0;
    _limbScoresNotifier.value = {};
    _feedbackNotifier.value = [];
    _angleFeedbackNotifier.value = [];
    _lastXpGainedNotifier.value = 0;
    _lastUnlockedBadgesNotifier.value = const <UnlockedBadge>[];
    _lastHudScoreUpdateAt = null;
    _lastHudProgressUpdateAt = null;
    _updateHudMetrics(at: DateTime.now(), score: 0, progress: 0, force: true);
    _guidanceNotifier.value = _guidanceService.evaluate(
      cameraReady: _isCameraReady,
      hasPose: false,
      poseStable: false,
      poseCompleted: false,
      score: 0,
      holdProgress: 0,
      scoreThreshold: _poseSessionService.scoreThreshold,
      feedbackMessages: const <String>[],
    );
    unawaited(_voiceCueService.reset());
  }

  void _updateHudMetrics({
    required DateTime at,
    required double score,
    required double progress,
    bool force = false,
  }) {
    final roundedScore = score.clamp(0.0, 100.0).toDouble().roundToDouble();
    final normalizedProgress = progress.clamp(0.0, 1.0).toDouble();

    if (force || _shouldRefreshHudScore(at, roundedScore)) {
      _hudScoreNotifier.value = roundedScore;
      _lastHudScoreUpdateAt = at;
    }
    if (force || _shouldRefreshHudProgress(at, normalizedProgress)) {
      _hudProgressNotifier.value = normalizedProgress;
      _lastHudProgressUpdateAt = at;
    }
  }

  bool _shouldRefreshHudScore(DateTime at, double nextScore) {
    final last = _lastHudScoreUpdateAt;
    if (last == null) return true;
    final elapsed = at.difference(last);
    if (elapsed < _hudScoreCadence) return false;

    final delta = (nextScore - _hudScoreNotifier.value).abs();
    if (delta >= 2.0) return true;
    return elapsed >= const Duration(seconds: 1) && delta >= 1.0;
  }

  bool _shouldRefreshHudProgress(DateTime at, double nextProgress) {
    final last = _lastHudProgressUpdateAt;
    if (last == null) return true;
    final elapsed = at.difference(last);
    if (elapsed < _hudProgressCadence) return false;

    final delta = (nextProgress - _hudProgressNotifier.value).abs();
    if (delta >= 0.003) return true;
    return elapsed >= const Duration(milliseconds: 800);
  }

  Future<void> _persistPoseResult(PoseResult result) async {
    if (_isSavingResult) return;
    _isSavingResult = true;
    try {
      final practiceResult = result.copyWith(
        sessionType: PoseResultSessionType.practice,
      );
      final insertedId = await _databaseService.insertPoseResult(
        practiceResult,
      );
      final persistedResult = practiceResult.copyWith(id: insertedId);
      final gamificationResult = await _gamificationService
          .processCompletedSession(persistedResult);
      _lastXpGainedNotifier.value = gamificationResult.xpGained;
      _lastUnlockedBadgesNotifier.value = gamificationResult.unlockedBadges;
      debugPrint(
        '[DB] Saved pose result: ${result.poseName} '
        '(score=${result.bestScore.toStringAsFixed(1)}%) '
        'xp=+${gamificationResult.xpGained} '
        'badges=${gamificationResult.unlockedBadges.length}',
      );
      if (mounted) {
        await RankUpDialog.showIfRankedUp(
          context,
          didRankUp: gamificationResult.didRankUp,
          rankAfter: gamificationResult.rankAfter,
          xpAfter: gamificationResult.xpAfter,
        );
        try {
          final punishmentResult = await _punishmentService.evaluate(
            trigger: PenaltyApplicationTrigger.postSession,
            practiceResult: persistedResult,
            qualityGateScore: _sessionConfig.scoreThreshold + 10.0,
          );
          if (!mounted) return;
          await XpDeductionDialog.showIfNeeded(
            context,
            result: punishmentResult,
          );
        } catch (error) {
          debugPrint('Failed to evaluate practice penalties: $error');
        }
      }
    } catch (e) {
      _lastXpGainedNotifier.value = 0;
      _lastUnlockedBadgesNotifier.value = const <UnlockedBadge>[];
      debugPrint('[DB] Failed to save pose result: $e');
    } finally {
      _isSavingResult = false;
    }
  }

  void _startTimedUiTicker() {
    _timedUiTicker?.cancel();
    if (!_isTimedMode) return;
    _timedUiTicker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || !_isTimedMode || _poseResultNotifier.value != null) {
        return;
      }
      _holdProgressNotifier.value = _poseSessionService.timedProgress;
      _holdSecondsNotifier.value = _poseSessionService.timedElapsedSeconds;
      if (_poseSessionService.timedRemainingSeconds <= 0) {
        final timedResult = _poseSessionService.finalizeTimedSession();
        if (timedResult != null) {
          _handleTimedSessionResult(timedResult);
        }
      }
    });
  }

  void _handleTimedSessionResult(PoseResult poseResult) {
    if (_poseResultNotifier.value != null) return;
    _poseResultNotifier.value = poseResult;
    _holdProgressNotifier.value = _poseSessionService.timedProgress;
    _holdSecondsNotifier.value = _poseSessionService.timedElapsedSeconds;
    _poseCompletedNotifier.value = _poseSessionService.poseCompleted;
    if (_sessionConfig.persistResult) {
      unawaited(_persistPoseResult(poseResult));
    }
    if (widget.returnResultOnCompletion && !_resultDelivered && mounted) {
      _resultDelivered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pop(
          ChallengeStepResult(
            poseName: poseResult.poseName,
            bestScore: poseResult.bestScore,
            holdDuration: poseResult.holdDuration,
            passed: true,
            completedAt: poseResult.timestamp ?? DateTime.now(),
          ),
        );
      });
    }
  }

  void _toggleTimedPause() {
    if (!_isTimedMode) return;
    if (_poseSessionService.isTimedPaused) {
      _poseSessionService.resumeTimedSession();
    } else {
      _poseSessionService.pauseTimedSession();
    }
    if (mounted) setState(() {});
  }

  void _returnTimedNavigation(ChallengeStepNavigationAction action) {
    if (!_isTimedMode || !widget.returnResultOnCompletion || _resultDelivered) {
      return;
    }
    _resultDelivered = true;
    if (action == ChallengeStepNavigationAction.previous) {
      Navigator.of(context).pop(
        ChallengeStepResult(
          poseName: widget.poseTemplate.name,
          bestScore: 0,
          holdDuration: 0,
          passed: false,
          completedAt: DateTime.now(),
          action: action,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final finalized = _poseSessionService.finalizeTimedSession(timestamp: now);
    final score = finalized?.bestScore ?? _poseSessionService.averageScore;
    final elapsed =
        finalized?.holdDuration ??
        _poseSessionService.timedElapsedSeconds.clamp(0, 9999).toDouble();
    Navigator.of(context).pop(
      ChallengeStepResult(
        poseName: widget.poseTemplate.name,
        bestScore: score,
        holdDuration: elapsed,
        passed: true,
        completedAt: now,
        action: action,
      ),
    );
  }

  String _formatClock(double seconds) {
    final total = seconds.isFinite ? seconds.round().clamp(0, 5999) : 0;
    final mins = total ~/ 60;
    final secs = total % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final textTheme = Theme.of(context).textTheme;

    // Error state.
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.videocam_off_rounded,
                  color: ZenColors.error,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Camera error',
                  style: textTheme.titleLarge?.copyWith(
                    color: ZenColors.mist,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_errorMessage',
                  style: textTheme.bodyMedium?.copyWith(
                    color: ZenColors.mist.withValues(alpha: 0.70),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Loading state.
    if (!_isCameraReady) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: ZenColors.teal,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Initialising camera…',
                style: textTheme.bodyLarge?.copyWith(
                  color: ZenColors.mist.withValues(alpha: 0.84),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Camera + overlay.
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview + skeleton overlay ──────────────────────────
          _buildCameraWithOverlay(),

          // ── Top bar: back button + pose name ────────────────────────────
          Positioned(
            top: topPad + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                // Back button
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ZenColors.bark.withValues(alpha: 0.62),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ZenColors.sage200.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: ZenColors.mist,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: ZenColors.bark.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: ZenColors.sage200.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      widget.poseTemplate.name,
                      style: textTheme.titleMedium?.copyWith(
                        color: ZenColors.mist,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Wide-lens status indicator (always-on policy when available)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _cameraService.hasWideLens
                        ? ZenColors.teal.withValues(alpha: 0.72)
                        : ZenColors.bark.withValues(alpha: 0.62),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ZenColors.sage200.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(
                    _cameraService.hasWideLens
                        ? Icons.zoom_out_map
                        : Icons.crop_free,
                    color: ZenColors.mist,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),

          // ── Status HUD (score + hold) ─────────────────────────────────
          _buildStatusHud(),

          // ── Feedback pills ────────────────────────────────────────────
          _buildFeedbackCard(),

          if (_isTimedMode) _buildTimedBottomPanel(),

          // ── Completion card overlay ───────────────────────────────────
          AnimatedBuilder(
            animation: Listenable.merge([
              _poseResultNotifier,
              _lastXpGainedNotifier,
              _lastUnlockedBadgesNotifier,
            ]),
            builder: (context, _) {
              if (_isTimedMode) return const SizedBox.shrink();
              final result = _poseResultNotifier.value;
              if (result == null) return const SizedBox.shrink();
              return Positioned.fill(
                child: Container(
                  color: ZenColors.bark.withValues(alpha: 0.70),
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.88, end: 1.0),
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: _buildCompletionCard(
                        result,
                        xpGained: _lastXpGainedNotifier.value,
                        unlockedBadges: _lastUnlockedBadgesNotifier.value,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHud() {
    final topPad = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPad + 64,
      left: 12,
      right: 12,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _guidanceNotifier,
          _holdSecondsNotifier,
          _hudScoreNotifier,
          _hudProgressNotifier,
        ]),
        builder: (context, _) {
          return WorkoutStatusHud(
            snapshot: _guidanceNotifier.value,
            holdSeconds: _holdSecondsNotifier.value,
            displayScore: _hudScoreNotifier.value,
            displayProgress: _hudProgressNotifier.value,
            durationSeconds: _isTimedMode
                ? _poseSessionService.timedDuration.inMilliseconds / 1000.0
                : _poseSessionService.holdDuration.inMilliseconds / 1000.0,
            scoreThreshold: _poseSessionService.scoreThreshold,
          );
        },
      ),
    );
  }

  Widget _buildFeedbackCard() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Positioned(
      bottom: bottomPad + (_isTimedMode ? 160 : 24),
      left: 12,
      right: 12,
      child: AnimatedBuilder(
        animation: Listenable.merge([_guidanceNotifier, _poseResultNotifier]),
        builder: (context, _) {
          return WorkoutFeedbackPanel(
            snapshot: _guidanceNotifier.value,
            visible: _poseResultNotifier.value == null,
          );
        },
      ),
    );
  }

  Widget _buildTimedBottomPanel() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final textTheme = Theme.of(context).textTheme;
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomPad + 16,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: ZenColors.bark.withValues(alpha: 0.66),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: ZenColors.sage200.withValues(alpha: 0.36)),
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _holdSecondsNotifier,
            _smoothedSimilarityNotifier,
          ]),
          builder: (context, _) {
            final remaining = _poseSessionService.timedRemainingSeconds;
            final timer = _formatClock(remaining);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timer,
                  style: textTheme.displayMedium?.copyWith(
                    color: ZenColors.mist,
                    fontWeight: FontWeight.w800,
                    fontSize: 46,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Avg score ${_poseSessionService.averageScore.toStringAsFixed(0)}%',
                  style: textTheme.labelLarge?.copyWith(
                    color: ZenColors.mist.withValues(alpha: 0.80),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _returnTimedNavigation(
                          ChallengeStepNavigationAction.previous,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ZenColors.mist,
                          side: BorderSide(
                            color: ZenColors.sage200.withValues(alpha: 0.52),
                          ),
                          backgroundColor: ZenColors.bark.withValues(
                            alpha: 0.28,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Icon(Icons.skip_previous_rounded),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _toggleTimedPause,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ZenColors.teal,
                          foregroundColor: ZenColors.mist,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: Icon(
                          _poseSessionService.isTimedPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _returnTimedNavigation(
                          ChallengeStepNavigationAction.next,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ZenColors.mist,
                          side: BorderSide(
                            color: ZenColors.sage200.withValues(alpha: 0.52),
                          ),
                          backgroundColor: ZenColors.bark.withValues(
                            alpha: 0.28,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Icon(Icons.skip_next_rounded),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompletionCard(
    PoseResult result, {
    required int xpGained,
    required List<UnlockedBadge> unlockedBadges,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final bestScoreText = '${result.bestScore.toStringAsFixed(0)}%';
    final holdTimeText = '${result.holdDuration.toStringAsFixed(1)}s';
    final buttonText =
        widget.completionActionLabel ??
        (widget.returnResultOnCompletion ? 'Continue' : 'Try Again');
    final score = result.bestScore;
    final Color scoreColor = score >= 80
        ? ZenColors.success
        : score >= 60
        ? ZenColors.warning
        : ZenColors.error;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: ZenColors.surface1,
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ZenColors.bark.withValues(alpha: 0.25),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Gradient header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[ZenColors.forest, ZenColors.teal],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: ZenColors.mist.withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: ZenColors.mist,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Pose Completed!',
                  style: textTheme.titleLarge?.copyWith(
                    color: ZenColors.mist,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.poseName,
                  style: textTheme.bodyMedium?.copyWith(
                    color: ZenColors.mist.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                // Score highlight
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      bestScoreText,
                      style: textTheme.displayMedium?.copyWith(
                        color: scoreColor,
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Best',
                          style: textTheme.bodySmall?.copyWith(
                            color: ZenColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Score',
                          style: textTheme.bodySmall?.copyWith(
                            color: ZenColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: ZenColors.sand,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: ZenColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Hold time: $holdTimeText',
                        style: textTheme.bodyMedium?.copyWith(
                          color: ZenColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (xpGained > 0 || unlockedBadges.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  WorkoutRewardSummary(
                    xpGained: xpGained,
                    unlockedBadges: unlockedBadges,
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (widget.returnResultOnCompletion) {
                        Navigator.of(context).pop(
                          ChallengeStepResult(
                            poseName: result.poseName,
                            bestScore: result.bestScore,
                            holdDuration: result.holdDuration,
                            passed:
                                result.bestScore >=
                                _sessionConfig.scoreThreshold,
                            completedAt: result.timestamp ?? DateTime.now(),
                          ),
                        );
                        return;
                      }
                      _resetSession();
                    },
                    child: Text(buttonText),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build the camera preview AND skeleton overlay inside the same sized
  /// container so coordinates match perfectly.
  Widget _buildCameraWithOverlay() {
    final controller = _cameraService.controller!;
    final previewAspectRatio = controller.value.aspectRatio; // w/h in landscape

    return Center(
      child: AspectRatio(
        aspectRatio: 1 / previewAspectRatio, // portrait aspect ratio
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Camera preview – wrapped in RepaintBoundary so it doesn't
            // repaint when the skeleton overlay updates.
            RepaintBoundary(child: CameraPreview(controller)),

            // Skeleton overlay – exactly the same size as the preview.
            ValueListenableBuilder<List<Pose>>(
              valueListenable: _posesNotifier,
              builder: (context, poses, _) {
                if (poses.isEmpty) return const SizedBox.shrink();
                final normalizedLandmarks = _normalizeLandmarks(poses.first);
                return CustomPaint(
                  painter: SkeletonOverlayPainter(
                    landmarks: normalizedLandmarks,
                    similarityScore: _guidanceNotifier.value.score,
                    scoreThreshold: _poseSessionService.scoreThreshold,
                    mirror:
                        _cameraService.cameraDescription?.lensDirection ==
                        CameraLensDirection.front,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// The image size reported by the camera (width × height in sensor coords).
  /// previewSize is reported in landscape (width > height), so we swap for
  /// portrait orientation.
  Size get _cameraImageSize {
    final controller = _cameraService.controller!;
    return Size(
      controller.value.previewSize?.height ?? 480,
      controller.value.previewSize?.width ?? 640,
    );
  }

  /// Convert ML Kit landmark pixels into normalized (0–1) coordinates.
  List<Landmark> _normalizeLandmarks(Pose pose) {
    final imageSize = _cameraImageSize;
    final width = imageSize.width;
    final height = imageSize.height;
    if (width == 0 || height == 0) {
      return List<Landmark>.filled(
        PoseLandmarkType.values.length,
        Landmark.invalid,
      );
    }

    return List<Landmark>.generate(PoseLandmarkType.values.length, (i) {
      final type = PoseLandmarkType.values[i];
      final lm = pose.landmarks[type];
      if (lm == null) return Landmark.invalid;
      return Landmark(x: lm.x / width, y: lm.y / height);
    });
  }

  /// Blend distance and angle scores into a single 0–100 score.
  ///
  /// Downward dog and plank are more reliable when angle similarity carries
  /// more weight and distance tolerance is slightly wider.
  double _combineScores({
    required double distanceScore,
    required double? cosineScore,
    required double? angleScore,
    required bool hasDistanceScore,
  }) {
    final (distanceWeight, cosineWeight, angleWeight) =
        _scoreBlendWeightsForPose();
    final weighted = <(double, double)>[];
    if (hasDistanceScore) {
      weighted.add((distanceScore, distanceWeight));
    }
    if (cosineScore != null) {
      weighted.add((cosineScore, cosineWeight));
    }
    if (angleScore != null) {
      weighted.add((angleScore, angleWeight));
    }

    if (weighted.isEmpty) {
      return 0.0;
    }

    final totalWeight = weighted.fold<double>(
      0.0,
      (sum, item) => sum + item.$2,
    );
    if (totalWeight <= 0.0) {
      return weighted.last.$1;
    }

    final weightedScore = weighted.fold<double>(
      0.0,
      (sum, item) => sum + (item.$1 * item.$2),
    );
    return weightedScore / totalWeight;
  }

  (double, double, double) _scoreBlendWeightsForPose() {
    // (distance, cosine, angle)
    switch (widget.poseTemplate.templateKey.toLowerCase()) {
      case 'downdog':
      case 'plank':
      case 'chair':
      case 'half-moon':
      case 'halfmoon':
      case 'half moon':
        return (0.05, 0.60, 0.35);
      default:
        return (0.20, 0.50, 0.30);
    }
  }

  double _distanceMaxDistanceForPose() {
    switch (widget.poseTemplate.templateKey.toLowerCase()) {
      case 'downdog':
        return 5.2;
      case 'plank':
        return 5.2;
      case 'chair':
        return 5.2;
      case 'half-moon':
      case 'halfmoon':
      case 'half moon':
        return 6.4;
      default:
        return PoseDistanceSimilarityService.defaultMaxDistance;
    }
  }

  double _stabilityThresholdForPose() {
    switch (widget.poseTemplate.templateKey.toLowerCase()) {
      case 'downdog':
      case 'plank':
        return 0.020;
      case 'chair':
        return 0.022;
      case 'half-moon':
      case 'halfmoon':
      case 'half moon':
        return 0.028;
      default:
        return 0.015;
    }
  }

  Duration _normalizedFallbackGraceForPose() {
    switch (widget.poseTemplate.templateKey.toLowerCase()) {
      case 'chair':
        return const Duration(milliseconds: 700);
      case 'half-moon':
      case 'halfmoon':
      case 'half moon':
        return const Duration(milliseconds: 900);
      default:
        return _normalizedFallbackGrace;
    }
  }

  List<double>? _normalizedForScoring(List<double>? normalized, DateTime at) {
    if (normalized != null) {
      _lastReliableNormalizedVector = normalized;
      _lastReliableNormalizedAt = at;
      return normalized;
    }

    final lastReliableAt = _lastReliableNormalizedAt;
    if (lastReliableAt == null) return null;
    if (at.difference(lastReliableAt) > _normalizedFallbackGraceForPose()) {
      _lastReliableNormalizedVector = null;
      _lastReliableNormalizedAt = null;
      return null;
    }
    return _lastReliableNormalizedVector;
  }
}
