import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_lang.dart';
import '../push/push_service.dart';
import 'settings_ui.dart';

/// الإشعارات: اختيارات حقيقية بتتحفظ (notif_prefs_get / notif_prefs_save).
/// الـ Push لسه مش متركب — الاختيارات جاهزة تتطبق أول ما يشتغل.
/// 'marketing' هو نفس اختيار "العروض والأخبار" في صفحة الخصوصية.
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final _sb = Supabase.instance.client;
  Map<String, dynamic>? _d;
  bool _loading = true;
  bool _failed = false;
  final Set<String> _saving = {};
  bool? _phoneAllowed; // null = مش مدعوم على التطبيق ده

  bool get _ar => AppLang.isArabic;
  String _t(String en, String ar) => AppLang.t(en, ar);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _loadPhone() async {
    if (!PushService.supported) return;
    final ok = await PushService.isAllowed();
    if (mounted) setState(() => _phoneAllowed = ok);
  }

  Future<void> _turnOn() async {
    final asked = !await PushService.notAskedYet();
    final ok = await PushService.requestAndRegister();
    if (!mounted) return;
    setState(() => _phoneAllowed = ok);
    if (ok) {
      sToast(context, _t('Notifications are on ✓', 'الإشعارات اتفعّلت ✓'));
    } else if (asked) {
      // اتقفلت قبل كده: الموبايل مش هيسأل تاني، لازم من الإعدادات
      sToast(context, _t('Allow notifications for BDGR in your phone settings.', 'اسمح بإشعارات BDGR من إعدادات الموبايل.'));
      await Geolocator.openAppSettings();
    }
  }

  Future<void> _load() async {
    _loadPhone();
    setState(() { _loading = _d == null; _failed = false; });
    try {
      final res = await _sb.rpc('notif_prefs_get');
      if (!mounted) return;
      setState(() {
        _d = res is Map ? Map<String, dynamic>.from(res) : null;
        _loading = false;
        _failed = _d == null;
      });
    } catch (e) {
      debugPrint('notif_prefs_get error: $e');
      if (mounted) setState(() { _loading = false; _failed = true; });
    }
  }

  Future<void> _set(String key, bool value) async {
    final old = _d?[key];
    setState(() { _d?[key] = value; _saving.add(key); });
    try {
      final res = await _sb.rpc('notif_prefs_save', params: {'p': {key: value}});
      if (!mounted) return;
      setState(() => _d = res is Map ? Map<String, dynamic>.from(res) : _d);
    } catch (e) {
      debugPrint('notif_prefs_save error: $e');
      if (!mounted) return;
      setState(() => _d?[key] = old);
      sToast(context, _t("Couldn't save. Try again.", 'محصلش حفظ. جرّب تاني.'));
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }

  // الأنواع اللي بتتبعت فعلًا دلوقتي. الباقي محفوظ وجاهز، وعليه علامة "قريب" لحد ما يتبني.
  static const _live = {'fantasy_deadline', 'fantasy_results', 'squad_social', 'badger_cup', 'marketing'};

  Widget _row(IconData icon, String key, String title, String desc) => SRow(
        icon: icon,
        title: title,
        desc: desc,
        below: _live.contains(key) ? null
            : Align(alignment: AlignmentDirectional.centerStart, child: SPill(_t('Coming soon', 'قريب'))),
        trailing: _saving.contains(key)
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: SC.accent, strokeWidth: 2))
            : SSwitch(value: _d?[key] != false, onChanged: (v) => _set(key, v)),
      );

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
        child: _loading
            ? const Scaffold(backgroundColor: SC.bg,
                body: Center(child: CircularProgressIndicator(color: SC.accent, strokeWidth: 2)))
            : _failed
                ? Scaffold(
                    backgroundColor: SC.bg,
                    appBar: AppBar(backgroundColor: SC.bg, foregroundColor: SC.text, elevation: 0),
                    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_t("Couldn't load your notification settings.", 'مقدرناش نحمّل إعدادات الإشعارات.'),
                          style: const TextStyle(color: SC.muted, fontSize: 14)),
                      const SizedBox(height: 12),
                      SBtn(_t('Try again', 'جرّب تاني'), onTap: _load),
                    ])))
                : _page(),
      );

  Widget _page() => SPage(
        title: _t('Notifications', 'الإشعارات'),
        subtitle: _t('Choose what BDGR tells you about.', 'اختار BDGR يبلّغك بإيه.'),
        bottomText: 'BDGR · ${_t('Notifications', 'الإشعارات')}',
        children: [
          if (_phoneAllowed != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: SCard(children: [
                SRow(
                  icon: _phoneAllowed! ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                  highlight: !_phoneAllowed!,
                  title: _phoneAllowed!
                      ? _t('Notifications are on for this phone', 'الإشعارات شغالة على الموبايل ده')
                      : _t('Notifications are off on this phone', 'الإشعارات مقفولة على الموبايل ده'),
                  desc: _phoneAllowed!
                      ? _t('Choose below what you want to hear about.', 'اختار تحت يوصلك إيه.')
                      : _t('Turn them on so you never miss a deadline.', 'شغّلها علشان ماتفوّتش أي ديدلاين.'),
                  trailing: _phoneAllowed!
                      ? SPill(_t('On', 'شغالة'), color: SC.success)
                      : SBtn(_t('Turn on', 'شغّلها'), primary: true, onTap: _turnOn),
                ),
              ]),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: SNotice(
                color: SC.warning,
                icon: Icons.notifications_active_outlined,
                title: _t('Phone notifications are coming soon', 'الإشعارات على الموبايل جاية قريب'),
                text: _t('Your choices are saved now and will apply as soon as notifications go live.',
                    'اختياراتك بتتحفظ دلوقتي، وهتتطبق أول ما الإشعارات تشتغل.'),
              ),
            ),
          if (_phoneAllowed == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: SNotice(
                plain: true,
                icon: Icons.bedtime_outlined,
                title: _t('Quiet hours', 'وقت هادي 🌙'),
                text: _t(
                    "From midnight to 9 AM (Cairo time) we hold normal notifications until the morning. Only deadline reminders and support replies can arrive at night. You can also mute a single type from your phone's notification settings.",
                    'من 12 بالليل لـ 9 الصبح (بتوقيت القاهرة) بنأجّل الإشعارات العادية للصبح. تفكير القفل وردود الدعم بس هما اللي ممكن يوصلوا بالليل. وتقدر كمان تقفل نوع واحد بس من إعدادات الإشعارات في الموبايل.'),
              ),
            ),
          SSection(
            icon: Icons.sports_soccer_rounded,
            title: _t('Fantasy', 'الفانتازي'),
            children: [SCard(children: [
              _row(Icons.timer_outlined, 'fantasy_deadline', _t('Deadline reminder', 'الديدلاين قرّب'),
                  _t('Before the round closes, so you can set your squad.', 'قبل ما الجولة تقفل، علشان تظبط تشكيلتك.')),
              _row(Icons.leaderboard_outlined, 'fantasy_results', _t('Results & points', 'النتايج والنقط'),
                  _t('When the round results and your points are out.', 'لما نتايج الجولة ونقطك تنزل.')),
              _row(Icons.emoji_events_outlined, 'badger_cup', _t('Badger Cup', 'كاس بادجر'),
                  _t('Your group, qualifying or going out.', 'مجموعتك، والتأهل أو الخروج.')),
              _row(Icons.local_fire_department_outlined, 'squad_social', _t('Reactions & comments on my squad', 'ريأكشن وكومنتات على تشكيلتي'),
                  _t('When people react or comment on your squad.', 'لما حد يعمل ريأكشن أو يكتب كومنت على تشكيلتك.')),
              _row(Icons.price_change_outlined, 'price_changes', _t('Price changes', 'تغيير الأسعار'),
                  _t('When the price of a player in your squad changes.', 'لما سعر لاعب في تشكيلتك يتغير.')),
            ])],
          ),
          SSection(
            icon: Icons.groups_outlined,
            title: _t('Leagues', 'الدوريات'),
            children: [SCard(children: [
              _row(Icons.mail_outline_rounded, 'league_invites', _t('League invites', 'دعوات الدوريات'),
                  _t('When someone invites you to their league.', 'لما حد يدعيك لدوريته.')),
              _row(Icons.how_to_reg_outlined, 'league_requests', _t('Join requests', 'طلبات الانضمام'),
                  _t('When someone asks to join your league.', 'لما حد يطلب يدخل دوريتك.')),
            ])],
          ),
          SSection(
            icon: Icons.people_outline_rounded,
            title: _t('People', 'الناس'),
            children: [SCard(children: [
              _row(Icons.person_add_alt_1_outlined, 'new_followers', _t('New followers', 'متابع جديد'),
                  _t('When someone follows you.', 'لما حد يتابعك.')),
              _row(Icons.favorite_border_rounded, 'moment_likes', _t('Likes', 'اللايكات'),
                  _t('When someone likes your moment.', 'لما حد يعمل لايك على المومنت بتاعك.')),
              _row(Icons.chat_bubble_outline_rounded, 'moment_comments', _t('Comments', 'الكومنتات'),
                  _t('When someone comments on your moment.', 'لما حد يكتب كومنت على المومنت بتاعك.')),
            ])],
          ),
          SSection(
            icon: Icons.emoji_events_outlined,
            title: _t('Competitions', 'المسابقات'),
            children: [SCard(children: [
              _row(Icons.campaign_outlined, 'competitions', _t('Competition news', 'أخبار المسابقات'),
                  _t('News about the sports you registered for.', 'أخبار الرياضات اللي سجلت فيها.')),
            ])],
          ),
          SSection(
            icon: Icons.local_offer_outlined,
            title: _t('From BDGR', 'من BDGR'),
            children: [SCard(children: [
              _row(Icons.local_offer_outlined, 'marketing', _t('Offers & news', 'العروض والأخبار'),
                  _t('Offers, prizes and news. Same choice as in Privacy.', 'عروض وجوايز وأخبار. نفس الاختيار اللي في الخصوصية.')),
            ])],
          ),
          SNotice(
            plain: true,
            text: _t('These always reach you: account messages (like your login code), BDGR replies to your support messages, and important announcements about the app.',
                'دول بيوصلوك دايمًا: رسايل الحساب (زي كود الدخول)، ورد BDGR على رسايلك للدعم، والإعلانات المهمة عن التطبيق.'),
          ),
        ],
      );
}
