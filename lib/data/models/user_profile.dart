class UserProfile {
  final String id;
  final int loginCount;
  final bool hasCompletedOnboarding;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    this.loginCount = 0,
    this.hasCompletedOnboarding = false,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      loginCount: (json['login_count'] as num?)?.toInt() ?? 0,
      hasCompletedOnboarding: json['has_completed_onboarding'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'login_count': loginCount,
      'has_completed_onboarding': hasCompletedOnboarding,
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    int? loginCount,
    bool? hasCompletedOnboarding,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      loginCount: loginCount ?? this.loginCount,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
