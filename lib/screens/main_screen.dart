import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/pose_frame.dart';
import '../services/angle_calculation_service.dart';
import '../services/camera_service.dart';
import '../services/landmark_smoothing_service.dart';
import '../services/pose_detection_service.dart';
import '../painters/skeleton_painter.dart';

/// MainScreen composes the camera preview and skeleton overlay.
///
/// It orchestrates:
///  1. Camera initialisation and image streaming via [CameraService].
///  2. Pose detection on each frame via [PoseDetectionService].
///  3. Overlay rendering via [SkeletonPainter] on a [CustomPaint].
///  4. Lifecycle management (pause / resume camera on app state changes).
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  // ── Services ──────────────────────────────────────────────────────────────

  final CameraService _cameraService = CameraService();
  final PoseDetectionService _poseDetectionService = PoseDetectionService();
  final AngleCalculationService _angleService = AngleCalculationService();
  final LandmarkSmoothingService _smoothingService = LandmarkSmoothingService();

  // ── State ─────────────────────────────────────────────────────────────────

  /// Use ValueNotifier so only the skeleton overlay repaints, not the whole tree.
  final ValueNotifier<List<Pose>> _posesNotifier = ValueNotifier([]);

  /// Computed joint angles for the current frame.
  final ValueNotifier<Map<String, double>> _anglesNotifier = ValueNotifier({});

  /// Whether the camera has finished initialising.
  bool _isCameraReady = false;

  /// Error message to show if initialisation fails.
  String? _errorMessage;

  /// Whether a camera switch is currently in progress.
  bool _isSwitching = false;

  /// Simple FPS counter for debug overlay.
  final ValueNotifier<double> _fpsNotifier = ValueNotifier(0);
  int _frameCount = 0;
  DateTime _lastFpsUpdate = DateTime.now();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _posesNotifier.dispose();
    _anglesNotifier.dispose();
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
        _anglesNotifier.value = {};
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

  /// Switch between front and back camera.
  Future<void> _switchCamera() async {
    if (_isSwitching) return;
    setState(() => _isSwitching = true);

    try {
      await _cameraService.stopImageStream();
      await _cameraService.switchCamera();
      _smoothingService.reset(); // Clear stale filter state.
      if (!mounted) return;
      _startDetection();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSwitching = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Error state.
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Camera error:\n$_errorMessage',
              style: const TextStyle(color: Colors.redAccent, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Loading state.
    if (!_isCameraReady) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Initialising camera…',
                style: TextStyle(color: Colors.white70, fontSize: 14),
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
          // ── Camera preview + skeleton overlay (same size) ────────────────
          _buildCameraWithOverlay(),

          // ── FPS debug overlay ─────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: ValueListenableBuilder<double>(
              valueListenable: _fpsNotifier,
              builder: (context, fps, _) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'FPS: ${fps.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // ── Pose count overlay ────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: ValueListenableBuilder<List<Pose>>(
              valueListenable: _posesNotifier,
              builder: (context, poses, _) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Landmarks: ${poses.isNotEmpty ? poses.first.landmarks.length : 0}',
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // ── Joint angles debug overlay ─────────────────────────────────────
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 90,
            left: 12,
            child: ValueListenableBuilder<Map<String, double>>(
              valueListenable: _anglesNotifier,
              builder: (context, angles, _) {
                if (angles.isEmpty) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: angles.entries.map((e) {
                      final label =
                          AngleCalculationService.jointLabels[e.key] ?? e.key;
                      return Text(
                        '$label: ${e.value.toStringAsFixed(0)}°',
                        style: const TextStyle(
                          color: Colors.yellowAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),

          // ── Camera switch button ──────────────────────────────────────────
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                onPressed: _isSwitching ? null : _switchCamera,
                backgroundColor: Colors.black54,
                child: Icon(
                  _cameraService.currentLensDirection ==
                          CameraLensDirection.back
                      ? Icons.camera_front
                      : Icons.camera_rear,
                  color: Colors.white,
                ),
              ),
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
                return CustomPaint(
                  painter: SkeletonPainter(
                    poses: poses,
                    imageSize: _cameraImageSize,
                    lensDirection:
                        _cameraService.cameraDescription?.lensDirection ??
                        CameraLensDirection.back,
                    rotation: _sensorRotation,
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

  /// Map sensor orientation to [InputImageRotation].
  InputImageRotation get _sensorRotation {
    final orientation =
        _cameraService.cameraDescription?.sensorOrientation ?? 0;
    switch (orientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }
}
