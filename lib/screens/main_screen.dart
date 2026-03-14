import 'dart:async';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/pose_frame.dart';
import '../models/pose_result.dart';
import '../models/challenge_step_result.dart';
import '../models/pose_session_config.dart';
import '../models/pose_template.dart';
import '../services/angle_calculation_service.dart';
import '../services/camera_service.dart';
import '../services/landmark_smoothing_service.dart';
import '../services/pose_normalization_service.dart';
import '../services/cosine_similarity_service.dart';
import '../services/pose_distance_similarity_service.dart';
import '../services/limb_similarity_service.dart';
import '../services/pose_correction_service.dart';
import '../services/pose_detection_service.dart';
import '../services/pose_mirror_service.dart';
import '../services/pose_session_service.dart';
import '../services/pose_stability_service.dart';
import '../services/score_smoothing_service.dart';
import '../models/landmark.dart';
import '../painters/skeleton_overlay_painter.dart';
import '../services/database_service.dart';
import '../services/gamification_service.dart';

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
  final PoseStabilityService _poseStabilityService = PoseStabilityService();
  final ScoreSmoothingService _scoreSmoothingService = ScoreSmoothingService(
    windowSize: 5,
  );
  final DatabaseService _databaseService = DatabaseService.instance;
  final GamificationService _gamificationService = GamificationService();

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

  /// Whether the camera has finished initialising.
  bool _isCameraReady = false;

  /// Error message to show if initialisation fails.
  String? _errorMessage;

  /// Whether wide lens mode is currently active.
  bool _isWideLens = false;

  /// Simple FPS counter for debug overlay.
  final ValueNotifier<double> _fpsNotifier = ValueNotifier(0);
  int _frameCount = 0;
  DateTime _lastFpsUpdate = DateTime.now();
  bool _isSavingResult = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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
    _holdProgressNotifier.dispose();
    _holdSecondsNotifier.dispose();
    _poseCompletedNotifier.dispose();
    _poseResultNotifier.dispose();
    _poseStableNotifier.dispose();
    _movementScoreNotifier.dispose();
    _limbScoresNotifier.dispose();
    _feedbackNotifier.dispose();
    _angleFeedbackNotifier.dispose();
    _fpsNotifier.dispose();
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

      // ── Smooth landmarks & compute joint angles ──────────────────────
      if (poses.isNotEmpty) {
        final poseFrame = PoseFrame.fromMLKitPose(poses.first);

        // Apply One Euro Filter smoothing to reduce jitter.
        final smoothedLandmarks = _smoothingService.smooth(poseFrame.landmarks);

        // Compute angles from the smoothed landmarks.
        final angles = _angleService.calculateAngles(smoothedLandmarks);
        _anglesNotifier.value = angles;

        // ── Normalize pose vector (translation + scale invariant) ────
        final normalized = _normalizationService.normalize(smoothedLandmarks);
        _normalizedVectorNotifier.value = normalized;

        // ── Distance + angle similarity against reference pose ──────
        final distanceScore = _distanceSimilarityService.computeScore(
          normalized,
          widget.poseTemplate.meanVector,
        );
        final mirroredDistanceScore = _distanceSimilarityService.computeScore(
          normalized,
          _mirroredTemplateVector,
        );
        final angleScore = normalized == null
            ? null
            : _poseCorrectionService.computeAngleScore(angles);
        final mirroredAngleScore = normalized == null
            ? null
            : _mirroredPoseCorrectionService.computeAngleScore(angles);
        final similarity = _combineScores(distanceScore, angleScore);
        final mirroredSimilarity = _combineScores(
          mirroredDistanceScore,
          mirroredAngleScore,
        );
        final useMirrored = mirroredSimilarity > similarity;
        final selectedSimilarity = useMirrored
            ? mirroredSimilarity
            : similarity;
        _rawSimilarityNotifier.value = selectedSimilarity;
        final smoothedScore = _scoreSmoothingService.addScore(
          selectedSimilarity,
        );
        _smoothedSimilarityNotifier.value = smoothedScore;

        // ── Pose stability check ────────────────────────────────────────
        final stabilityResult = _poseStabilityService.update(smoothedLandmarks);
        _poseStableNotifier.value = stabilityResult.poseStable;
        _movementScoreNotifier.value = stabilityResult.movementScore;

        // ── Pose hold timer ───────────────────────────────────────────
        final poseResult = _poseSessionService.update(
          smoothedScore,
          poseStable: stabilityResult.poseStable,
        );
        if (poseResult != null) {
          _poseResultNotifier.value = poseResult;
          if (_sessionConfig.persistResult) {
            unawaited(_persistPoseResult(poseResult));
          }
        }
        _holdProgressNotifier.value = _poseSessionService.holdProgress;
        _holdSecondsNotifier.value = _poseSessionService.holdTimeSeconds;
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

        // Debug: print the normalized vector to console.
        if (normalized != null) {
          debugPrint(
            '[PoseNorm] vector(${normalized.length}): '
            '${normalized.map((v) => v.toStringAsFixed(3)).join(", ")}',
          );
          debugPrint(
            '[PoseScore] distance=${distanceScore.toStringAsFixed(1)} '
            'angle=${angleScore?.toStringAsFixed(1) ?? '-'} '
            'mirrorDist=${mirroredDistanceScore.toStringAsFixed(1)} '
            'mirrorAngle=${mirroredAngleScore?.toStringAsFixed(1) ?? '-'} '
            'raw=${selectedSimilarity.toStringAsFixed(1)}% '
            'smooth=${smoothedScore.toStringAsFixed(1)}% '
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
        if (_poseResultNotifier.value == null) {
          _anglesNotifier.value = {};
          _normalizedVectorNotifier.value = null;
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
          _feedbackNotifier.value = [];
          _angleFeedbackNotifier.value = [];
        }
        if (mounted) {
          _posesNotifier.value = poses;
        }
      }

      // Update FPS counter.
      _frameCount++;
      final now = DateTime.now();
      final elapsed = now.difference(_lastFpsUpdate).inMilliseconds;
      if (elapsed >= 1000) {
        _fpsNotifier.value = _frameCount / (elapsed / 1000.0);
        _frameCount = 0;
        _lastFpsUpdate = now;
      }

      // Release the busy-guard so the next frame can be processed.
      _cameraService.isProcessing = false;
    });
  }

  void _resetSession() {
    _scoreSmoothingService.reset();
    _poseSessionService.reset();
    _poseStabilityService.reset();
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
  }

  Future<void> _persistPoseResult(PoseResult result) async {
    if (_isSavingResult) return;
    _isSavingResult = true;
    try {
      final insertedId = await _databaseService.insertPoseResult(result);
      final persistedResult = result.copyWith(id: insertedId);
      final gamificationResult = await _gamificationService
          .processCompletedSession(persistedResult);
      debugPrint(
        '[DB] Saved pose result: ${result.poseName} '
        '(score=${result.bestScore.toStringAsFixed(1)}%) '
        'xp=+${gamificationResult.xpGained} '
        'badges=${gamificationResult.unlockedBadges.length}',
      );
    } catch (e) {
      debugPrint('[DB] Failed to save pose result: $e');
    } finally {
      _isSavingResult = false;
    }
  }

  /// Toggle wide lens mode (zoom out to widest FOV).
  Future<void> _toggleWideLens() async {
    final newState = !_isWideLens;
    try {
      await _cameraService.setWideLens(newState);
      if (mounted) setState(() => _isWideLens = newState);
    } catch (e) {
      debugPrint('[WideLens] Error toggling wide lens: $e');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

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
                const Icon(Icons.videocam_off_rounded,
                    color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Camera error',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_errorMessage',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
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
                  color: const Color(0xFF4A9B8E),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Initialising camera…',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w500),
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
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      widget.poseTemplate.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Manrope',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Wide lens toggle
                GestureDetector(
                  onTap: _toggleWideLens,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _isWideLens
                          ? const Color(0xFF4A9B8E).withValues(alpha: 0.55)
                          : Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Icon(
                      _isWideLens ? Icons.zoom_in_map : Icons.zoom_out_map,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Status HUD (score + hold) ─────────────────────────────────
          _buildStatusHud(),

          // ── Feedback pills ────────────────────────────────────────────
          _buildFeedbackCard(),

          // ── Completion card overlay ───────────────────────────────────
          ValueListenableBuilder<PoseResult?>(
            valueListenable: _poseResultNotifier,
            builder: (context, result, _) {
              if (result == null) return const SizedBox.shrink();
              return Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.60),
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.88, end: 1.0),
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: _buildCompletionCard(result),
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
          _smoothedSimilarityNotifier,
          _holdProgressNotifier,
          _holdSecondsNotifier,
          _poseStableNotifier,
        ]),
        builder: (context, _) {
          final score = _smoothedSimilarityNotifier.value;
          final progress =
              _holdProgressNotifier.value.clamp(0.0, 1.0).toDouble();
          final seconds = _holdSecondsNotifier.value;
          final durationSeconds =
              _poseSessionService.holdDuration.inMilliseconds / 1000.0;
          final threshold = _poseSessionService.scoreThreshold;
          final isStable = _poseStableNotifier.value;
          final holdActive = score >= threshold && isStable;

          // Score colour tiers
          final Color scoreColor = score >= 80
              ? const Color(0xFF4ADBA8)
              : score >= threshold
                  ? const Color(0xFFFFD166)
                  : const Color(0xFFFF8C66);
          final Color barColor =
              holdActive ? const Color(0xFF4ADBA8) : const Color(0xFF4A9B8E);

          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'POSE MATCH',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            fontFamily: 'Manrope',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${score.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: scoreColor,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Manrope',
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isStable
                            ? const Color(0xFF4ADBA8).withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isStable
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked,
                            color: isStable
                                ? const Color(0xFF4ADBA8)
                                : Colors.white54,
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isStable ? 'Stable' : 'Hold still',
                            style: TextStyle(
                              color: isStable
                                  ? const Color(0xFF4ADBA8)
                                  : Colors.white60,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Manrope',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Hold progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hold  ${seconds.toStringAsFixed(1)}s / '
                      '${durationSeconds.toStringAsFixed(0)}s',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Manrope',
                      ),
                    ),
                    if (!holdActive)
                      Text(
                        'Needs ≥${threshold.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontFamily: 'Manrope',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeedbackCard() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Positioned(
      bottom: bottomPad + 24,
      left: 12,
      right: 12,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _angleFeedbackNotifier,
          _feedbackNotifier,
          _poseResultNotifier,
        ]),
        builder: (context, _) {
          if (_poseResultNotifier.value != null) {
            return const SizedBox.shrink();
          }
          final combined = <String>[
            ..._angleFeedbackNotifier.value,
            ..._feedbackNotifier.value,
          ];
          if (combined.isEmpty) return const SizedBox.shrink();
          final shown = combined.take(2).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  'FEEDBACK',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    fontFamily: 'Manrope',
                  ),
                ),
              ),
              ...shown.map(
                (msg) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFFFD166).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.tips_and_updates_rounded,
                          color: Color(0xFFFFD166),
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            msg,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Manrope',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCompletionCard(PoseResult result) {
    final bestScoreText = '${result.bestScore.toStringAsFixed(0)}%';
    final holdTimeText = '${result.holdDuration.toStringAsFixed(1)}s';
    final buttonText =
        widget.completionActionLabel ??
        (widget.returnResultOnCompletion ? 'Continue' : 'Try Again');
    final score = result.bestScore;
    final Color scoreColor = score >= 80
        ? const Color(0xFF3D8B68)
        : score >= 60
            ? const Color(0xFFD4872A)
            : const Color(0xFFB33A3A);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
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
                colors: [Color(0xFF3F5A45), Color(0xFF4A9B8E)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pose Completed!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Manrope',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.poseName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.80),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Manrope',
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
                      style: TextStyle(
                        color: scoreColor,
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Manrope',
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Best',
                          style: TextStyle(
                            color: Color(0xFF5C6E5F),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Manrope',
                          ),
                        ),
                        Text(
                          'Score',
                          style: TextStyle(
                            color: Color(0xFF5C6E5F),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Manrope',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F1E7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: Color(0xFF5C6E5F),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Hold time: $holdTimeText',
                        style: const TextStyle(
                          color: Color(0xFF2D3A2E),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Manrope',
                        ),
                      ),
                    ],
                  ),
                ),
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
                            passed: result.bestScore >=
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
                    similarityScore: _smoothedSimilarityNotifier.value,
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
  double _combineScores(double distanceScore, double? angleScore) {
    if (angleScore == null) return distanceScore;
    const double distanceWeight = 0.6;
    const double angleWeight = 0.4;
    return (distanceScore * distanceWeight) + (angleScore * angleWeight);
  }
}
