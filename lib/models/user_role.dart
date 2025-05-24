enum UserRole {
  admin,
  accountant,
  owner,
  employee,
  guest,
  client,
  worker,
  manager,
  user,
  pending;

  String get name {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.accountant:
        return 'Accountant';
      case UserRole.owner:
        return 'Owner';
      case UserRole.employee:
        return 'Employee';
      case UserRole.guest:
        return 'Guest';
      case UserRole.client:
        return 'Client';
      case UserRole.worker:
        return 'Worker';
      case UserRole.manager:
        return 'Manager';
      case UserRole.user:
        return 'User';
      case UserRole.pending:
        return 'Pending';
    }
  }

  String get value => toString().split('.').last;

  bool get canLogin {
    switch (this) {
      case UserRole.admin:
      case UserRole.manager:
      case UserRole.worker:
      case UserRole.accountant:
      case UserRole.client:
      case UserRole.owner:
      case UserRole.user:
      case UserRole.employee:
        return true;
      case UserRole.guest:
      case UserRole.pending:
        return false;
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'مدير النظام';
      case UserRole.manager:
        return 'مدير';
      case UserRole.worker:
        return 'عامل';
      case UserRole.accountant:
        return 'محاسب';
      case UserRole.client:
        return 'عميل';
      case UserRole.owner:
        return 'مالك';
      case UserRole.user:
        return 'مستخدم';
      case UserRole.employee:
        return 'موظف';
      case UserRole.guest:
        return 'زائر';
      case UserRole.pending:
        return 'قيد الانتظار';
    }
  }

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.toString().split('.').last.toLowerCase() == value.toLowerCase(),
      orElse: () => UserRole.guest,
    );
  }

  String toJson() => value;
  static UserRole fromJson(String json) => fromString(json);
}

// Extension to be used throughout the app
extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'مدير النظام';
      case UserRole.manager:
        return 'مدير';
      case UserRole.worker:
        return 'عامل';
      case UserRole.accountant:
        return 'محاسب';
      case UserRole.client:
        return 'عميل';
      case UserRole.owner:
        return 'مالك';
      case UserRole.user:
        return 'مستخدم';
      case UserRole.pending:
        return 'قيد الانتظار';
    }
  }

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.name.toLowerCase() == value.toLowerCase(),
      orElse: () => UserRole.pending,
    );
  }
} 