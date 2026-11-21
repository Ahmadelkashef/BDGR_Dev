import 'package:flutter/material.dart';

import 'account_settings_page.dart';
import 'app_preferences_page.dart';
import 'help_support_page.dart';
import 'login_security_page.dart';
import 'notification_settings_page.dart';
import 'privacy_settings_page.dart';
import 'terms_privacy_page.dart';

/// صفحات قايمة الترس في الهوم. المفتاح = value بتاع العنصر في القايمة.
/// بتتفتح جوه Navigator التاب، فالشريط اللي تحت بيفضل ظاهر.
final Map<String, WidgetBuilder> kSettingsPages = {
  'account-settings': (_) => const AccountSettingsPage(),
  'login-security': (_) => const LoginSecurityPage(),
  'privacy-settings': (_) => const PrivacySettingsPage(),
  'notification-settings': (_) => const NotificationSettingsPage(),
  'app-preferences': (_) => const AppPreferencesPage(),
  'help-support': (_) => const HelpSupportPage(),
  'terms-privacy': (_) => const TermsPrivacyPage(),
};

/// بترجع false لو المفتاح مش ليه صفحة
/// onClosed: بيتنده لما اليوزر يرجع (مثلاً علشان الهوم تتحدث لو اللغة اتغيرت)
bool openSettingsPage(BuildContext context, String key, {VoidCallback? onClosed}) {
  final builder = kSettingsPages[key];
  if (builder == null) return false;
  Navigator.of(context).push(MaterialPageRoute<void>(builder: builder)).then((_) => onClosed?.call());
  return true;
}
