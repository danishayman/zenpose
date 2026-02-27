import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../services/camera_service.dart';
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

  // ── State ─────────────────────────────────────────────────────────────────

  /// Most recently detected poses (updated every frame).
  List<Pose> _detectedPoses = [];

  /// Whether the camera has finished initialising.
  bool _isCameraReady = false;

  /// Error message to show if initialisation fails.
  String? _errorMessage;

  /// Simple FPS counter for debug overlay.
  int _frameCount = 0;
  double _fps = 0;
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

      // Update FPS counter.
      _frameCount++;
      final now = DateTime.now();
      final elapsed = now.difference(_lastFpsUpdate).inMilliseconds;
      if (elapsed >= 1000) {
        _fps = _frameCount / (elapsed / 1000.0);
        _frameCount = 0;
        _lastFpsUpdate = now;
      }

      // Update the overlay.
      if (mounted) {
        setState(() {
          _detectedPoses = poses;
        });
      }

      // Release the busy-guard so the next frame can be processed.
      _cameraService.isProcessing = false;
    });
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
          // ── Camera preview (full-screen) ──────────────────────────────────
          _buildCameraPreview(),

          // ── Skeleton overlay ──────────────────────────────────────────────
          if (_detectedPoses.isNotEmpty)
            CustomPaint(
              painter: SkeletonPainter(
                poses: _detectedPoses,
                imageSize: _cameraImageSize,
                lensDirection:
                    _cameraService.cameraDescription?.lensDirection ??
                    CameraLensDirection.back,
                rotation: _sensorRotation,
              ),
            ),

          // ── FPS debug overlay ─────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'FPS: ${_fps.toStringAsFixed(1)}',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // ── Pose count overlay ────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Landmarks: ${_detectedPoses.isNotEmpty ? _detectedPoses.first.landmarks.length : 0}',
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the camera preview widget, scaled to fill the screen.
  Widget _buildCameraPreview() {
    final controller = _cameraService.controller!;
    final previewAspectRatio = controller.value.aspectRatio;

    return Center(
      child: AspectRatio(
        aspectRatio: 1 / previewAspectRatio, // portrait
        child: CameraPreview(controller),
      ),
    );
  }

  /// The image size reported by the camera (width × height in sensor coords).
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
