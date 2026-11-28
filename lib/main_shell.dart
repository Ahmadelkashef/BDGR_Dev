import 'competitions/teams/team_pages.dart' show TeamJoinPage, teamPageRoute;
import 'package:flutter/material.dart';
import 'diag.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ads/ads.dart';
import 'app_config.dart';
import 'app_usage.dart';
import 'app_lang.dart';
import 'brand.dart';
import 'competitions/competition_sports.dart' show competitionPreselect;
import 'competitions/competitions_page.dart';
import 'deep_links.dart';
import 'feed/feed_page.dart';
import 'fantasy.dart' show FantasyShell, fantasyLeaguePage, badgerLeaguePage;
import 'home/home_page.dart' show HomePage, HomeActions;
import 'fantasy_motion.dart' show FantasyMotion;
import 'profile/profile_page.dart';
import 'settings/help_support_page.dart' show supportThreadRoute;
import 'settings/terms_privacy_page.dart';
import 'widgets/bottom_nav.dart';
import 'push/push_banner.dart';
import 'push/push_service.dart';
import 'local_store.dart';
import 'profile/profile_ambient.dart';
import 'web/web_layout.dart';
import 'web/web_side_rail.dart';

// ── أيقونات التابات ──────────────────────────────────────────────────────────
const _navItems = [
  NavItem(
    label: 'Home',
    svgInner: '<path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>'
        '<polyline points="9 22 9 12 15 12 15 22"/>',
  ),
  NavItem(
    label: 'Fantasy',
    svgInner: '<circle cx="12" cy="12" r="10"/>'
        '<path d="M12 7l4.5 3.3-1.7 5.2H9.2L7.5 10.3z"/>'
        '<path d="M12 7V2M16.5 10.3l4.8-1.6M14.8 15.5l3 4M9.2 15.5l-3 4M7.5 10.3L2.7 8.7"/>',
  ),
  NavItem(
    label: 'Feed',
    svgInner: '<path d="M4 11a9 9 0 0 1 9 9"/>'
        '<path d="M4 4a16 16 0 0 1 16 16"/>'
        '<circle cx="5" cy="19" r="1"/>',
  ),
  NavItem(
    label: 'Competitions',
    svgInner: '<path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"/>'
        '<path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"/>'
        '<path d="M4 22h16"/>'
        '<path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22"/>'
        '<path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22"/>'
        '<path d="M18 2H6v7a6 6 0 0 0 12 0V2Z"/>',
  ),
  NavItem(
    label: 'Profile',
    svgInner: '<circle cx="12" cy="8" r="3.5"/>'
        '<path d="M5 20c.7-3.5 3.1-5.5 7-5.5s6.3 2 7 5.5"/>',
  ),
];

// ── MainShell ────────────────────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  // الفيد بيشغّل الفيديوهات بس وهو التاب المفتوح
  static const int _feedTab = 2;
  final ValueNotifier<bool> _feedActive = ValueNotifier<bool>(false);

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _feedActive.value = _index == _feedTab;
    HomeActions.active.value = _index == 0;
    FantasyMotion.tabActive.value = _index == 1;   // launch: the fantasy intro plays the first time
    ShellTab.current.value = _index;                // profile background moves only in the visible tab
  }

  // كل تاب ليه Navigator: أي صفحة بتتفتح جوه التاب والشريط اللي تحت يفضل ظاهر
  final _navKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());
  // Hero جوه كل تاب (الإعلان الكبير وهو بينزل مكان البانر في الهوم)
  final _heroCtrls = List.generate(5, (_) => HeroController());

  void _onTab(int i) {
    if (i == _index) {
      _navKeys[i].currentState?.popUntil((r) => r.isFirst);   // دوسة على نفس التاب = يرجع لأوله
    } else {
      setState(() => _index = i);
    }
  }

  void _onBack() {
    final nav = _navKeys[_index].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
    } else if (_index != 0) {
      setState(() => _index = 0);
    } else {
      SystemNavigator.pop();
    }
  }

  late final List<Widget> _pages = [
    HomePage(
      onOpenProfile: () => setState(() => _index = 4),
      onOpenFantasy: () => setState(() => _index = 1),
      onOpenCompetitions: () => setState(() => _index = 3),
    ),
    // الفانتازي: ليها شريطها الخاص، و 🏠 جواها بيرجّع للهوم
    FantasyShell(onExitFantasy: () => setState(() => _index = 0)),
    ValueListenableBuilder<bool>(
      valueListenable: _feedActive,
      builder: (_, active, __) => FeedPage(isActive: active),
    ),
    const CompetitionsPage(),
    ProfilePage(
      onBuildTeam: () => setState(() => _index = 1),
    ),
  ];

  // ── لينكات المشاركة: افتح المومنت جوه التطبيق ───────────────────────────
  bool _openingShared = false;

  @override
  void initState() {
    super.initState();
    // الويب: القايمة الجانبية بتاخد زرار الترس من الهوم بعد أول فريم
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() {}); });
    Diag.sendPending();
    AppUsage.trackOpen(); // user_apps: اليوزر فتح التطبيق ده
    HomeActions.showFantasyTab = () { if (mounted && _index != 1) setState(() => _index = 1); };
    HomeActions.showProfileTab = () { if (mounted && _index != 4) setState(() => _index = 4); };
    DeepLinks.pendingMomentId.addListener(_openPendingMoment);
    DeepLinks.pendingLeagueCode.addListener(_joinPendingLeague);
    DeepLinks.pendingTeamCode.addListener(_openPendingTeam);
    DeepLinks.pendingBLeagueCode.addListener(_openPendingBLeague);
    DeepLinks.pendingPostId.addListener(_goToPendingPost);
    DeepLinks.pendingUgcId.addListener(_goToPendingPost);
    // لو اللينك جه قبل اللوجن أو قبل ما الشاشة دي تتبني
    PushService.foreground.addListener(_showForegroundPush);
    PushService.opened.addListener(_onPushOpened);
    Ads.deepLink.addListener(_openAdLink);   // إعلان لينكه جوه التطبيق
    Ads.ensure();
    WidgetsBinding.instance.addPostFrameCallback((_) { _openPendingMoment(); _joinPendingLeague(); _openPendingTeam(); _openPendingBLeague(); _goToPendingPost(); _showPriceAlerts(); _cancelPendingDeletion(); _checkLegalUpdate().then((_) => _pushOnOpen()); });
  }

  // الشروط اتحدّثت بعد ما اليوزر وافق: نطلب موافقته على النسخة الجديدة (مرة واحدة)
  bool _legalShown = false;
  Future<void> _checkLegalUpdate() async {
    if (_legalShown) return;
    try {
      final st = await Supabase.instance.client.rpc('legal_my_status');
      if (st is! Map || st['needs_accept'] != true || !mounted) return;
      _legalShown = true;
      final ver = (st['current_terms'] ?? '').toString();
      await showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: const Color(0xFF16171C),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => _LegalUpdateSheet(version: ver),
      );
    } catch (e) {
      debugPrint('legal_my_status error: $e');
    }
  }

  // الإشعارات: نسجّل الموبايل لو مسموح، ولو لسه ما اتسألش نشرح الأول (مرة واحدة)
  Future<void> _pushOnOpen() async {
    if (!PushService.supported) return;
    await PushService.checkInitialMessage();
    await PushService.sync();
    if (!mounted || _legalShown) return;
    if (await LocalStore.getFlag('push_prompt_shown') || !await PushService.notAskedYet()) return;
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    await LocalStore.setFlag('push_prompt_shown');
    final yes = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF16171C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Directionality(
        textDirection: AppLang.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.notifications_active_outlined, color: Colors.white70, size: 32),
            const SizedBox(height: 12),
            Text(AppLang.t("Don't miss the deadline", 'ماتفوّتش الديدلاين'), textAlign: TextAlign.center,
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
  }

  // اليوزر طلب مسح حسابه وبعدين دخل تاني: الطلب بيتلغي
  Future<void> _cancelPendingDeletion() async {
    try {
      final cancelled = await Supabase.instance.client.rpc('account_cancel_deletion');
      if (cancelled == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLang.t('Welcome back! Your account deletion request was cancelled.',
              'أهلاً بيك تاني! طلب مسح حسابك اتلغى.')),
          duration: const Duration(seconds: 5),
        ));
      }
    } catch (e) {
      debugPrint('account_cancel_deletion error: $e');
    }
  }

  // دوسة على إشعار: نروح للصفحة المناسبة حسب نوعه
  void _onPushOpened() {
    final d = PushService.opened.value;
    if (d == null || !mounted) return;
    PushService.opened.value = null;
    _openPushTarget(d);
  }

  static const _pushTabs = {'home': 0, 'fantasy': 1, 'feed': 2, 'competitions': 3, 'profile': 4};

  bool _hasPushTarget(Map<String, dynamic> d) =>
      const {'fantasy_deadline', 'fantasy_results', 'support_reply'}.contains(d['kind']) ||
      _pushTabs.containsKey(d['open']);

  void _openPushTarget(Map<String, dynamic> d) {
    final kind = d['kind']?.toString();
    int? tab;
    Route<void>? page;
    if (kind == 'fantasy_deadline' || kind == 'fantasy_results') {
      tab = 1;
      if (kind == 'fantasy_results') FantasyMotion.pendingRecapEvent = d['event_id']?.toString();
    } else if (kind == 'support_reply') {
      final id = int.tryParse(d['ticket_id']?.toString() ?? '');
      if (id != null) { tab = 0; page = supportThreadRoute(id); }
    } else if ((kind == 'team_request' || kind == 'team_accepted') && (d['team_id']?.toString() ?? '').isNotEmpty) {
      tab = 3; page = teamPageRoute(d['team_id'].toString());
    } else if (_pushTabs.containsKey(d['open'])) {
      tab = _pushTabs[d['open']];
    }
    if (tab == null) return;
    final t = tab;
    setState(() => _index = t);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = _navKeys[t].currentState;
      nav?.popUntil((r) => r.isFirst);
      if (page != null) nav?.push(page);
    });
  }

  // إعلان لينكه "deeplink": fantasy / feed / competitions[:sport] / profile / home
  void _openAdLink() {
    final link = Ads.deepLink.value;
    if (link == null || !mounted) return;
    final parts = link.split(':');
    final tab = _pushTabs[parts.first];
    if (tab == null) return;
    if (parts.first == 'competitions' && parts.length > 1 && parts[1].isNotEmpty) {
      competitionPreselect.value = parts[1];
    }
    setState(() => _index = tab);
    WidgetsBinding.instance.addPostFrameCallback((_) => _navKeys[tab].currentState?.popUntil((r) => r.isFirst));
  }

  // إشعار وصل والتطبيق مفتوح: كارت شيك بينزل من فوق (push_banner.dart)
  void _showForegroundPush() {
    final m = PushService.foreground.value;
    if (m == null || !mounted) return;
    final data = Map<String, dynamic>.from(m.data);
    final title = m.notification?.title ?? data['title']?.toString() ?? '';
    final body = m.notification?.body ?? data['body']?.toString() ?? '';
    if (title.isEmpty && body.isEmpty) return;
    PushBanner.show(context, title: title, body: body,
        onOpen: _hasPushTarget(data) ? () => _openPushTarget(data) : null);
  }

  @override
  void dispose() {
    PushService.foreground.removeListener(_showForegroundPush);
    PushService.opened.removeListener(_onPushOpened);
    Ads.deepLink.removeListener(_openAdLink);
    DeepLinks.pendingMomentId.removeListener(_openPendingMoment);
    DeepLinks.pendingLeagueCode.removeListener(_joinPendingLeague);
    DeepLinks.pendingTeamCode.removeListener(_openPendingTeam);
    DeepLinks.pendingBLeagueCode.removeListener(_openPendingBLeague);
    DeepLinks.pendingPostId.removeListener(_goToPendingPost);
    DeepLinks.pendingUgcId.removeListener(_goToPendingPost);
    _feedActive.dispose();
    super.dispose();
  }

  // لينك بوست فيد: نروح لتاب الفيد، والفيد نفسه بيفتح البوست
  void _goToPendingPost() {
    if ((DeepLinks.pendingPostId.value == null && DeepLinks.pendingUgcId.value == null) || !mounted) return;
    if (supa.auth.currentSession == null) return;   // بعد اللوجن
    setState(() => _index = _feedTab);
    WidgetsBinding.instance.addPostFrameCallback((_) => _navKeys[_feedTab].currentState?.popUntil((r) => r.isFirst));
  }

  // ── دعوة فريق دوري بادجر (الفانتازي): نروح للفانتازي ونفتح الدوري بالكود ──
  void _openPendingBLeague() {
    final code = DeepLinks.pendingBLeagueCode.value;
    if (code == null || !mounted) return;
    if (supa.auth.currentSession == null) return;   // بعد اللوجن
    DeepLinks.consumeBLeague();
    const tab = 1;
    setState(() => _index = tab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = _navKeys[tab].currentState;
      nav?.popUntil((r) => r.isFirst);
      nav?.push(MaterialPageRoute<void>(builder: (_) => badgerLeaguePage(joinCode: code)));
    });
  }

  // ── دعوة فريق (مسابقات): نروح للمسابقات ونفتح صفحة الانضمام بالكود ──
  void _openPendingTeam() {
    final code = DeepLinks.pendingTeamCode.value;
    if (code == null || !mounted) return;
    if (supa.auth.currentSession == null) return;   // بعد اللوجن
    DeepLinks.consumeTeam();
    const tab = 3;
    setState(() => _index = tab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = _navKeys[tab].currentState;
      nav?.popUntil((r) => r.isFirst);
      nav?.push(MaterialPageRoute<void>(builder: (_) => TeamJoinPage(code: code)));
    });
  }

  // ── دعوة ليج: يأكد وبعدين يدخل الليج ويروح للفانتازي ─────────────────────
  bool _joiningLeague = false;
  Future<void> _joinPendingLeague() async {
    final code = DeepLinks.pendingLeagueCode.value;
    if (code == null || _joiningLeague || !mounted) return;
    if (supa.auth.currentSession == null) return;   // بعد اللوجن
    _joiningLeague = true;
    DeepLinks.consumeLeague();
    try {
      final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppLang.t('Join league?', 'تدخل الليج؟'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(AppLang.t('You were invited to a BDGR Fantasy league with code $code.',
            'اتعزمت على ليج في BDGR فانتازي بالكود $code.'), style: const TextStyle(color: Colors.white70, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLang.t('Not now', 'مش دلوقتي'), style: const TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLang.t('Join', 'ادخل'), style: const TextStyle(color: Color(0xFF00FF87), fontWeight: FontWeight.w900))),
        ],
      ));
      if (ok != true || !mounted) return;
      final r = Map<String, dynamic>.from(await supa.rpc('join_fantasy_league', params: {'p_code': code}) as Map);
      final st = r['status']?.toString();
      final msg = switch (st) {
        'joined' => AppLang.t('You joined the league! 🎉', 'دخلت الليج! 🎉'),
        'already_member' => AppLang.t("You're already in this league.", 'إنت في الليج دي بالفعل.'),
        'requested' => AppLang.t('A request was sent to the league owner.', 'اتبعت طلب لصاحب الليج.'),
        'pending' => AppLang.t('Your request is still waiting for the owner.', 'طلبك لسه مستني رد صاحب الليج.'),
        'blocked' => AppLang.t("You can't join this league.", 'مش هتقدر تدخل الليج دي.'),
        'league_full' => AppLang.t('This league is full.', 'الليج دي مليانة.'),
        _ => AppLang.t('This invite link is not valid anymore.', 'لينك الدعوة ده مبقاش شغال.'),
      };
      if (!mounted) return;
      setState(() => _index = 1);   // الفانتازي
      // دخل (أو كان فيها): نفتحله صفحة الليج على طول، والرجوع بيوديه للوبي الفانتازي
      final leagueId = r['league_id']?.toString();
      if (leagueId != null && (st == 'joined' || st == 'already_member')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navKeys[1].currentState?.popUntil((r) => r.isFirst);
          _navKeys[1].currentState?.push(MaterialPageRoute<void>(builder: (_) => fantasyLeaguePage(leagueId)));
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      debugPrint('join league from link error: $e');
    } finally {
      _joiningLeague = false;
    }
  }

  // ── تنبيه: أسعار لاعيبة اتغيّرت في جولة مفتوحة عندك فيها فريق (بيظهر أول ما الهوم يفتح) ──
  bool _priceAlertShown = false;
  Future<void> _showPriceAlerts() async {
    if (_priceAlertShown || supa.auth.currentSession == null) return;
    _priceAlertShown = true;
    try {
      final r = await supa.rpc('fantasy_my_price_alerts');
      if (r == null || !mounted) return;
      final data = Map<String, dynamic>.from(r as Map);
      final changes = ((data['changes'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (changes.isEmpty) return;
      final ar = AppLang.isArabic;
      String t(String en, String a) => ar ? a : en;
      String fmt(num? v) => v == null ? '—' : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());
      String hm(String? iso) {
        final d = DateTime.tryParse(iso ?? '')?.toLocal();
        if (d == null) return '';
        final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
        return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? t('AM', 'ص') : t('PM', 'م')}';
      }
      final openSquad = data['has_open_squad'] == true;
      String day(String? iso) {
        final d = DateTime.tryParse(iso ?? '')?.toLocal();
        if (d == null) return '';
        const ma = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
        const me = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        return ar ? '${d.day} ${ma[d.month - 1]}' : '${me[d.month - 1]} ${d.day}';
      }
      final when = '${day(data['from'] as String?)} ${hm(data['from'] as String?)}'
          '${data['from'] != data['to'] ? ' – ${hm(data['to'] as String?)}' : ''}';
      // ميتقفلش غير بـ "تمام" — علشان نتأكد إنه شافه
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(canPop: false, child: Dialog(
          backgroundColor: const Color(0xFF151518),
          insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 12), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(openSquad ? '⚠️' : '📢', style: const TextStyle(fontSize: 22)), const SizedBox(width: 10),
              Expanded(child: Text(openSquad ? t('Heads up: player prices changed', 'خلي بالك: أسعار لاعيبة اتغيّرت')
                                             : t('Player prices updated', 'تحديث أسعار اللاعيبة'),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 6),
            Text(openSquad
                ? t('Players already in your team keep the price you paid. New picks use the new price.',
                    'اللاعيبة اللي في فريقك بتفضل بالسعر اللي اشتريتهم بيه. أي لاعب جديد هتاخده بالسعر الجديد.')
                : t('The new prices apply from the next round.', 'الأسعار الجديدة هتتطبق من الجولة الجاية.'),
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45)),
            const SizedBox(height: 4),
            Text('${t('Updated', 'اتعدّلت')} $when', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 12),
            ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.45), child: SingleChildScrollView(child: Column(children: [
              for (final c in changes) Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: c['in_squad'] == true ? const Color(0x1400FF87) : Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c['in_squad'] == true ? const Color(0x5500FF87) : Colors.white12)),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${(ar ? c['name_ar'] : c['name_en']) ?? c['name_en'] ?? ''}',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                    if (c['in_squad'] == true) Padding(padding: const EdgeInsets.only(top: 2), child: Text(
                      t('In your team · you keep it at ${fmt(c['paid'] as num?)}', 'في فريقك · بيفضل بالسعر اللي اشتريته بيه ${fmt(c['paid'] as num?)}'),
                      style: const TextStyle(color: Color(0xFF00FF87), fontSize: 11.5, fontWeight: FontWeight.w700)))
                    else if (c['in_last'] == true) Padding(padding: const EdgeInsets.only(top: 2), child: Text(
                      t('Was in your last team', 'كان في فريقك آخر جولة'),
                      style: const TextStyle(color: Colors.white54, fontSize: 11.5, fontWeight: FontWeight.w700))),
                  ])),
                  Text('${fmt(c['old'] as num?)} → ', style: const TextStyle(color: Colors.white54, fontSize: 13.5)),
                  Text(fmt(c['new'] as num?), style: TextStyle(
                    color: ((c['new'] as num?) ?? 0) > ((c['old'] as num?) ?? 0) ? const Color(0xFFFF6B6B) : const Color(0xFF4CD964),
                    fontSize: 16, fontWeight: FontWeight.w900)),
                  Text(((c['new'] as num?) ?? 0) > ((c['old'] as num?) ?? 0) ? ' ⬆️' : ' ⬇️', style: const TextStyle(fontSize: 13)),
                ])),
            ]))),
            const SizedBox(height: 6),
            SizedBox(width: double.infinity, height: 46, child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF1A1A), foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(t('Got it', 'تمام'), style: const TextStyle(fontWeight: FontWeight.w900)))),
          ])),
        )),
      );
      await supa.rpc('fantasy_price_alerts_ack', params: {'p_last_id': data['max_id']});
    } catch (e) {
      debugPrint('price alerts error: $e');
    }
  }

  Future<void> _openPendingMoment() async {
    final id = DeepLinks.pendingMomentId.value;
    if (id == null || _openingShared || !mounted) return;
    if (supa.auth.currentSession == null) return;   // هيتفتح بعد اللوجن
    _openingShared = true;
    DeepLinks.consume();
    try {
      final res = await supa.rpc('get_moment_owner', params: {'p_moment_id': id});
      final rows = res is List ? res : const [];
      if (!mounted) return;
      if (rows.isEmpty || rows.first is! Map) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLang.t('This moment is no longer available',
                'المومنت ده مبقاش موجود'))));
        return;
      }
      final row = rows.first as Map;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ProfilePage(
          visitTarget: ProfileVisitTarget(
            userId:      '${row['user_id']}',
            username:    '${row['username'] ?? ''}',
            displayName: '${row['display_name'] ?? ''}',
            avatarUrl:   row['avatar_url']?.toString(),
          ),
          openMomentId: id,
        ),
      ));
    } catch (e) {
      debugPrint('open shared moment error: $e');
    } finally {
      _openingShared = false;
    }
  }

  // ── الويب على شاشة كبيرة ────────────────────────────────────────────────
  static const _labelsAr = ['الرئيسية', 'الفانتازي', 'الفيد', 'المسابقات', 'البروفايل'];
  /// أقصى عرض لكل تاب على الكمبيوتر (null = الصفحة نفسها بتتصرف في العرض)
  static const List<double?> _webMaxWidth = [null, 860, 640, 1080, 980];

  Widget _tabNavigator(int i) => ShellTabScope(
        index: i,
        child: Navigator(
          key: _navKeys[i],
          observers: [_heroCtrls[i], AdsRouteGuard()],
          onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => _pages[i]),
        ),
      );

  Widget _webColumn(int i) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border.symmetric(vertical: BorderSide(color: Colors.white.withOpacity(0.06))),
          boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 40)],
        ),
        child: ClipRect(child: _tabNavigator(i)),
      );

  Widget _webTab(int i) {
    final maxW = _webMaxWidth[i]!;
    if (i != _feedTab) return WebPageFrame(maxWidth: maxW, child: _webColumn(i));
    // الفيد: العمود في النص + عمود جانبي (فانتازي / مسابقات / لينكات) لو الشاشة واسعة
    return LayoutBuilder(builder: (context, c) {
      const gap = 28.0;
      final showRail = c.maxWidth >= maxW + gap + WebSideRail.width + 40;
      if (!showRail) return WebPageFrame(maxWidth: maxW, child: _webColumn(i));
      return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(width: maxW, child: WebPageFrame(maxWidth: maxW, child: _webColumn(i))),
        const SizedBox(width: gap),
        WebSideRail(
          onOpenFantasy: () => setState(() => _index = 1),
          onOpenCompetitions: () => setState(() => _index = 3),
        ),
      ]);
    });
  }

  Widget _buildDesktop(BuildContext context) {
    HomeActions.showHomeTab = () { if (_index != 0) setState(() => _index = 0); };
    final w = MediaQuery.sizeOf(context).width;
    final compact = w < WebLayout.fullSidebarMin;
    return Directionality(
      textDirection: AppLang.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Brand.background,
        body: Row(children: [
          WebSidebar(
            items: _navItems,
            labelsAr: _labelsAr,
            selectedIndex: _index,
            onTap: _onTab,
            compact: compact,
            onSearch: () => HomeActions.search?.call(),
            onToggleLang: () { HomeActions.toggleLang?.call(); setState(() {}); },
            settingsButton: HomeActions.menu,
          ),
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              const WebBackdrop(),
              IndexedStack(
                index: _index,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    _webMaxWidth[i] == null ? _tabNavigator(i) : _webTab(i),
                ],
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (WebLayout.isDesktop(context)) return _buildDesktop(context);
    // الشريط الرئيسي ظاهر في كل حتة، حتى في الصفحات اللي بتتفتح جوه التاب
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _onBack(); },
      // the strip above the bottom bar takes the profile's colour while the profile is on screen (`profile_nav_fill`)
      child: ValueListenableBuilder<Color?>(valueListenable: ShellTab.navFill, builder: (_, fill, __) => Scaffold(
        backgroundColor: fill ?? Brand.background,
        extendBody: false,   // الصفحات اللي بتتفتح جوه التاب ما تستخباش ورا الشريط
        body: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < _pages.length; i++) _tabNavigator(i),
          ],
        ),
        bottomNavigationBar: BottomNav(
          items:         _navItems,
          selectedIndex: _index,
          onTap:         _onTab,
        ),
      )),
    );
  }
}


/// "حدّثنا الشروط": مش بيتقفل غير بالموافقة. "اقرا" بيفتح الصفحة.
class _LegalUpdateSheet extends StatefulWidget {
  const _LegalUpdateSheet({required this.version});
  final String version;

  @override
  State<_LegalUpdateSheet> createState() => _LegalUpdateSheetState();
}

class _LegalUpdateSheetState extends State<_LegalUpdateSheet> {
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc('legal_accept');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('legal_accept error: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLang.t('Something went wrong. Try again.', 'حصلت مشكلة. جرّب تاني.'))));
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: AppLang.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: PopScope(
          canPop: false,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Icon(Icons.description_outlined, color: Colors.white70, size: 30),
                const SizedBox(height: 12),
                Text(AppLang.t('We updated our Terms & Privacy Policy', 'حدّثنا الشروط وسياسة الخصوصية'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(AppLang.t(
                    'They now explain clearly what we collect, who sees what, how prizes work, and how to delete your account. Please read and agree to keep using BDGR.',
                    'بقت بتشرح بوضوح بنجمع إيه، ومين بيشوف إيه، والجوايز بتمشي إزاي، وإزاي تمسح حسابك. اقراها ووافق علشان تكمّل على BDGR.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFA6AAB5), fontSize: 13, height: 1.7)),
                const SizedBox(height: 18),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const TermsPrivacyPage())),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF2A2C33)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(AppLang.t('Read them', 'اقراها')),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _busy ? null : _accept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF1A1A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(AppLang.t('I agree (version ${widget.version})', 'موافق (النسخة ${widget.version})'),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ]),
            ),
          ),
        ),
      );
}
