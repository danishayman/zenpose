import 'dart:ui' show Size;
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// CameraService manages the device camera lifecycle and image streaming.
///
/// It initialises the front-facing camera, starts an image stream, and converts
/// each [CameraImage] into an [InputImage] suitable for ML Kit processing.
/// A "skip-if-busy" flag prevents frame backpressure when the pose detector
/// is still processing the previous frame.
class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  static const double _wideLensEpsilon = 0.01;

  /// Whether the service has been successfully initialised.
  bool get isInitialised => _controller?.value.isInitialized ?? false;

  /// The camera controller (exposed for [CameraPreview] widget).
  CameraController? get controller => _controller;

  /// Guard flag – true while the pose detector is processing a frame.
  bool isProcessing = false;

  /// Whether wide lens (minimum zoom) is currently active.
  bool _isWideLens = false;
  bool get isWideLens => _isWideLens;
  bool _hasWideLens = false;
  bool get hasWideLens => _hasWideLens;

  /// Initialise the camera.
  ///
  /// Always selects the front-facing camera and opens it at low resolution
  /// (good balance between quality and inference speed).
  ///
  /// After init, it applies the "wide-lens only" policy by switching to the
  /// minimum zoom level when true wide FOV is supported on the device.
  Future<void> initialise() async {
    const direction = CameraLensDirection.front;
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      throw Exception('No cameras available on this device.');
    }

    // Prefer the requested direction; fall back to first available.
    final camera = _cameras.firstWhere(
      (c) => c.lensDirection == direction,
      orElse: () => _cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.low,
      enableAudio: false, // no mic needed
      imageFormatGroup: ImageFormatGroup.nv21, // best for Android ML Kit
    );

    await _controller!.initialize();
    await useWideLensOnlyIfAvailable();
  }

  /// Get the minimum zoom level supported by the camera.
  Future<double> getMinZoomLevel() async {
    if (_controller == null || !_controller!.value.isInitialized) return 1.0;
    return _controller!.getMinZoomLevel();
  }

  /// Set the camera zoom level.
  Future<void> setZoomLevel(double level) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    await _controller!.setZoomLevel(level);
  }

  /// Enforce "wide-lens only" policy where available.
  ///
  /// Returns true when true wide mode is available and applied (min zoom < 1x).
  /// Returns false when the device has no wider-than-1x front-camera zoom.
  Future<bool> useWideLensOnlyIfAvailable() async {
    if (_controller == null || !_controller!.value.isInitialized) return false;
    final minZoom = await _controller!.getMinZoomLevel();
    _hasWideLens = minZoom < (1.0 - _wideLensEpsilon);
    if (_hasWideLens) {
      await _controller!.setZoomLevel(minZoom);
      _isWideLens = true;
      return true;
    }

    await _controller!.setZoomLevel(1.0);
    _isWideLens = false;
    return false;
  }

  /// Legacy entry point kept for compatibility.
  ///
  /// This app now runs in wide-lens-only mode, so disabling wide lens is
  /// intentionally ignored.
  Future<void> setWideLens(bool enabled) async {
    if (!enabled) return;
    await useWideLensOnlyIfAvailable();
  }

  /// Start streaming camera frames.
  ///
  /// [onFrame] is called for every frame that is *not* dropped by the
  /// skip-if-busy guard. The caller must set [isProcessing] back to false
  /// once detection completes.
  void startImageStream(Function(InputImage inputImage) onFrame) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    _controller!.startImageStream((CameraImage image) {
      // Skip frame if detector is still busy with the previous one.
      if (isProcessing) return;
      isProcessing = true;

      final inputImage = _convertCameraImage(image);
      if (inputImage != null) {
        onFrame(inputImage);
      } else {
        isProcessing = false;
      }
    });
  }

  /// Stop the image stream (e.g. on pause).
  Future<void> stopImageStream() async {
    if (_controller != null &&
        _controller!.value.isInitialized &&
        _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
  }

  /// Convert a [CameraImage] to an ML Kit [InputImage].
  InputImage? _convertCameraImage(CameraImage image) {
    final camera = _controller!.description;
    final sensorOrientation = camera.sensorOrientation;

    // Determine rotation for ML Kit based on sensor orientation.
    InputImageRotation? rotation;
    switch (sensorOrientation) {
      case 0:
        rotation = InputImageRotation.rotation0deg;
        break;
      case 90:
        rotation = InputImageRotation.rotation90deg;
        break;
      case 180:
        rotation = InputImageRotation.rotation180deg;
        break;
      case 270:
        rotation = InputImageRotation.rotation270deg;
        break;
      default:
        rotation = InputImageRotation.rotation0deg;
    }

    // Build InputImage from bytes (NV21 on Android).
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  /// The camera description (needed by the skeleton painter for mirroring).
  CameraDescription? get cameraDescription => _controller?.description;

  /// Dispose the camera controller.
  Future<void> dispose() async {
    await stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }
}
