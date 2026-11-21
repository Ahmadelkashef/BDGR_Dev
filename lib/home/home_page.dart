import 'dart:async';
import '../media_cache.dart';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import '../ads/ad_takeover.dart';
import '../ads/ad_widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';

import '../app_config.dart';
import '../auth/landing_screen.dart';
import '../app_lang.dart';
import '../brand.dart';
import '../competitions/competition_sports.dart';
import '../local_store.dart';
import '../web/web_layout.dart';
import '../settings/settings_pages.dart';
import 'home_user_search_page.dart';
import '../push/push_service.dart';

// ---------------------------------------------------------------------------
// HOME: نفس صفحة home.html (واجهة فقط، بدون باك اند)
// ---------------------------------------------------------------------------

/// نص الهوم بالعربي أو الإنجليزي (AppLang)
String _tr(String en, String ar) => AppLang.t(en, ar);

const Color _kDark = Color(0xFF0B0B0F);   // أسود بادجر (كان بنفسجي iPLAY)
const Color _kGreen = Color(0xFF00FF87);
const Color _kCard = Color(0xFF1A1A1A);   // نفس كروت الفانتازي

const String _kMedia =
    'https://huggingface.co/datasets/Meekkii/IPLAY/resolve/main';

// ---- أيقونات SVG (نفس الأيقونات الموجودة في home.html) ----
const String _icBell =
    '<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9"/>'
    '<path d="M10 21h4"/>';
const String _icProfile =
    '<circle cx="12" cy="8" r="3.5"/>'
    '<path d="M5 20c.7-3.5 3.1-5.5 7-5.5s6.3 2 7 5.5"/>';
const String _icSettings =
    '<circle cx="12" cy="12" r="3"/>'
    '<path d="m19.4 15 .1.1 1.4 1.1-1.4 2.4-1.7-.7a8 8 0 0 1-1.6.9l-.3 1.8h-2.8l-.3-1.8a8 8 0 0 1-1.6-.9l-1.7.7-1.4-2.4 1.4-1.1a7 7 0 0 1 0-1.9l-1.4-1.1 1.4-2.4 1.7.7a8 8 0 0 1 1.6-.9l.3-1.8h2.8l.3 1.8a8 8 0 0 1 1.6.9l1.7-.7 1.4 2.4-1.4 1.1a7 7 0 0 1 0 1.8Z" transform="translate(-1 -1) scale(1.05)"/>';
const String _icLock =
    '<rect x="4" y="10" width="16" height="11" rx="2"/>'
    '<path d="M8 10V7a4 4 0 0 1 8 0v3"/>'
    '<path d="M12 14v3"/>';
const String _icShield =
    '<path d="M12 22s8-4 8-11V5l-8-3-8 3v6c0 7 8 11 8 11Z"/>'
    '<path d="m9 12 2 2 4-4"/>';
const String _icGlobe =
    '<circle cx="12" cy="12" r="9"/>'
    '<path d="M3 12h18"/>'
    '<path d="M12 3a15 15 0 0 1 0 18"/>'
    '<path d="M12 3a15 15 0 0 0 0 18"/>';
const String _icHelp =
    '<circle cx="12" cy="12" r="10"/>'
    '<path d="M9.1 9a3 3 0 0 1 5.8 1c0 2-3 3-3 3"/>'
    '<path d="M12 17h.01"/>';
const String _icTerms =
    '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z"/>'
    '<path d="M14 2v6h6"/>'
    '<path d="M8 13h8M8 17h8"/>';
const String _icLogout =
    '<path d="M9 4H5a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h4"/>'
    '<path d="M16 17l5-5-5-5"/>'
    '<path d="M21 12H9"/>';
const String _icChevron = '<path d="m9 18 6-6-6-6"/>';
const String _icArrow = '<path d="M5 12h13"/><path d="m13 6 6 6-6 6"/>';

Widget _svgIcon(
  String inner, {
  String hex = '#FFFFFF',
  double size = 19,
  double strokeWidth = 1.8,
  double opacity = 1,
  bool round = false,
}) {
  final caps = round ? ' stroke-linecap="round" stroke-linejoin="round"' : '';
  return SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
    'fill="none" stroke="$hex" stroke-opacity="$opacity" '
    'stroke-width="$strokeWidth"$caps>$inner</svg>',
    width: size,
    height: size,
  );
}

// أسماء صفحات قائمة الحساب (لحد ما نحدد وجهة كل صفحة)
const Map<String, String> _menuLabels = {
  'account-settings': 'Account Settings',
  'login-security': 'Login & Security',
  'privacy-settings': 'Privacy & Permissions',
  'notification-settings': 'Notifications',
  'app-preferences': 'App Preferences',
  'help-support': 'Help & Support',
  'terms-privacy': 'Terms & Privacy Policy',
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// ضغطة بتصغّر العنصر شوية زي :active في CSS
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.onTap,
    required this.child,
    this.pressedScale = 0.94,
  });

  final VoidCallback onTap;
  final Widget child;
  final double pressedScale;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

/// المربع الصغير بتاع الأيقونات (.icon-btn)
class _IconBox extends StatelessWidget {
  const _IconBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: child,
    );
  }
}

/// فيديو بيشتغل لوب بدون صوت (للهيرو وكروت More coming)
class _LoopVideo extends StatefulWidget {
  const _LoopVideo({required this.url, this.dim = false});

  final String url;
  final bool dim; // brightness(.78) زي الكروت

  @override
  State<_LoopVideo> createState() => _LoopVideoState();
}

class _LoopVideoState extends State<_LoopVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = await MediaCache.video(widget.url,
        options: VideoPlayerOptions(mixWithOthers: true));
    if (!mounted) { controller.dispose(); return; }
    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted) {
        return;
      }
      await controller.setVolume(0);
      await controller.setLooping(true);
      await controller.play();
      if (mounted) {
        setState(() => _ready = true);
      }
    } catch (_) {
      // لو الفيديو ما اتحملش نسيب الخلفية الغامقة
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (!_ready || controller == null) {
      return const SizedBox.expand();
    }

    Widget video = SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );

    if (widget.dim) {
      video = ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Color(0xFFC7C7C7),
          BlendMode.modulate,
        ),
        child: video,
      );
    }

    return video;
  }
}

/// مودال بخلفية مغبشة (زي backdrop-filter: blur في CSS)
Future<T?> _showBlurDialog<T>(
  BuildContext context, {
  required double barrierOpacity,
  required bool dismissible,
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'dialog',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, animation, secondary) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);

      return Stack(
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: curved,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: dismissible ? () => Navigator.of(ctx).pop() : null,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: ColoredBox(
                    color: Colors.black.withOpacity(barrierOpacity),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: builder(ctx),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

// ---------------------------------------------------------------------------
// HOME PAGE
// ---------------------------------------------------------------------------

/// الويب (شاشة كبيرة): القايمة الجانبية بتنادي نفس أزرار الهوم (بحث / لغة / الترس).
class HomeActions {
  HomeActions._();
  static VoidCallback? search;
  static VoidCallback? toggleLang;
  static Widget Function(Widget child)? menu;
  /// قبل ما صفحة تتفتح من القايمة الجانبية: الموقع بيروح لتاب الهوم (الصفحة بتتفتح جواه)
  static VoidCallback? showHomeTab;
  /// الهوم هو التاب الظاهر دلوقتي (صف الرياضات بيتحرك لوحده بس وهو ظاهر)
  static final ValueNotifier<bool> active = ValueNotifier<bool>(true);
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onOpenProfile,
    required this.onOpenFantasy,
    this.onOpenCompetitions,
  });

  /// بيفتح تاب المسابقات (كروت الرياضات تحت)
  final VoidCallback? onOpenCompetitions;

  final VoidCallback onOpenProfile;

  /// بيفتح تاب Fantasy في الشريط اللي تحت (نفس الدوس على التاب)
  final VoidCallback onOpenFantasy;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  // الأونبوردنج: لليوزر الجديد بس (حسابه أقل من 24 ساعة)، ومرة واحدة على الجهاز
  static bool _welcomeChecked = false;
  static const String _kWelcomeFlag = 'home_welcome_seen';

  // عدد اللي لعبوا فانتازي ولو مرة (distinct users في fantasy_user_squads)
  // بيتحمل من home_fantasy_players_count، ولحد ما يوصل بيفضل آخر رقم اتجاب
  static int? _playersCount;

  String get _playersText {
    final n = _playersCount;
    if (n == null) return '—';
    return n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  // عداد الديدلاين + الجايزة (RPC home_fantasy_hero):
  // جولة مفتوحة → لحد الديدلاين، مفيش → لحد ما الجولة الجاية تتفتح.
  // الجايزة = المركز الأول، ولو الجولة الجاية لسه مالهاش → جايزة الجولة الشغالة.
  static Map<String, dynamic>? _hero;
  Timer? _countdownTimer;

  DateTime? get _heroAt => DateTime.tryParse('${_hero?['at'] ?? ''}')?.toLocal();

  String get _countdownLabel => _hero?['mode'] == 'deadline' ? _tr('Deadline', 'الديدلاين') : _tr('Next round', 'الجولة الجاية');

  String? get _countdownText {
    final at = _heroAt;
    if (at == null) return null;
    final left = at.difference(DateTime.now());
    if (left.isNegative) return null;
    final d = left.inDays, h = left.inHours % 24, m = left.inMinutes % 60;
    final dd = _tr('d', 'ي'), hh = _tr('h', 'س'), mm = _tr('m', 'د');
    if (d > 0) return '$d$dd $h$hh';
    if (left.inHours > 0) return '$h$hh $m$mm';
    return '${m < 1 ? 1 : m}$mm';
  }

  String? get _prizeText {
    // الهيرو كله إنجليزي، فالجايزة بالإنجليزي برضو (1750 EGP)
    final p = AppLang.isArabic ? (_hero?['prize_ar'] ?? _hero?['prize_en']) : (_hero?['prize_en'] ?? _hero?['prize_ar']);
    return (p == null || '$p'.isEmpty) ? null : '$p';
  }

  Future<void> _loadHero() async {
    try {
      final res = await supa.rpc('home_fantasy_hero');
      if (res is Map && mounted) setState(() => _hero = Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('home_fantasy_hero error: $e');
    }
  }

  Future<void> _loadPlayersCount() async {
    try {
      final res = await supa.rpc('home_fantasy_players_count');
      final n = res is num ? res.toInt() : int.tryParse('$res');
      if (n != null && mounted) setState(() => _playersCount = n);
    } catch (e) {
      debugPrint('home_fantasy_players_count error: $e');
    }
  }

  late final AnimationController _pulseController;
  late final AnimationController _playController;
  late final Animation<double> _pulse;
  late final Animation<double> _playPulse;

  bool _notifOpen = false;
  bool _showBadge = false;

  String _toastText = '';
  bool _toastVisible = false;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    HomeActions.search = _openUserSearch;
    HomeActions.toggleLang = _toggleLang;
    HomeActions.menu = (child) => _buildAccountMenu(child: child);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseController, curve: Curves.ease);

    _playController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _playPulse = CurvedAnimation(parent: _playController, curve: Curves.ease);

    _loadPlayersCount();
    _loadHero();
    // العداد بيتحدّث كل 30 ثانية، ولما يخلص بنجيب الجولة اللي بعدها
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final at = _heroAt;
      if (at != null && !at.isAfter(DateTime.now())) _loadHero();
      setState(() {});
    });

    if (!_welcomeChecked) {
      _welcomeChecked = true;
      _maybeShowWelcome();
    }
    // Home Takeover (لو فيه حملة): مرة في اليوم، مش لليوزر الجديد، وبس لو الهوم هي اللي قدام اليوزر
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      showHomeTakeover(context);
    });
  }

  Future<void> _maybeShowWelcome() async {
    final created = DateTime.tryParse(supa.auth.currentUser?.createdAt ?? '');
    if (created == null) return;
    final isNew = DateTime.now().toUtc().difference(created.toUtc()) < const Duration(hours: 24);
    if (!isNew || await LocalStore.getFlag(_kWelcomeFlag)) return;
    await LocalStore.setFlag(_kWelcomeFlag);   // مرة واحدة بس، حتى لو قفلها بأي طريقة
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final play = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => const _WelcomeSheet(),
    );
    if (play == true && mounted) widget.onOpenFantasy();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _toastTimer?.cancel();
    _pulseController.dispose();
    _playController.dispose();
    super.dispose();
  }

  // ---- Toast ----

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() {
      _toastText = message;
      _toastVisible = true;
    });
    _toastTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() => _toastVisible = false);
      }
    });
  }

  // ---- Actions ----

  void _playFantasy() {
    widget.onOpenFantasy();
  }

  void _openUserSearch() {
    HomeActions.showHomeTab?.call();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const UserSearchPage(),
      ),
    );
  }

  void _toggleLang() {
    final ar = !AppLang.isArabic;
    AppLang.set(ar ? 'ar' : 'en');
    LocalStore.setLang(ar ? 'ar' : 'en');
    setState(() {});
  }

  void _onMenuSelected(String value) {
    if (value != 'profile') HomeActions.showHomeTab?.call();
    switch (value) {
      case 'profile':
        widget.onOpenProfile();
        break;
      case 'logout':
        _confirmLogout();
        break;
      default:
        // باقي الاختيارات: صفحات lib/settings (واجهة بس)
        if (!openSettingsPage(context, value, onClosed: () { if (mounted) setState(() {}); })) {
          _showToast(
            _tr('${_menuLabels[value] ?? 'This page'} comes in the next update', 'الصفحة دي جاية في التحديث الجاي'),
          );
        }
    }
  }

  Future<void> _openNotifications({bool auto = false}) async {
    if (_notifOpen) {
      return;
    }
    _notifOpen = true;

    await _showBlurDialog<void>(
      context,
      barrierOpacity: 0.62,
      dismissible: true,
      builder: (ctx) => _NotificationsCard(autoClose: auto),
    );

    _notifOpen = false;
    if (mounted) {
      setState(() => _showBadge = true);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await _showBlurDialog<bool>(
      context,
      barrierOpacity: 0.68,
      dismissible: false,
      builder: (ctx) => const _LogoutCard(),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await PushService.unregister();
    try {
      await supa.auth.signOut();
    } catch (e) {
      debugPrint('Logout error: $e');
    }
    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const LandingScreen()),
      (route) => false,
    );
  }

  void _openComingSoon() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Coming soon',
      barrierColor: Colors.black,
      transitionDuration: Duration.zero,
      pageBuilder: (ctx, animation, secondary) => const _ComingSoonOverlay(),
    );
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: AppLang.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: _buildPage(context),
      );

  Widget _buildPage(BuildContext context) {
    final media = MediaQuery.of(context);
    final narrow = media.size.width <= 360;

    return Stack(
      fit: StackFit.expand,
      children: [
        // الخلفية: نفس بادجر صفحة اللوجن بس سودا (خطوط مايلة + توهج أبيض خفيف)
        const ColoredBox(color: Colors.black),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.15),
              radius: 0.8,
              colors: [Color(0x14FFFFFF), Color(0x00000000)],
            ),
          ),
        ),
        CustomPaint(painter: _HomeRaysPainter()),
        Center(
          child: FractionallySizedBox(
            widthFactor: 0.85,
            child: Opacity(
              opacity: 0.10,
              child: Image.asset(Brand.badger, fit: BoxFit.contain),
            ),
          ),
        ),
        if (WebLayout.isDesktop(context))
          _buildDesktopBody()
        else
        SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              narrow ? 14 : 18,
              16,
              narrow ? 14 : 18,
              120 + media.padding.bottom,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 484),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 18),
                    _buildHero(narrow),
                    // إعلان: بانر تحت الهيرو (مفيش حملة = مفيش حاجة)
                    // بعد الـ Takeover: نفس الإعلان بينزل هنا مكان البانر
                    ValueListenableBuilder<AdItem?>(
                      valueListenable: Ads.docked,
                      builder: (_, d, __) => d == null
                          ? const AdSlot('home_banner', padding: EdgeInsets.only(top: 18))
                          : Padding(padding: const EdgeInsets.only(top: 18), child: DockedTakeoverBanner(d)),
                    ),
                    const SizedBox(height: 28),
                    _buildComingSection(narrow),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 85,
          child: IgnorePointer(
            child: Center(
              child: AnimatedOpacity(
                opacity: _toastVisible ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                        ),
                      ),
                      child: Text(
                        _toastText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          decoration: TextDecoration.none,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---- الويب: شاشة كبيرة ----
  // نفس محتوى الهوم بالظبط (الهيرو + الإعلان + الرياضات) بس متوزع على عرض الشاشة.
  // البحث واللغة والترس في القايمة الجانبية.
  Widget _buildDesktopBody() {
    return LayoutBuilder(builder: (context, c) {
      final pad = c.maxWidth >= 1400 ? 48.0 : 36.0;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, 34, pad, 56),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(_tr('Home', 'الرئيسية'),
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                  const SizedBox(width: 14),
                  Text('B D G R', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.4)),
                ]),
                const SizedBox(height: 22),
                _buildHero(false, wide: true),
                ValueListenableBuilder<AdItem?>(
                  valueListenable: Ads.docked,
                  builder: (_, d, __) => d == null
                      ? const AdSlot('home_banner', padding: EdgeInsets.only(top: 22))
                      : Padding(padding: const EdgeInsets.only(top: 22), child: DockedTakeoverBanner(d)),
                ),
                const SizedBox(height: 40),
                _buildComingSection(false, wide: true),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ---- Top bar ----

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // لوجو البادجر + اسم التاب (نفس هيدر الفانتازي)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2C2C2C)),
              ),
              child: Image.asset(Brand.badger, fit: BoxFit.contain),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('HOME', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5, height: 1.1)),
                Text('B D G R', style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2)),
              ],
            ),
          ],
        ),
        Row(
          children: [
            _Pressable(
              onTap: _openUserSearch,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.055),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.10),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _svgIcon(
                      '<circle cx="11" cy="11" r="7"/>'
                      '<path d="m16 16 4 4"/>',
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _tr('Search', 'بحث'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 9),
            // زرار اللغة (مكان الجرس): بيقلب الهوم عربي/إنجليزي وبيتحفظ
            _Pressable(
              onTap: _toggleLang,
              child: _IconBox(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.language_rounded, color: Colors.white70, size: 14),
                    Text(
                      AppLang.isArabic ? 'EN' : 'ع',
                      style: const TextStyle(color: _kGreen, fontSize: 10, fontWeight: FontWeight.w900, height: 1.1),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 9),
            _buildAccountMenu(),
          ],
        ),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    String label,
    String icon, {
    bool danger = false,
  }) {
    final color = danger ? const Color(0xFFFF7777) : Colors.white;
    final hex = danger ? '#FF7777' : '#FFFFFF';

    return PopupMenuItem<String>(
      value: value,
      height: 43,
      padding: const EdgeInsets.symmetric(horizontal: 19),
      child: Row(
        children: [
          _svgIcon(icon, hex: hex, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (!danger)
            _svgIcon(_icChevron, size: 14, opacity: 0.35),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuDivider() {
    return PopupMenuItem<String>(
      enabled: false,
      height: 15,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(height: 1, color: Colors.white.withOpacity(0.10)),
    );
  }

  PopupMenuItem<String> _menuLabel(String text) {
    return PopupMenuItem<String>(
      enabled: false,
      height: 28,
      padding: const EdgeInsets.fromLTRB(19, 5, 19, 7),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.40),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildAccountMenu({Widget? child}) {
    return PopupMenuButton<String>(
      position: PopupMenuPosition.under,
      offset: const Offset(0, 10),
      color: const Color(0xFF17191F),
      elevation: 16,
      shadowColor: Colors.black,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 255),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      onSelected: _onMenuSelected,
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          padding: const EdgeInsets.fromLTRB(19, 10, 19, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tr('My Account', 'حسابي'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _tr('Profile & account preferences', 'البروفايل وإعدادات الحساب'),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.52),
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        _menuDivider(),
        _menuLabel(_tr('ACCOUNT', 'الحساب')),
        _menuItem('profile', _tr('My Profile', 'بروفايلي'), _icProfile),
        _menuItem('account-settings', _tr('Account Settings', 'إعدادات الحساب'), _icSettings),
        _menuItem('login-security', _tr('Login & Security', 'الدخول والأمان'), _icLock),
        _menuItem('privacy-settings', _tr('Privacy & Permissions', 'الخصوصية والصلاحيات'), _icShield),
        _menuItem('notification-settings', _tr('Notifications', 'الإشعارات'), _icBell),
        _menuItem('app-preferences', _tr('App Preferences', 'تفضيلات التطبيق'), _icGlobe),
        _menuDivider(),
        _menuItem('help-support', _tr('Help & Support', 'المساعدة والدعم'), _icHelp),
        _menuItem('terms-privacy', _tr('Terms & Privacy Policy', 'الشروط وسياسة الخصوصية'), _icTerms),
        _menuDivider(),
        _menuItem('logout', _tr('Logout', 'تسجيل الخروج'), _icLogout, danger: true),
      ],
      // ترس Material المتماثل (الـ SVG القديم كان مرسوم يدوي وباين معوج)
      child: child ?? const _IconBox(child: Icon(Icons.settings_outlined, color: Colors.white, size: 21)),
    );
  }

  // ---- Hero ----

  Widget _buildHero(bool narrow, {bool wide = false}) {
    final minHeight = wide ? 470.0 : (narrow ? 330.0 : 350.0);

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.34),
            blurRadius: 60,
            offset: const Offset(0, 25),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(
            child: _LoopVideo(url: '$_kMedia/Videos/Home/Fantasy_background.mp4'),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.25, 0.67, 1.0],
                  colors: const [
                    Color.fromRGBO(11, 11, 15, 0.10),
                    Color.fromRGBO(11, 11, 15, 0.18),
                    Color.fromRGBO(11, 11, 15, 0.78),
                    Color.fromRGBO(11, 11, 15, 0.98),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: wide ? -120 : -80,
            top: wide ? -120 : -70,
            width: wide ? 520 : 240,
            height: wide ? 520 : 240,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _kGreen.withOpacity(0.12),
                    _kGreen.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Container(
            constraints: BoxConstraints(minHeight: minHeight),
            // المسافة اللي فوق محجوزة لشارة LIVE NOW: لو الكلام زاد (زي سطر "برعاية")
            // الكارت بيطول لتحت بدل ما الكلام يطلع فوق الشارة.
            padding: wide
                ? EdgeInsets.fromLTRB(46, 30 + _badgeH + 22, 46, 42)
                : EdgeInsets.fromLTRB(
                    narrow ? 18 : 22,
                    21 + _badgeH + 14,
                    narrow ? 18 : 22,
                    narrow ? 17 : 20,
                  ),
            alignment: AlignmentDirectional.bottomStart,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tr('${AppConfig.appName.toUpperCase()} COMPETITION', 'مسابقات ${AppConfig.appName}'),
                  style: TextStyle(
                    color: _kGreen,
                    fontSize: wide ? 13 : 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 640 : 290),
                  child: Text(
                    _tr('Fantasy Football', 'فانتازي كورة'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: wide ? 58 : (narrow ? 28 : 31),
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      height: 1.02,
                    ),
                  ),
                ),
                // نفس السطر المخفي في الـ HTML (visibility:hidden) عشان المسافات
                const SizedBox(height: 8),
                Opacity(
                  opacity: 0,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 285),
                    child: const Text(
                      'Weekly • Selected Matches',
                      style: TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 560 : double.infinity),
                  child: Text(
                    _tr('Build your team. Compete with everyone. Climb the leaderboard.', 'كوّن فريقك. نافس الكل. اطلع في الترتيب.'),
                    style: TextStyle(color: Colors.white, fontSize: wide ? 19 : 16, height: 1.45),
                  ),
                ),
                SizedBox(height: wide ? 22 : 14),
                Row(
                  children: [
                    _heroStat(_playersText, _tr('Players', 'لاعب'), wide: wide),
                    if (_countdownText != null) ...[
                      _heroDivider(),
                      _heroStat(_countdownText!, _countdownLabel, wide: wide),
                    ],
                    if (_prizeText != null) ...[
                      _heroDivider(),
                      _heroStat(_prizeText!, _tr('1st Prize', 'جايزة الأول'), wide: wide),
                    ],
                  ],
                ),
                // راعي الفانتازي/الجولة على الهيرو: "برعاية X"
                const AdSlot('home_hero', padding: EdgeInsets.only(top: 12),
                    prefixEn: 'Presented by', prefixAr: 'برعاية'),
                SizedBox(height: wide ? 26 : 17),
                ScaleTransition(
                  alignment: AppLang.isArabic ? Alignment.centerRight : Alignment.centerLeft,
                  scale: Tween<double>(begin: 1, end: 1.015).animate(_playPulse),
                  child: _Pressable(
                    pressedScale: 0.97,
                    onTap: _playFantasy,
                    child: Container(
                      width: wide ? 300 : double.infinity,
                      height: wide ? 56 : 53,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF1A1A), // أحمر بادجر (زي Fantasy)
                        borderRadius: BorderRadius.circular(17),
                        boxShadow: [BoxShadow(color: const Color(0xFFFF1A1A).withOpacity(0.35), blurRadius: 22, offset: const Offset(0, 8))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _tr('PLAY NOW', 'العب دلوقتي'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 9),
                          _svgIcon(
                            _icArrow,
                            hex: '#FFFFFF',
                            size: 17,
                            strokeWidth: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          PositionedDirectional(
            top: wide ? 30 : 21,
            start: wide ? 44 : 21,
            child: _buildLiveBadge(),
          ),
        ],
      ),
    );
  }

  /// طول شارة LIVE NOW (بيكبر مع حجم الخط في إعدادات الموبايل)
  double get _badgeH => 16 + MediaQuery.textScalerOf(context).scale(15);

  Widget _heroDivider() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Container(width: 1, height: 28, color: Colors.white.withOpacity(0.15)),
      );

  Widget _heroStat(String value, String label, {bool wide = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: wide ? 20 : 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: wide ? 5 : 3),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.46),
            fontSize: wide ? 12.5 : 10,
          ),
        ),
      ],
    );
  }

  Widget _buildLiveBadge() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.42),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.13)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  return Opacity(
                    opacity: 1 - 0.55 * _pulse.value,
                    child: Transform.scale(
                      scale: 1 - 0.28 * _pulse.value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _kGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _kGreen.withOpacity(0.9),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                _tr('LIVE NOW', 'شغال دلوقتي'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- More coming ----

  Widget _buildComingSection(bool narrow, {bool wide = false}) {
    final gap = narrow ? 7.0 : 9.0;
    final cardHeight = narrow ? 155.0 : 190.0;
    if (wide) return _buildComingGrid();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tr('More coming to ${AppConfig.appName}', 'جاي قريب على ${AppConfig.appName}'),
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 13),
        // كل الرياضات: نفس مقاس الكروت والمسافات بالظبط (3 ظاهرين)، واليوزر بيسكرول يمين وشمال
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 2 * gap) / 3;
            // بيتحرك لوحده كارت كارت (دايرة مالهاش آخر)، ويقف لما اليوزر يلمسه
            return SizedBox(
              height: cardHeight,
              child: _AutoSlideRow(
                count: kCompSports.length,
                itemExtent: cardWidth + gap,
                itemBuilder: (i) => Padding(
                  padding: EdgeInsetsDirectional.only(end: gap),
                  child: SizedBox(
                    width: cardWidth,
                    child: _sportCard(kCompSports[i], cardHeight, narrow),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// الويب: كل الرياضات في شبكة (من غير سكرول جنب)
  Widget _buildComingGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tr('More coming to ${AppConfig.appName}', 'جاي قريب على ${AppConfig.appName}'),
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.2),
        ),
        const SizedBox(height: 6),
        Text(
          _tr('Pick a sport to register your interest.', 'اختار رياضة وسجّل اهتمامك.'),
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13.5),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, c) {
          const gap = 14.0;
          final cols = (c.maxWidth / 200).floor().clamp(3, 7).toInt();
          final cw = (c.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final s in kCompSports)
                SizedBox(width: cw, child: _WebHover(child: _sportCard(s, cw * 1.22, false))),
            ],
          );
        }),
      ],
    );
  }

  /// دوسة على كارت: روح للمسابقات واللعبة دي متعلّمة جاهزة
  void _openCompetition(CompSport sport) {
    competitionPreselect.value = sport.id;
    widget.onOpenCompetitions?.call();
  }

  Widget _sportCard(CompSport sport, double height, bool narrow) {
    final name = AppLang.isArabic ? 'مسابقة ${sport.ar}' : '${sport.en} Competition';
    final videoUrl = sport.videoUrl;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openCompetition(sport),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.045),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: Colors.white.withOpacity(0.075)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // الصورة دايماً تحت كباك اب، والفيديو بيغطيها أول ما يشتغل
            Positioned.fill(
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(Color(0xFFC7C7C7), BlendMode.modulate),
                child: Image(
                  image: MediaCache.image(sport.imageUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(sport.icon, color: Colors.white24, size: 30),
                  ),
                ),
              ),
            ),
            if (videoUrl != null)
              Positioned.fill(child: _LoopVideo(url: videoUrl, dim: true)),
            // راعي الرياضة دي (لو فيه): "برعاية" + لوجو صغير فوق
            PositionedDirectional(
              top: 8, start: 8, end: 8,
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: AdSlot('home_sports', sport: sport.id, compact: true,
                    prefixEn: 'by', prefixAr: 'برعاية'),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.2, 0.5, 1.0],
                    colors: const [
                      Color.fromRGBO(11, 11, 15, 0.05),
                      Color.fromRGBO(11, 11, 15, 0.28),
                      Color.fromRGBO(11, 11, 15, 0.96),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 15,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: narrow ? 11 : 12,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, child) {
                      return Opacity(
                        opacity: 1 - 0.55 * _pulse.value,
                        child: Transform.scale(
                          scale: 1 - 0.28 * _pulse.value,
                          alignment: Alignment.centerLeft,
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      _tr('Coming Soon', 'قريبًا'),
                      style: TextStyle(color: Color(0xFFFFD900), fontSize: 9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// NOTIFICATIONS (نفس مودال الترحيب: إنجليزي/عربي)
// ---------------------------------------------------------------------------

class _NotifText {
  const _NotifText(this.title, this.text);

  final String title;
  final String text;
}

const List<String> _notifIcons = ['🎮', '👤', '🏆', '🚀'];

List<_NotifText> get _notifEn => [
  _NotifText(
    'Start Playing',
    'Fantasy Competition is available now. Tap Play Now, build your team and start competing.',
  ),
  _NotifText(
    'Build Your Sports Profile',
    'Complete your sports profile and start building your identity on ${AppConfig.appName}.',
  ),
  _NotifText(
    'Compete & Earn',
    'Follow competitions, challenges and rewards coming to the platform.',
  ),
  _NotifText(
    'More Sports Coming',
    'Football Competition, Padel, Basketball and more sports are coming soon.',
  ),
];

List<_NotifText> get _notifAr => [
  _NotifText(
    'ابدأ اللعب',
    'مسابقة الفانتازي متاحة الآن. اضغط على Play Now، كوّن فريقك وابدأ المنافسة.',
  ),
  _NotifText(
    'أنشئ ملفك الرياضي',
    'أكمل ملفك الرياضي وابدأ في بناء هويتك الرياضية على ${AppConfig.appName}.',
  ),
  _NotifText(
    'نافس واربح',
    'تابع المسابقات والتحديات والجوائز القادمة إلى المنصة.',
  ),
  _NotifText(
    'رياضات أخرى قادمة',
    'مسابقات كرة القدم، البادل، كرة السلة والمزيد من الرياضات قادمة قريبًا.',
  ),
];

class _NotificationsCard extends StatefulWidget {
  const _NotificationsCard({required this.autoClose});

  final bool autoClose;

  @override
  State<_NotificationsCard> createState() => _NotificationsCardState();
}

class _NotificationsCardState extends State<_NotificationsCard> {
  bool _arabic = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.autoClose) {
      _timer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final items = _arabic ? _notifAr : _notifEn;

    return Material(
      type: MaterialType.transparency,
      child: Directionality(
        textDirection: _arabic ? TextDirection.rtl : TextDirection.ltr,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Container(
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 70,
                  offset: const Offset(0, 25),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 23, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _arabic
                                  ? 'أهلاً بك في ${AppConfig.appName} 👋'
                                  : 'Welcome to ${AppConfig.appName} 👋',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _arabic
                                  ? 'إليك ما يمكنك فعله على ${AppConfig.appName}.'
                                  : 'Here’s what you can do on ${AppConfig.appName}.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.52),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 15),
                      _Pressable(
                        onTap: () => setState(() => _arabic = !_arabic),
                        child: Container(
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 9),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.055),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.10),
                            ),
                          ),
                          child: Text(
                            _arabic ? 'English' : 'العربية',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.78),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      _Pressable(
                        onTap: _close,
                        child: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.055),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.10),
                            ),
                          ),
                          child: const Text(
                            '×',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  for (int i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _notifItem(_notifIcons[i], items[i]),
                  ],
                  const SizedBox(height: 17),
                  _Pressable(
                    pressedScale: 0.97,
                    onTap: _close,
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        _arabic ? 'حسنًا' : 'Got it',
                        style: const TextStyle(
                          color: _kDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _notifItem(String icon, _NotifText item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withOpacity(0.075)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _kGreen.withOpacity(0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 17)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.text,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.56),
                    fontSize: 10,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LOGOUT CONFIRMATION
// ---------------------------------------------------------------------------

class _LogoutCard extends StatelessWidget {
  const _LogoutCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 350),
        child: Container(
          padding: const EdgeInsets.fromLTRB(21, 25, 21, 21),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.11)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.48),
                blurRadius: 70,
                offset: const Offset(0, 25),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D4D).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: _svgIcon(_icLogout, hex: '#FF7777', size: 27),
              ),
              const SizedBox(height: 17),
              const Text(
                'Confirm Logout',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'Are you sure you want to log out?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.62),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _Pressable(
                      pressedScale: 0.96,
                      onTap: () => Navigator.of(context).pop(false),
                      child: Container(
                        height: 45,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.10),
                          ),
                        ),
                        child: const Text(
                          'No, Cancel',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Pressable(
                      pressedScale: 0.96,
                      onTap: () => Navigator.of(context).pop(true),
                      child: Container(
                        height: 45,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D4D),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Text(
                          'Yes, Logout',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// COMING SOON FULLSCREEN OVERLAY
// ---------------------------------------------------------------------------

class _ComingSoonOverlay extends StatefulWidget {
  const _ComingSoonOverlay();

  @override
  State<_ComingSoonOverlay> createState() => _ComingSoonOverlayState();
}

class _ComingSoonOverlayState extends State<_ComingSoonOverlay> {
  VideoPlayerController? _controller;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = await MediaCache.video('$_kMedia/Videos/Home/comingsoon.mp4');
    if (!mounted) { controller.dispose(); return; }
    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted) {
        return;
      }
      controller.addListener(_onTick);
      await controller.setVolume(1);
      await controller.seekTo(Duration.zero);
      await controller.play();
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      _close();
    }
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    final value = controller.value;
    if (value.hasError) {
      _close();
      return;
    }

    if (value.isInitialized &&
        value.duration > Duration.zero &&
        value.position >= value.duration) {
      _close();
    }
  }

  void _close() {
    if (_closing || !mounted) {
      return;
    }
    _closing = true;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return Material(
      color: Colors.black,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: SizedBox.expand(
          child: ready
              ? FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}


/// خطوط مايلة خفيفة في خلفية الهوم (نفس إحساس صفحة اللوجن)
class _HomeRaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0DFFFFFF)
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final rays = <List<Offset>>[
      [Offset(w * 0.55, 0), Offset(w * 0.70, 0), Offset(w * 0.20, h)],
      [Offset(w * 0.85, 0), Offset(w * 0.95, 0), Offset(w * 0.45, h)],
      [Offset(w, h * 0.10), Offset(w, h * 0.22), Offset(w * 0.60, h)],
    ];
    for (final r in rays) {
      canvas.drawPath(
        Path()
          ..moveTo(r[0].dx, r[0].dy)
          ..lineTo(r[1].dx, r[1].dy)
          ..lineTo(r[2].dx, r[2].dy)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


// ---------------------------------------------------------------------------
// WELCOME: أونبوردنج بسيط لليوزر الجديد بس (مرة واحدة)
// ---------------------------------------------------------------------------

class _WelcomeSheet extends StatefulWidget {
  const _WelcomeSheet();

  @override
  State<_WelcomeSheet> createState() => _WelcomeSheetState();
}

class _WelcomeSheetState extends State<_WelcomeSheet> {
  bool _ar = AppLang.isArabic;

  String t(String en, String ar) => _ar ? ar : en;

  static const Color _red = Color(0xFFFF1A1A);
  static const Color _line = Color(0xFF2C2C2C);

  Widget _row(String emoji, String title, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40, height: 40, alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: _line)),
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(text, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, height: 1.45)),
          ])),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Directionality(
      textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
        decoration: const BoxDecoration(
          color: Color(0xFF111114),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: _line)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 14),
          Row(children: [
            Container(width: 46, height: 46, padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)),
              child: Image.asset(Brand.badger, fit: BoxFit.contain)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _ar = !_ar),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
                child: Text(_ar ? 'English' : 'عربي', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Text(t('Welcome to ${AppConfig.appName} 👋', 'أهلاً بيك في ${AppConfig.appName} 👋'),
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.2)),
          const SizedBox(height: 6),
          Text(t('Here is what is waiting for you.', 'ده اللي مستنيك هنا.'),
              style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13)),
          const SizedBox(height: 20),
          _row('⚽', t('Fantasy', 'فانتازي'), t('Build your team and compete every round.', 'كوّن فريقك ونافس كل جولة.')),
          _row('🏆', t('Competitions', 'المسابقات'), t('Register in your sport and be the first to know when it opens.', 'سجّل في اللعبة اللي بتحبها، وأول ما البطولة تفتح هتعرف.')),
          _row('👤', t('Your profile', 'بروفايلك'), t('Complete your info and build your sports identity.', 'كمّل بياناتك وابني هويتك الرياضية.')),
          const SizedBox(height: 8),
          SizedBox(height: 52, child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: Text(t("Let's play Fantasy", 'يلا نلعب فانتازي'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          )),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('Later', 'بعدين'), style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}


/// الويب: الكارت بيعلى سنة لما الماوس يقف عليه
class _WebHover extends StatefulWidget {
  const _WebHover({required this.child});
  final Widget child;
  @override
  State<_WebHover> createState() => _WebHoverState();
}

class _WebHoverState extends State<_WebHover> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        child: AnimatedScale(
          scale: _h ? 1.025 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}


/// صف الرياضات في الهوم (الموبايل): بيقف 3 ثواني، ويتزحلق بنعومة كارت واحد، وهكذا.
/// دايرة مالهاش آخر (بعد آخر رياضة ترجع الكورة)، بيشتغل بس والهوم ظاهر والتطبيق مفتوح،
/// ولو اليوزر لمسه أو سحبه بيقف، ويكمّل بعد 4 ثواني من آخر لمسة.
class _AutoSlideRow extends StatefulWidget {
  const _AutoSlideRow({required this.count, required this.itemExtent, required this.itemBuilder});
  final int count;
  final double itemExtent;
  final Widget Function(int i) itemBuilder;
  @override
  State<_AutoSlideRow> createState() => _AutoSlideRowState();
}

class _AutoSlideRowState extends State<_AutoSlideRow> with WidgetsBindingObserver {
  static const _pause = Duration(seconds: 3);
  static const _slide = Duration(milliseconds: 750);
  static const _resumeAfterTouch = Duration(seconds: 4);

  final _ctrl = ScrollController();
  Timer? _timer;
  bool _touching = false;
  bool _appOpen = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HomeActions.active.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HomeActions.active.removeListener(_sync);
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    _appOpen = s == AppLifecycleState.resumed;
    _sync();
  }

  bool get _running => HomeActions.active.value && _appOpen && !_touching && widget.count > 3;

  void _sync() {
    _timer?.cancel();
    if (_running) _timer = Timer(_pause, _step);
  }

  Future<void> _step() async {
    if (!mounted || !_running || !_ctrl.hasClients) return;
    // مكان الكارت الجاي بالظبط (حتى لو اليوزر كان ساحبه لنص كارت)
    final next = ((_ctrl.offset / widget.itemExtent).floor() + 1) * widget.itemExtent;
    try {
      await _ctrl.animateTo(next, duration: _slide, curve: Curves.easeInOutCubic);
    } catch (_) {}
    _sync();
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _touching = true;
      _timer?.cancel();
    } else if (n is ScrollEndNotification && _touching) {
      _touching = false;
      _timer?.cancel();
      _timer = Timer(_resumeAfterTouch, _sync);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: ListView.builder(
          controller: _ctrl,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          // من غير itemCount = صف مالوش آخر؛ الرياضة رقم i % العدد
          itemBuilder: (_, i) => widget.itemBuilder(i % widget.count),
        ),
      );
}
