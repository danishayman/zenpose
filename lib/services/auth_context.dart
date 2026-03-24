/// Lightweight in-memory auth context used by local services.
///
/// Defaults to a local offline profile until a real auth session is restored.
class AuthContext {
  static const String localUserId = '__local__';

  static String _activeUserId = localUserId;

  static String get activeUserId => _activeUserId;

  static bool get isLocalProfile => _activeUserId == localUserId;

  static void setActiveUserId(String? userId) {
    final normalized = userId?.trim();
    _activeUserId = (normalized == null || normalized.isEmpty)
        ? localUserId
        : normalized;
  }
}
