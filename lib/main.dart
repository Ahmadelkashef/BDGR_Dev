import 'dart:async';

import 'ads/ads.dart';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import 'app_lang.dart';
import 'auth/auth_callback_screen.dart';
import 'auth/landing_screen.dart';
import 'auth/login_config.dart';
import 'auth/video_preloader.dart';
import 'brand.dart';
import 'deep_links.dart';
import 'diag.dart';
import 'local_store.dart';
import 'main_shell.dart';
import 'push/push_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PushService.registerBackgroundHandler();
  unawaited(Diag.init());

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:              Colors.transparent,
    statusBarIconBrightness:     Brightness.light,
    systemNavigationBarColor:    Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  runApp(const Bootstrap());
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  bool    _ready          = false;
  bool    _supabaseReady  = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (_error != null) setState(() => _error = null);

    if (!AppConfig.isConfigured) {
      setState(() => _error =
          'SUPABASE_URL / SUPABASE_KEY / APP_ID are missing in this build.');
      return;
    }

    try {
      if (!_supabaseReady) {
        await Supabase.initialize(
          url:     AppConfig.supabaseUrl,
          anonKey: AppConfig.supabaseKey,
          // الداتابيز بتعرف منه التطبيق (التسجيل + user_apps)
          headers: {'x-app-id': AppConfig.appId},
          // الويب: الموقع على نفس الدومين بتاع الداشبورد (github.io)، فلازم مفتاح جلسة
          // خاص بيه، وإلا بياخد جلسة الأدمن بتاعة الداشبورد (والعكس).
          authOptions: kIsWeb
              ? FlutterAuthClientOptions(
                  localStorage: SharedPreferencesLocalStorage(persistSessionKey: 'bdgr-web-auth-token'))
              : const FlutterAuthClientOptions(),
        ).timeout(const Duration(seconds: 15));
        _supabaseReady = true;
      }

      await AppLang.load();
      if (mounted) setState(() => _ready = true);

      unawaited(DeepLinks.start());
      _startBackgroundWork();
    } catch (e) {
      debugPrint('Startup failed: $e');
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _startBackgroundWork() {
    if (supa.auth.currentSession != null) return; // داخل ← مش محتاج

    unawaited(
      LoginConfig.load().then((_) {
        VideoPreloader.start(
          poster: LoginConfig.loginPoster,
          videos: LoginConfig.loginVideos,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const App();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: Brand.background,
        body: _error == null ? const BrandSplash() : _errorView(),
      ),
    );
  }

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrandLogo(width: 180),
          const SizedBox(height: 32),
          const Text(
            'Startup failed',
            style: TextStyle(
              color: Color(0xFFFF7777),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _init, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

/// للتنقل من برّه الشاشات (الرجوع من المتصفح بعد الدخول بحساب)
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class _AppState extends State<App> {
  StreamSubscription<AuthState>? _authSub;
  bool _handlingSignIn = false;

  @override
  void initState() {
    super.initState();
    _authSub = supa.auth.onAuthStateChange.listen(_onAuthState, onError: _onAuthError);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  /// المتصفح رجّعنا بجلسة جديدة بعد الدخول بجوجل / فيسبوك / X / تيك توك (نفس كود iPLAY)
  Future<void> _onAuthState(AuthState state) async {
    final session = state.session;
    if (state.event != AuthChangeEvent.signedIn || session == null || _handlingSignIn) return;
    _handlingSignIn = true;
    try {
      final provider = await LocalStore.getValidPendingProvider();
      if (provider == null) return; // جلسة راجعة من التخزين أو دخول بالـ OTP
      await LocalStore.clearPendingProvider();
      appNavigatorKey.currentState?.pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: (_) => AuthCallbackScreen(session: session, provider: provider)),
        (route) => false,
      );
    } finally {
      _handlingSignIn = false;
    }
  }

  /// أخطاء الدخول الراجعة من المتصفح (مثلاً اليوزر رفض)
  Future<void> _onAuthError(Object error) async {
    final provider = await LocalStore.getValidPendingProvider();
    if (provider == null) return;
    await LocalStore.clearPendingProvider();
    debugPrint('social sign-in error ($provider): $error');
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(SnackBar(
      content: Text(AppLang.isArabic ? 'الدخول ما كملش، حاول تاني' : 'Sign-in was not completed. Try again.'),
    ));
  }

  /// الشاشة الأولى: لو فيه جلسة محفوظة روح للهوم على طول
  Widget get _home {
    if (supa.auth.currentSession != null) {
      return const MainShell();
    }
    return const LandingScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                    AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Brand.background,
      ),
      navigatorKey: appNavigatorKey,
      home: _home,
      // الويب: السحب بالماوس/التراك باد بيشتغل في القوايم الجانبية والريلز
      scrollBehavior: kIsWeb
          ? const MaterialScrollBehavior().copyWith(dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            })
          : null,
      navigatorObservers: [AdsRouteGuard()],   // الإعلان الكبير بيستنى أي نافذة مفتوحة
    );
  }
}
