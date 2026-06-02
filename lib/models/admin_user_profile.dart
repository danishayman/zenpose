import 'account_access.dart';

class AdminUserProfile {
  final String userId;
  final String email;
  final String? displayName;
  final AccountRole role;
  final AccountStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AdminUserProfile({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAdmin => role == AccountRole.admin;
  bool get isActive => status == AccountStatus.active;

  factory AdminUserProfile.fromMap(Map<String, dynamic> map) {
    return AdminUserProfile(
      userId: map['user_id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      displayName: _toNullableTrimmedString(map['display_name']),
      role: AccountRoleX.fromDbValue(map['role']?.toString()),
      status: AccountStatusX.fromDbValue(map['status']?.toString()),
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static String? _toNullableTrimmedString(Object? value) {
    final str = value?.toString().trim();
    if (str == null || str.isEmpty) return null;
    return str;
  }
}
