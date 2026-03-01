import 'dart:math' as math;

import '../models/pose_landmark_model.dart';

/// Applies temporal smoothing to pose landmarks using the **One Euro Filter**
/// algorithm, eliminating jitter when stationary while maintaining responsive
/// tracking during fast motion.
///
/// ## Usage
///
/// ```dart
/// final smoother = LandmarkSmoothingService();
/// final smoothed = smoother.smooth(rawLandmarks);
/// ```
///
/// Call [reset] when switching cameras or re-initialising to clear filter state.
class LandmarkSmoothingService {
  /// Minimum cutoff frequency (Hz). Lower = smoother when still, more lag.
  final double minCutoff;

  /// Speed coefficient. Higher = less lag during fast motion, more jitter.
  final double beta;

  /// Cutoff frequency for the derivative filter.
  final double dCutoff;

  LandmarkSmoothingService({
    this.minCutoff = 1.7,
    this.beta = 0.007,
    this.dCutoff = 1.0,
  });

  /// One filter per landmark per axis: [landmarkIndex][0=x, 1=y, 2=z].
  List<List<_OneEuroFilter>>? _filters;

  /// Timestamp of the previous frame (for computing dt).
  DateTime? _lastTimestamp;

  /// Smooth a list of landmarks, returning new instances with filtered x/y/z.
  ///
  /// Confidence values are passed through unmodified.
  List<PoseLandmark> smooth(List<PoseLandmark> landmarks) {
    final now = DateTime.now();
    final dt = _lastTimestamp != null
        ? now.difference(_lastTimestamp!).inMicroseconds / 1e6
        : 1.0 / 30.0; // assume 30 fps for the first frame
    _lastTimestamp = now;

    // Guard against zero or negative dt (e.g. clock jumps).
    final safeDt = dt.clamp(0.001, 0.5);

    // Lazily initialise filters on first call or if landmark count changes.
    if (_filters == null || _filters!.length != landmarks.length) {
      _filters = List.generate(
        landmarks.length,
        (_) => List.generate(
          3, // x, y, z
          (_) => _OneEuroFilter(
            minCutoff: minCutoff,
            beta: beta,
            dCutoff: dCutoff,
          ),
        ),
      );
    }

    return List.generate(landmarks.length, (i) {
      final lm = landmarks[i];

      // Don't smooth invalid (low-confidence) landmarks — pass through as-is.
      if (!lm.isValid) {
        // Reset this landmark's filters so we don't carry stale state.
        for (final f in _filters![i]) {
          f.reset();
        }
        return lm;
      }

      final sx = _filters![i][0].filter(lm.x, safeDt);
      final sy = _filters![i][1].filter(lm.y, safeDt);
      final sz = _filters![i][2].filter(lm.z, safeDt);

      return lm.copyWith(x: sx, y: sy, z: sz);
    });
  }

  /// Clear all filter state (call on camera switch, etc.).
  void reset() {
    _filters = null;
    _lastTimestamp = null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// One Euro Filter implementation
// Reference: https://cristal.univ-lille.fr/~casiez/1euro/
// ─────────────────────────────────────────────────────────────────────────────

/// Low-pass filter using exponential smoothing.
class _LowPassFilter {
  double? _hatXPrev;
  bool _isInitialised = false;

  double filter(double x, double alpha) {
    if (!_isInitialised) {
      _isInitialised = true;
      _hatXPrev = x;
      return x;
    }
    final hatX = alpha * x + (1.0 - alpha) * _hatXPrev!;
    _hatXPrev = hatX;
    return hatX;
  }

  double get hatXPrev => _hatXPrev ?? 0;

  void reset() {
    _hatXPrev = null;
    _isInitialised = false;
  }
}

/// One Euro Filter — an adaptive low-pass filter for noisy real-time signals.
///
/// At low speeds (stationary) it uses a low cutoff → very smooth output.
/// At high speeds (fast motion) it raises the cutoff → minimal lag.
class _OneEuroFilter {
  final double minCutoff;
  final double beta;
  final double dCutoff;

  final _LowPassFilter _xFilter = _LowPassFilter();
  final _LowPassFilter _dxFilter = _LowPassFilter();

  _OneEuroFilter({
    required this.minCutoff,
    required this.beta,
    required this.dCutoff,
  });

  /// Compute the smoothing factor α from a cutoff frequency and time step.
  static double _alpha(double cutoff, double dt) {
    final tau = 1.0 / (2.0 * math.pi * cutoff);
    return 1.0 / (1.0 + tau / dt);
  }

  /// Filter a new value [x] with the time delta [dt] since the last call.
  double filter(double x, double dt) {
    // Estimate the derivative (speed) of the signal.
    final prevX = _xFilter.hatXPrev;
    final dx = _xFilter._isInitialised ? (x - prevX) / dt : 0.0;
    final edx = _dxFilter.filter(dx, _alpha(dCutoff, dt));

    // Adaptive cutoff: raise it when moving fast.
    final cutoff = minCutoff + beta * edx.abs();

    // Apply the main low-pass filter with the adaptive alpha.
    return _xFilter.filter(x, _alpha(cutoff, dt));
  }

  void reset() {
    _xFilter.reset();
    _dxFilter.reset();
  }
}
