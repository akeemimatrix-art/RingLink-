enum AccountRole { customer, provider, business, admin }

AccountRole accountRoleFromString(String? value) {
  switch (value) {
    case 'provider':
      return AccountRole.provider;
    case 'business':
      return AccountRole.business;
    case 'admin':
      return AccountRole.admin;
    default:
      return AccountRole.customer;
  }
}

String accountRoleToString(AccountRole role) {
  switch (role) {
    case AccountRole.customer:
      return 'customer';
    case AccountRole.provider:
      return 'provider';
    case AccountRole.business:
      return 'business';
    case AccountRole.admin:
      return 'admin';
  }
}

class AppProfile {
  const AppProfile({
    required this.id,
    required this.displayName,
    required this.accountRole,
    this.phone,
    this.avatarUrl,
    this.bio,
    this.city,
    this.isVerified = false,
  });

  final String id;
  final String displayName;
  final AccountRole accountRole;
  final String? phone;
  final String? avatarUrl;
  final String? bio;
  final String? city;
  final bool isVerified;

  factory AppProfile.fromMap(Map<String, dynamic> map) {
    final rawName = map['display_name'] as String?;
    return AppProfile(
      id: map['id'] as String,
      displayName: rawName?.trim().isNotEmpty == true
          ? rawName!
          : 'RingLink user',
      accountRole: accountRoleFromString(map['account_role'] as String?),
      phone: map['phone'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      bio: map['bio'] as String?,
      city: map['city'] as String?,
      isVerified: map['is_verified'] as bool? ?? false,
    );
  }
}

extension AccountRoleX on AccountRole {
  String get dbValue => accountRoleToString(this);

  String get label {
    switch (this) {
      case AccountRole.customer:
        return 'Customer';
      case AccountRole.provider:
        return 'Service Provider';
      case AccountRole.business:
        return 'Business / Group';
      case AccountRole.admin:
        return 'Administrator';
    }
  }
}

extension AppProfileX on AppProfile {
  AccountRole get role => accountRole;
}
