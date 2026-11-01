class UserSummary {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String userType;
  final String role;

  const UserSummary({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.userType,
    required this.role,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      userType: json['user_type'] as String? ?? 'staff',
      role: json['role'] as String? ?? 'owner',
    );
  }
}

class TenantSummary {
  final String id;
  final String name;
  final String slug;

  const TenantSummary({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory TenantSummary.fromJson(Map<String, dynamic> json) {
    return TenantSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
    );
  }
}

class OutletSummary {
  final String id;
  final String name;

  const OutletSummary({
    required this.id,
    required this.name,
  });

  factory OutletSummary.fromJson(Map<String, dynamic> json) {
    return OutletSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class SubscriptionSummary {
  final String plan;
  final String status;

  const SubscriptionSummary({
    required this.plan,
    required this.status,
  });

  factory SubscriptionSummary.fromJson(Map<String, dynamic> json) {
    return SubscriptionSummary(
      plan: json['plan'] as String? ?? 'free',
      status: json['status'] as String? ?? 'active',
    );
  }
}

class TokensModel {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;

  const TokensModel({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
  });

  factory TokensModel.fromJson(Map<String, dynamic> json) {
    return TokensModel(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 1800,
    );
  }
}

class AuthDataModel {
  final UserSummary user;
  final TenantSummary tenant;
  final OutletSummary outlet;
  final SubscriptionSummary subscription;
  final TokensModel tokens;

  const AuthDataModel({
    required this.user,
    required this.tenant,
    required this.outlet,
    required this.subscription,
    required this.tokens,
  });

  factory AuthDataModel.fromJson(Map<String, dynamic> json) {
    return AuthDataModel(
      user: UserSummary.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
      tenant: TenantSummary.fromJson(json['tenant'] as Map<String, dynamic>? ?? {}),
      outlet: OutletSummary.fromJson(json['outlet'] as Map<String, dynamic>? ?? {}),
      subscription: SubscriptionSummary.fromJson(json['subscription'] as Map<String, dynamic>? ?? {}),
      tokens: TokensModel.fromJson(json['tokens'] as Map<String, dynamic>? ?? {}),
    );
  }
}
