import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_lang.dart';
import '../auth/landing_screen.dart';
import '../local_store.dart';
import 'settings_ui.dart';
import '../push/push_service.dart';

/// الدخول والأمان: متوصلة بالداتابيز (security_overview).
/// الدخول عندنا بالموبايل + كود (OTP) بس. الحسابات المربوطة بتتربط/تتفك من تعديل البروفايل.
class LoginSecurityPage extends StatefulWidget {
  const LoginSecurityPage({super.key});

  @override
  State<LoginSecurityPage> createState() => _LoginSecurityPageState();
}

class _LoginSecurityPageState extends State<LoginSecurityPage> {
  final _sb = Supabase.instance.client;
  Map<String, dynamic>? _d;
  String? _thisDevice;
  bool _loading = true;
  bool _failed = false;
  bool _busy = false;

  bool get _ar => AppLang.isArabic;
  String _t(String en, String ar) => AppLang.t(en, ar);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = _d == null; _failed = false; });
    try {
      _thisDevice ??= await LocalStore.getDeviceId();
      final res = await _sb.rpc('security_overview');
      if (!mounted) return;
      setState(() {
        _d = res is Map ? Map<String, dynamic>.from(res) : null;
        _loading = false;
        _failed = _d == null;
      });
    } catch (e) {
      debugPrint('security_overview error: $e');
      if (mounted) setState(() { _loading = false; _failed = true; });
    }
  }

  // ── عرض ────────────────────────────────────────────────────────────────────
  /// +201012345678 → +20 10•••• 5678
  String _maskPhone(String? p) {
    final s = (p ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    if (s.length < 8) return s.isEmpty ? _t('Not set', 'مش متحدد') : s;
    final plus = s.startsWith('+') ? '+' : '';
    final digits = s.replaceAll('+', '');
    final cc = digits.startsWith('20') ? '20' : digits.substring(0, 2);
    final rest = digits.substring(cc.length);
    if (rest.length < 6) return '$plus$cc $rest';
    return '$plus$cc ${rest.substring(0, 2)}${'•' * (rest.length - 6)} ${rest.substring(rest.length - 4)}';
  }

  String _ago(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '—';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 2) return _t('Just now', 'دلوقتي');
    if (diff.inHours < 1) return _t('${diff.inMinutes} min ago', 'من ${diff.inMinutes} دقيقة');
    if (diff.inDays < 1) return _t('${diff.inHours} h ago', 'من ${diff.inHours} ساعة');
    if (diff.inDays < 30) return _t('${diff.inDays} days ago', 'من ${diff.inDays} يوم');
    const en = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const ar = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return _ar ? '${d.day} ${ar[d.month - 1]} ${d.year}' : '${d.day} ${en[d.month - 1]} ${d.year}';
  }

  String _deviceName(Map d) {
    String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
    final brand = cap((d['manufacturer'] ?? '').toString());
    final model = (d['model'] ?? '').toString();
    final name = [brand, model].where((x) => x.isNotEmpty).join(' ');
    return name.isEmpty ? _t('Unknown device', 'جهاز مش معروف') : name;
  }

  // ── أفعال ──────────────────────────────────────────────────────────────────
  Future<void> _signOutOthers() async {
    final ok = await sInfo(context,
        title: _t('Log out of other devices?', 'تخرج من الأجهزة التانية؟'),
        icon: Icons.devices_other_rounded,
        body: [_t('Every other phone logged in to your account will be logged out right away. You stay logged in here.',
                  'أي موبايل تاني داخل على حسابك هيخرج على طول، وانت هتفضل داخل هنا.')],
        confirm: _t('Log them out', 'خرّجهم'),
        danger: true);
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _sb.auth.signOut(scope: SignOutScope.others);
      await _sb.rpc('security_forget_other_devices', params: {'p_client_device_id': _thisDevice});
      await _load();
      if (mounted) sToast(context, _t('Other devices were logged out ✓', 'الأجهزة التانية خرجت ✓'));
    } catch (e) {
      debugPrint('signOut others error: $e');
      if (mounted) sToast(context, _t('Something went wrong. Try again.', 'حصلت مشكلة. جرّب تاني.'));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _signOut() async {
    final ok = await sInfo(context,
        title: _t('Log out?', 'تسجيل الخروج؟'),
        icon: Icons.logout_rounded,
        body: [_t('You will need your phone number and a code to log in again.',
                  'هتحتاج رقم موبايلك وكود علشان تدخل تاني.')],
        confirm: _t('Log out', 'اخرج'),
        danger: true);
    if (ok != true || !mounted) return;
    await PushService.unregister();
    try {
      await _sb.auth.signOut();
    } catch (e) {
      debugPrint('signOut error: $e');
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const LandingScreen()),
      (route) => false,
    );
  }

  void _tips() => sInfo(context,
        title: _t('Keep your account safe', 'خلّي حسابك في أمان'),
        icon: Icons.shield_outlined,
        body: [[
          _t("Never share your login code with anyone, even if they say they're from BDGR.",
              'ماتديش كود الدخول لأي حد، حتى لو قال إنه من BDGR.'),
          _t('BDGR will never ask you for your code by phone or message.',
              'BDGR عمره ما هيطلب منك الكود في مكالمة أو رسالة.'),
          _t("See a device you don't know below? Log out other devices.",
              'شايف جهاز مش بتاعك في القايمة؟ خرّج الأجهزة التانية.'),
          _t('Lost your phone or SIM? Log out other devices from a new phone.',
              'موبايلك أو الخط ضاع؟ ادخل من موبايل تاني وخرّج الأجهزة التانية.'),
        ]],
      );

  // ── البناء ─────────────────────────────────────────────────────────────────
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
                      Text(_t("Couldn't load your security info.", 'مقدرناش نحمّل بيانات الأمان.'),
                          style: const TextStyle(color: SC.muted, fontSize: 14)),
                      const SizedBox(height: 12),
                      SBtn(_t('Try again', 'جرّب تاني'), onTap: _load),
                    ])))
                : _page(),
      );

  Widget _linkedPill(bool on) => on
      ? SPill(_t('Linked', 'مربوط'), color: SC.success)
      : SPill(_t('Not linked', 'مش مربوط'));

  Widget _page() {
    final linked = _d?['linked'] is Map ? Map<String, dynamic>.from(_d!['linked'] as Map) : <String, dynamic>{};
    final devices = (_d?['devices'] as List?)?.whereType<Map>().toList() ?? const [];
    final prev = _d?['prev_login']?.toString();

    return SPage(
      title: _t('Login & Security', 'الدخول والأمان'),
      subtitle: _t('How you log in and which devices use your account.', 'إزاي بتدخل، وأنهي أجهزة داخلة على حسابك.'),
      bottomText: 'BDGR · ${_t('Login & Security', 'الدخول والأمان')}',
      children: [
        SSection(
          icon: Icons.login_rounded,
          title: _t('How you log in', 'طريقة الدخول'),
          children: [
            SCard(children: [
              SRow(
                icon: Icons.phone_iphone_rounded,
                highlight: true,
                title: _t('Phone number', 'رقم الموبايل'),
                desc: _t('You log in with your number and a one-time code (OTP).',
                    'بتدخل برقمك وكود بيوصلك (OTP).'),
                value: _maskPhone(_d?['phone']?.toString()),
                trailing: SPill(_t('Main', 'الأساسي'), color: SC.success),
              ),
            ]),
          ],
        ),
        SSection(
          icon: Icons.link_rounded,
          title: _t('Linked accounts', 'الحسابات المربوطة'),
          description: _t('Link or unlink them from Edit Profile.', 'بتربطها أو تفكها من "تعديل البروفايل".'),
          children: [SCard(children: [
            SRow(icon: Icons.g_mobiledata_rounded, title: 'Google', trailing: _linkedPill(linked['google'] == true)),
            SRow(icon: Icons.facebook_rounded, title: 'Facebook', trailing: _linkedPill(linked['facebook'] == true)),
            SRow(icon: Icons.music_note_rounded, title: 'TikTok', trailing: _linkedPill(linked['tiktok'] == true)),
            SRow(icon: Icons.alternate_email_rounded, title: 'X', trailing: _linkedPill(linked['x'] == true)),
          ])],
        ),
        SSection(
          icon: Icons.smartphone_rounded,
          title: _t('Your devices', 'أجهزتك'),
          description: prev == null ? null
              : _t('Previous login: ${_ago(prev)}', 'آخر دخول قبل كده: ${_ago(prev)}'),
          children: [
            SCard(children: [
              if (devices.isEmpty)
                SRow(title: _t('No devices yet', 'مفيش أجهزة لسه'), valueMuted: true),
              for (final d in devices)
                SRow(
                  icon: d['platform'] == 'ios' ? Icons.phone_iphone_rounded : Icons.phone_android_rounded,
                  highlight: d['client_device_id']?.toString() == _thisDevice,
                  title: _deviceName(d),
                  desc: [
                    if ((d['os_name'] ?? '').toString().isNotEmpty) '${d['os_name']} ${d['os_version'] ?? ''}'.trim(),
                    _t('Logged in ${_ago(d['last_seen_at']?.toString())}', 'دخل ${_ago(d['last_seen_at']?.toString())}'),
                  ].join(' · '),
                  trailing: d['client_device_id']?.toString() == _thisDevice
                      ? SPill(_t('This phone', 'الموبايل ده'), color: SC.success)
                      : null,
                ),
            ]),
            SCard(children: [
              SRow(
                icon: Icons.devices_other_rounded,
                title: _t('Log out of other devices', 'اخرج من الأجهزة التانية'),
                desc: _t('Use this if you see a device you don\'t know.', 'استخدمها لو شايف جهاز مش بتاعك.'),
                trailing: _busy
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: SC.accent, strokeWidth: 2))
                    : SBtn(_t('Log out', 'خرّجهم'), danger: true, onTap: _signOutOthers),
              ),
            ]),
          ],
        ),
        SSection(
          icon: Icons.shield_outlined,
          title: _t('Security', 'الأمان'),
          children: [SCard(children: [
            SRow(icon: Icons.health_and_safety_outlined,
                title: _t('Safety tips', 'نصايح الأمان'),
                onTap: _tips, trailing: SBtn(_t('View', 'شوف'), onTap: _tips)),
            SRow(icon: Icons.logout_rounded,
                title: _t('Log out', 'تسجيل الخروج'),
                desc: _t('Log out from this phone.', 'اخرج من الموبايل ده.'),
                onTap: _signOut, trailing: SBtn(_t('Log out', 'اخرج'), danger: true, onTap: _signOut)),
          ])],
        ),
      ],
    );
  }
}
