/// Lightweight 2D landmark model for normalized MediaPipe-style coordinates.
///
/// `x` and `y` are expected to be in the 0–1 range, relative to the input
/// image or preview size.
class Landmark {
  final double x;
  final double y;

  const Landmark({required this.x, required this.y});

  /// Sentinel for missing/invalid landmarks.
  static const Landmark invalid = Landmark(x: double.nan, y: double.nan);

  bool get isValid => !x.isNaN && !y.isNaN;
}
