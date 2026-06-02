enum AccountRole { user, admin }

extension AccountRoleX on AccountRole {
  String get dbValue => this == AccountRole.admin ? 'admin' : 'user';

  static AccountRole fromDbValue(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'admin':
        return AccountRole.admin;
      case 'user':
      default:
        return AccountRole.user;
    }
  }
}

enum AccountStatus { active, inactive }

extension AccountStatusX on AccountStatus {
  String get dbValue => this == AccountStatus.inactive ? 'inactive' : 'active';

  static AccountStatus fromDbValue(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'inactive':
        return AccountStatus.inactive;
      case 'active':
      default:
        return AccountStatus.active;
    }
  }
}
