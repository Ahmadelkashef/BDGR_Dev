import 'package:flutter/foundation.dart';

import '../app_config.dart';

class AccountInfo {
  const AccountInfo({
    required this.exists,
    required this.onboardingCompleted,
  });

  final bool exists;
  final bool onboardingCompleted;
}

/// هل اليوزر عنده حساب وخلّص التسجيل؟
Future<AccountInfo> getMyAccount() async {
  final data = await supa.rpc('get_my_account');

  dynamic row = data;
  if (data is List) {
    row = data.isNotEmpty ? data.first : null;
  }

  if (row is Map) {
    final exists      = row['out_exists'] == true;
    final completedAt = row['out_onboarding_completed_at'];
    final completed   = completedAt != null &&
        completedAt.toString().trim().isNotEmpty;

    return AccountInfo(exists: exists, onboardingCompleted: completed);
  }

  return const AccountInfo(exists: false, onboardingCompleted: false);
}

/// أول كلمة من اسم اليوزر، أو fallback
Future<String> getMyFirstName({String fallback = 'Player'}) async {
  try {
    final data = await supa.rpc('get_my_display_name');

    if (data is List && data.isNotEmpty) {
      final row = data.first;
      if (row is Map) {
        final name = (row['out_display_name'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          return name.split(RegExp(r'\s+')).first;
        }
      }
    }
  } catch (e) {
    debugPrint('Display name lookup error: $e');
  }

  return fallback;
}
