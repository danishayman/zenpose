/// ScoreSmoothingService applies a moving average filter to similarity scores
/// to reduce jitter while keeping latency low.
///
/// It maintains a fixed-size buffer of the most recent scores and updates the
/// smoothed value in O(1) time using a running sum.
class ScoreSmoothingService {
  /// Number of frames to include in the moving average.
  final int windowSize;

  /// Recent raw scores (oldest → newest).
  final List<double> _scoreBuffer = <double>[];

  double _sum = 0.0;
  double _smoothedScore = 0.0;

  ScoreSmoothingService({this.windowSize = 5}) : assert(windowSize > 0);

  /// Read-only view of the current buffer (useful for debugging).
  List<double> get scoreBuffer => List.unmodifiable(_scoreBuffer);

  /// Latest smoothed score.
  double get smoothedScore => _smoothedScore;

  /// Add a new raw [similarityScore] and return the updated smoothed score.
  double addScore(double similarityScore) {
    _scoreBuffer.add(similarityScore);
    _sum += similarityScore;

    if (_scoreBuffer.length > windowSize) {
      _sum -= _scoreBuffer.removeAt(0);
    }

    _smoothedScore =
        _scoreBuffer.isEmpty ? 0.0 : _sum / _scoreBuffer.length;
    return _smoothedScore;
  }

  /// Clear the buffer and reset the smoothed value.
  void reset() {
    _scoreBuffer.clear();
    _sum = 0.0;
    _smoothedScore = 0.0;
  }
}
