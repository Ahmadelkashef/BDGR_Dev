import 'package:flutter/material.dart';

import '../app_lang.dart';
import '../local_store.dart';
import 'push_service.dart';

/// owner 28 Nov: the notification permission is asked after a squad save (not at app open).
/// Shows the explainer once per phone (flag push_prompt_shown) when the phone was never asked.
/// Returns true when the sheet was shown (the save flow then shows nothing else that time).
Future<bool> maybeAskPush(BuildContext context) async {
  if (!PushService.supported) return false;
  if (await LocalStore.getFlag('push_prompt_shown') || !await PushService.notAskedYet()) return false;
  await LocalStore.setFlag('push_prompt_shown');
  if (!context.mounted) return false;
  final yes = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    backgroundColor: const Color(0xFF16171C),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Directionality(
      textDirection: AppLang.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Icon(Icons.notifications_active_outlined, color: Colors.white70, size: 32),
          const SizedBox(height: 12),
          Text(AppLang.t("Don't miss the next deadline", 'ماتفوّتش الديدلاين الجاي'), textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(AppLang.t('Turn on notifications and BDGR will remind you before the round closes, and tell you when your points are out. You choose what you get in Settings.',
                  'شغّل الإشعارات وBDGR هيفكّرك قبل ما الجولة تقفل، ويبلّغك لما نقطك تنزل. وانت بتختار يوصلك إيه من الإعدادات.'),
              textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFA6AAB5), fontSize: 13, height: 1.7)),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF1A1A), foregroundColor: Colors.white,
                elevation: 0, padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(AppLang.t('Turn on', 'شغّلها'), style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLang.t('Not now', 'بعدين'), style: const TextStyle(color: Color(0xFFA6AAB5))),
          ),
        ]),
      )),
    ),
  );
  if (yes == true) await PushService.requestAndRegister();
  return true;
}

/// The small "🔔 Remind me before the deadline" line inside the first-achievement screen (no extra popup).
class PushRemindButton extends StatefulWidget {
  const PushRemindButton({super.key});
  @override
  State<PushRemindButton> createState() => _PushRemindButtonState();
}

class _PushRemindButtonState extends State<PushRemindButton> {
  bool _show = false, _done = false;

  @override
  void initState() {
    super.initState();
    () async {
      if (!PushService.supported) return;
      final ask = !await LocalStore.getFlag('push_prompt_shown') && await PushService.notAskedYet();
      if (mounted) setState(() => _show = ask);
    }();
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextButton.icon(
        onPressed: _done ? null : () async {
          await LocalStore.setFlag('push_prompt_shown');
          final ok = await PushService.requestAndRegister();
          if (mounted) setState(() => _done = true);
          if (!ok && mounted) setState(() => _show = false);
        },
        icon: Icon(_done ? Icons.check_circle : Icons.notifications_active_outlined,
            size: 18, color: _done ? const Color(0xFF4CAF50) : const Color(0xFFFFD27A)),
        label: Text(_done ? AppLang.t("We'll remind you ✓", 'هنفكّرك ✓')
                          : AppLang.t('Remind me before the deadline', 'فكّرني قبل الديدلاين'),
            style: TextStyle(color: _done ? const Color(0xFF4CAF50) : const Color(0xFFFFD27A), fontWeight: FontWeight.w800)),
      ),
    );
  }
}
