import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/data/models/user_profile.dart';

void main() {
  group('UserProfile', () {
    test('fromJson and toJson round-trip', () {
      final now = DateTime(2026, 9, 1);
      final json = {
        'id': 'user-999',
        'login_count': 5,
        'has_completed_onboarding': true,
        'created_at': now.toIso8601String(),
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, equals('user-999'));
      expect(profile.loginCount, equals(5));
      expect(profile.hasCompletedOnboarding, isTrue);

      final serialized = profile.toJson();
      expect(serialized['id'], equals('user-999'));
      expect(serialized['login_count'], equals(5));
      expect(serialized['has_completed_onboarding'], isTrue);
    });

    test('fromJson sets defaults when optional fields omitted', () {
      final json = {'id': 'user-1'};
      final profile = UserProfile.fromJson(json);

      expect(profile.id, equals('user-1'));
      expect(profile.loginCount, equals(0));
      expect(profile.hasCompletedOnboarding, isFalse);
      expect(profile.createdAt, isNotNull);
    });

    test('copyWith works correctly', () {
      final profile = UserProfile(
        id: 'u-1',
        loginCount: 1,
        hasCompletedOnboarding: false,
        createdAt: DateTime.now(),
      );

      final updated = profile.copyWith(
        loginCount: 2,
        hasCompletedOnboarding: true,
      );

      expect(updated.loginCount, equals(2));
      expect(updated.hasCompletedOnboarding, isTrue);
      expect(updated.id, equals('u-1'));
    });
  });
}
