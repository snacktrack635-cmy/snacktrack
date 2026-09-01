import '../../core/constants/tier_limits.dart';

enum SubscriptionProvider {
  stripe,
  apple,
  google,
}

class UserSubscription {
  final String id;
  final String userId;
  final SubscriptionTier tier;
  final SubscriptionProvider? provider;
  final String? providerSubscriptionId;
  final String status;
  final DateTime? currentPeriodEnd;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserSubscription({
    required this.id,
    required this.userId,
    this.tier = SubscriptionTier.free,
    this.provider,
    this.providerSubscriptionId,
    this.status = 'active',
    this.currentPeriodEnd,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'active';

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tier: _parseTier(json['tier'] as String?),
      provider: _parseProvider(json['provider'] as String?),
      providerSubscriptionId: json['provider_subscription_id'] as String?,
      status: json['status'] as String? ?? 'active',
      currentPeriodEnd: json['current_period_end'] != null
          ? DateTime.parse(json['current_period_end'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'tier': tier.name,
      'provider': provider?.name,
      'provider_subscription_id': providerSubscriptionId,
      'status': status,
      'current_period_end': currentPeriodEnd?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static SubscriptionTier _parseTier(String? tier) {
    switch (tier) {
      case 'plus':
        return SubscriptionTier.plus;
      case 'pro':
        return SubscriptionTier.pro;
      default:
        return SubscriptionTier.free;
    }
  }

  static SubscriptionProvider? _parseProvider(String? provider) {
    switch (provider) {
      case 'stripe':
        return SubscriptionProvider.stripe;
      case 'apple':
        return SubscriptionProvider.apple;
      case 'google':
        return SubscriptionProvider.google;
      default:
        return null;
    }
  }
}

class UsageCounter {
  final String userId;
  final DateTime periodStart;
  final int scansUsed;
  final int recipesGenerated;

  const UsageCounter({
    required this.userId,
    required this.periodStart,
    this.scansUsed = 0,
    this.recipesGenerated = 0,
  });

  factory UsageCounter.fromJson(Map<String, dynamic> json) {
    return UsageCounter(
      userId: json['user_id'] as String,
      periodStart: json['period_start'] != null
          ? DateTime.parse(json['period_start'] as String)
          : DateTime.now(),
      scansUsed: (json['scans_used'] as num?)?.toInt() ?? 0,
      recipesGenerated: (json['recipes_generated'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'period_start': periodStart.toIso8601String(),
      'scans_used': scansUsed,
      'recipes_generated': recipesGenerated,
    };
  }

  UsageCounter copyWith({
    String? userId,
    DateTime? periodStart,
    int? scansUsed,
    int? recipesGenerated,
  }) {
    return UsageCounter(
      userId: userId ?? this.userId,
      periodStart: periodStart ?? this.periodStart,
      scansUsed: scansUsed ?? this.scansUsed,
      recipesGenerated: recipesGenerated ?? this.recipesGenerated,
    );
  }
}
