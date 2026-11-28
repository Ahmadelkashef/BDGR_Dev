import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_config.dart';
import '../device_telemetry.dart';
import 'account_service.dart';
import 'login_config.dart';
import '../local_store.dart';

enum AuthDestination { home, onboarding, error }

class AuthResult {
  const AuthResult._(this.destination, this.reason);
  const AuthResult.home()                : this._(AuthDestination.home,        null);
  const AuthResult.onboarding()          : this._(AuthDestination.onboarding,  null);
  const AuthResult.error(String reason)  : this._(AuthDestination.error,       reason);

  final AuthDestination destination;
  final String?         reason;
}

/// فحص تطابق الجهاز: فشله لا يمنع الدخول
Future<void> _runDeviceMatchCheck(DeviceTelemetry t) async {
  try {
    await supa.rpc(
      'check_device_match',
      params: {'p_client_device_id': t.clientDeviceId},
    );
  } catch (e) {
    debugPrint('check_device_match error: $e');
  }
}

/// المنطق الكامل بعد تأكيد الـ OTP
/// [provider] = google / facebook / x / tiktok لو الدخول بحساب، null لو بالـ OTP
Future<AuthResult> processAuthSession(Session session, {String? provider}) async {
  try {
    // 1) هل اليوزر عنده حساب؟
    AccountInfo account;
    try {
      account = await getMyAccount();
    } catch (e) {
      debugPrint('get_my_account error: $e');
      return const AuthResult.error('rpc_error');
    }

    final telemetry = await getDeviceTelemetry();

    // 2) حساب موجود
    if (account.exists) {
      try {
        await supa.rpc('log_app_login', params: {
          'p_client_device_id': telemetry.clientDeviceId,
          'p_platform':         telemetry.platform,
          'p_os_name':          telemetry.osName,
          'p_os_version':       telemetry.osVersion,
          'p_manufacturer':     telemetry.manufacturer,
          'p_model':            telemetry.model,
          'p_app_version':      telemetry.appVersion,
        });
      } catch (e) {
        debugPrint('log_app_login error: $e');
        return const AuthResult.error('login_rpc_error');
      }

      await _runDeviceMatchCheck(telemetry);

      if (provider != null) {
        try {
          await supa.rpc('sync_login_credential', params: {'p_provider': provider});
        } catch (e) {
          debugPrint('sync_login_credential error: $e'); // مش بيمنع الدخول
        }
      }

      return account.onboardingCompleted
          ? const AuthResult.home()
          : const AuthResult.onboarding();
    }

    // 3) يوزر جديد: أنشئ الحساب بالموبايل أو بالحساب (جوجل/فيسبوك/X/تيك توك)
    try {
      await supa.rpc(provider == null ? 'complete_phone_signup' : 'complete_social_signup', params: {
        if (provider != null) 'p_provider': provider,
        'p_platform':         telemetry.platform,
        'p_app_version':      telemetry.appVersion,
        'p_client_device_id': telemetry.clientDeviceId,
        'p_os_name':          telemetry.osName,
        'p_os_version':       telemetry.osVersion,
        'p_manufacturer':     telemetry.manufacturer,
        'p_model':            telemetry.model,
      });
    } catch (e) {
      debugPrint('signup error: $e');
      return const AuthResult.error('signup_rpc_error');
    }

    await _runDeviceMatchCheck(telemetry);
    return const AuthResult.onboarding();
  } catch (e) {
    debugPrint('processAuthSession unexpected: $e');
    return const AuthResult.error('unexpected');
  }
}

/// تكملة الأونبوردنج بعد إنشاء الحساب
Future<String?> completeOnboarding() async {
  final consents = await LocalStore.getPendingConsents();

  if (consents == null || !consents.terms) {
    return 'consent_missing';
  }

  if (supa.auth.currentSession == null) {
    return 'auth_error';
  }

  try {
    // جيب نسخة الشروط
    final legal = await LoginConfig.fetchLegalVersions();
    if (legal == null) return 'legal_versions_error';

    await supa.rpc('complete_onboarding', params: {
      'p_terms_accepted':        consents.terms,
      'p_privacy_acknowledged':  consents.terms,
      'p_marketing_consent':     consents.marketing ? 'yes' : 'no',
      'p_terms_version':         legal['terms'],
      'p_privacy_version':       legal['privacy'],
    });

    await LocalStore.clearPendingConsents();
    return null;
  } on PostgrestException catch (e) {
    debugPrint('complete_onboarding error: $e');
    return 'onboarding_rpc_error';
  } catch (e) {
    debugPrint('complete_onboarding unexpected: $e');
    return 'onboarding_error';
  }
}
