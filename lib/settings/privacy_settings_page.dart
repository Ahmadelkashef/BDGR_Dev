import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_lang.dart';
import 'account_settings_page.dart';
import 'settings_ui.dart';
import 'terms_privacy_page.dart';

/// الخصوصية والصلاحيات: متوصلة بالداتابيز (privacy_get / privacy_save / my_blocked_users).
/// "للمتابعين بس" بيتطبق من السيرفر (get_public_moments)، والعمر/المكان بيستخبوا في get_public_profile.
class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> with WidgetsBindingObserver {
  final _sb = Supabase.instance.client;
  Map<String, dynamic>? _d;
  List<Map<String, dynamic>> _blocked = [];
  LocationPermission? _locPerm;
  bool _loading = true;
  bool _failed = false;
  final Set<String> _saving = {};
  final Set<int> _unblocking = {};

  bool get _ar => AppLang.isArabic;
  String _t(String en, String ar) => AppLang.t(en, ar);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // راجع من إعدادات الموبايل: نحدّث حالة الصلاحية
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadPermission();
  }

  Future<void> _loadPermission() async {
    try {
      final p = await Geolocator.checkPermission();
      if (mounted) setState(() => _locPerm = p);
    } catch (e) {
      debugPrint('checkPermission error: $e');
    }
  }

  Future<void> _load() async {
    setState(() { _loading = _d == null; _failed = false; });
    try {
      final res = await Future.wait([
        _sb.rpc('privacy_get'),
        _sb.rpc('my_blocked_users'),
      ]);
      await _loadPermission();
      if (!mounted) return;
      setState(() {
        _d = res[0] is Map ? Map<String, dynamic>.from(res[0] as Map) : null;
        _blocked = (res[1] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
        _failed = _d == null;
      });
    } catch (e) {
      debugPrint('privacy load error: $e');
      if (mounted) setState(() { _loading = false; _failed = true; });
    }
  }

  // بنغيّر في الشاشة على طول، ولو الحفظ فشل نرجّع القيمة
  Future<void> _set(String key, bool value) async {
    final old = _d?[key];
    setState(() { _d?[key] = value; _saving.add(key); });
    try {
      final res = await _sb.rpc('privacy_save', params: {'p': {key: value}});
      if (!mounted) return;
      setState(() => _d = res is Map ? Map<String, dynamic>.from(res) : _d);
    } catch (e) {
      debugPrint('privacy_save error: $e');
      if (!mounted) return;
      setState(() => _d?[key] = old);
      sToast(context, _t("Couldn't save. Try again.", 'محصلش حفظ. جرّب تاني.'));
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }

  Future<void> _unblock(Map<String, dynamic> u) async {
    final id = (u['user_id'] as num?)?.toInt();
    if (id == null) return;
    final name = (u['display_name'] ?? u['username'] ?? '').toString();
    final ok = await sInfo(context,
        title: _t('Unblock $name?', 'تشيل البلوك عن $name؟'),
        icon: Icons.person_add_alt_rounded,
        body: [_t('You will be able to see each other\'s profiles again. They won\'t be notified.',
                  'هتقدروا تشوفوا بروفايلات بعض تاني، ومش هيوصله إشعار.')],
        confirm: _t('Unblock', 'شيل البلوك'));
    if (ok != true || !mounted) return;
    setState(() => _unblocking.add(id));
    try {
      await _sb.rpc('unblock_user', params: {'p_target_user_id': id});
      if (!mounted) return;
      setState(() => _blocked.removeWhere((x) => (x['user_id'] as num?)?.toInt() == id));
      sToast(context, _t('Unblocked ✓', 'البلوك اتشال ✓'));
    } catch (e) {
      debugPrint('unblock_user error: $e');
      if (mounted) sToast(context, _t('Something went wrong. Try again.', 'حصلت مشكلة. جرّب تاني.'));
    } finally {
      if (mounted) setState(() => _unblocking.remove(id));
    }
  }

  Future<void> _openPhoneSettings() async {
    try {
      final ok = await Geolocator.openAppSettings();
      if (!ok && mounted) {
        sToast(context, _t('Open your phone Settings → Apps → BDGR.', 'افتح إعدادات الموبايل ← التطبيقات ← BDGR.'));
      }
    } catch (e) {
      debugPrint('openAppSettings error: $e');
    }
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  // ── عرض ────────────────────────────────────────────────────────────────────
  Widget _toggle(String key, String title, String desc) => SRow(
        title: title,
        desc: desc,
        trailing: _saving.contains(key)
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: SC.accent, strokeWidth: 2))
            : SSwitch(value: _d?[key] == true, onChanged: (v) => _set(key, v)),
      );

  Widget _audience() {
    final followersOnly = _d?['followers_only'] == true;
    Widget opt(bool value, String label, IconData icon) => Expanded(
          child: GestureDetector(
            onTap: _saving.contains('followers_only') || followersOnly == value
                ? null : () => _set('followers_only', value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: followersOnly == value ? SC.accent.withOpacity(0.12) : SC.chip,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: followersOnly == value ? SC.accent : const Color(0xFF41444F)),
              ),
              child: Column(children: [
                Icon(icon, size: 20, color: followersOnly == value ? SC.text : SC.muted),
                const SizedBox(height: 5),
                Text(label, style: TextStyle(color: SC.text, fontSize: 12.5,
                    fontWeight: followersOnly == value ? FontWeight.w800 : FontWeight.w600)),
              ]),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_t('Who can see your moments', 'مين يشوف المومنتس بتاعتك'),
            style: const TextStyle(color: SC.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(_t('Your name and photo are always visible so people can find you.',
                'اسمك وصورتك بيبانوا دايمًا علشان الناس تلاقيك.'),
            style: const TextStyle(color: SC.muted, fontSize: 11.5, height: 1.6)),
        const SizedBox(height: 12),
        Row(children: [
          opt(false, _t('Everyone', 'الكل'), Icons.public_rounded),
          const SizedBox(width: 10),
          opt(true, _t('Followers only', 'المتابعين بس'), Icons.lock_outline_rounded),
        ]),
      ]),
    );
  }

  Widget _permissionPill() {
    switch (_locPerm) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return SPill(_t('Allowed', 'مسموح'), color: SC.success);
      case LocationPermission.denied:
      case LocationPermission.deniedForever:
        return SPill(_t('Not allowed', 'مش مسموح'), color: SC.warning);
      default:
        return SPill(_t('Unknown', 'مش معروف'));
    }
  }

  Widget _blockedList() {
    if (_blocked.isEmpty) {
      return SRow(title: _t("You haven't blocked anyone", 'مفيش حد عامل له بلوك'), valueMuted: true);
    }
    return Column(children: [
      for (var i = 0; i < _blocked.length; i++) ...[
        if (i > 0) const Divider(height: 1, color: SC.border),
        _blockedRow(_blocked[i]),
      ],
    ]);
  }

  Widget _blockedRow(Map<String, dynamic> u) {
    final id = (u['user_id'] as num?)?.toInt();
    final avatar = (u['avatar_url'] ?? '').toString();
    final name = (u['display_name'] ?? '').toString().trim();
    final username = (u['username'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: SC.chip,
          backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
          child: avatar.isEmpty ? const Icon(Icons.person_outline, color: SC.muted, size: 20) : null,
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name.isNotEmpty ? name : username, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: SC.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
          if (username.isNotEmpty)
            Text('@$username', maxLines: 1, overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: SC.muted, fontSize: 11.5)),
        ])),
        const SizedBox(width: 8),
        id != null && _unblocking.contains(id)
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: SC.accent, strokeWidth: 2))
            : SBtn(_t('Unblock', 'شيل البلوك'), onTap: () => _unblock(u)),
      ]),
    );
  }

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
                      Text(_t("Couldn't load your privacy settings.", 'مقدرناش نحمّل إعدادات الخصوصية.'),
                          style: const TextStyle(color: SC.muted, fontSize: 14)),
                      const SizedBox(height: 12),
                      SBtn(_t('Try again', 'جرّب تاني'), onTap: _load),
                    ])))
                : _page(),
      );

  Widget _page() => SPage(
        title: _t('Privacy & Permissions', 'الخصوصية والصلاحيات'),
        subtitle: _t('Choose what others see and what the app can use.', 'اختار الناس تشوف إيه، والتطبيق يستخدم إيه.'),
        bottomText: 'BDGR · ${_t('Privacy & Permissions', 'الخصوصية والصلاحيات')}',
        children: [
          SSection(
            icon: Icons.visibility_outlined,
            title: _t('Your profile', 'بروفايلك'),
            children: [SCard(children: [
              _audience(),
              _toggle('show_age', _t('Show my age', 'اظهر عمري'),
                  _t('Visitors see your age on your profile.', 'الزوار يشوفوا عمرك في البروفايل.')),
              _toggle('show_location', _t('Show my city', 'اظهر مدينتي'),
                  _t('Visitors see your city and governorate. Your area rankings still work if hidden.',
                      'الزوار يشوفوا مدينتك ومحافظتك. لو خبيتها، ترتيب منطقتك بيفضل شغال عادي.')),
            ])],
          ),
          SSection(
            icon: Icons.person_off_outlined,
            title: _t('Blocked accounts', 'الحسابات اللي عامل لها بلوك'),
            children: [SCard(children: [_blockedList()])],
          ),
          SSection(
            icon: Icons.campaign_outlined,
            title: _t('Messages from BDGR', 'رسايل من BDGR'),
            children: [SCard(children: [
              _toggle('marketing', _t('Offers & news', 'العروض والأخبار'),
                  _t('Get offers, prizes and news from BDGR. Account messages always reach you.',
                      'توصلك عروض وجوايز وأخبار من BDGR. رسايل الحساب المهمة بتوصلك دايمًا.')),
            ])],
          ),
          SSection(
            icon: Icons.smartphone_rounded,
            title: _t('Phone permissions', 'صلاحيات الموبايل'),
            description: _t('Your phone controls these. BDGR only asks when a feature needs it.',
                'الموبايل هو اللي بيتحكم فيها، وBDGR بيطلبها بس لما ميزة تحتاجها.'),
            children: [SCard(children: [
              SRow(
                icon: Icons.location_on_outlined,
                title: _t('Location', 'المكان'),
                desc: _t('Used to set your city for the rankings.', 'بيتحدد بيه مدينتك علشان الترتيب.'),
                trailing: _permissionPill(),
              ),
              SRow(
                icon: Icons.photo_camera_outlined,
                title: _t('Camera & photos', 'الكاميرا والصور'),
                desc: _t('Used when you add a profile photo or a moment.', 'بتتطلب لما تضيف صورة بروفايل أو مومنت.'),
              ),
              SRow(
                icon: Icons.settings_outlined,
                title: _t('Open phone settings', 'افتح إعدادات الموبايل'),
                desc: _t('Change any permission for BDGR.', 'غيّر أي صلاحية لـ BDGR.'),
                onTap: _openPhoneSettings,
                trailing: SBtn(_t('Open', 'افتح'), onTap: _openPhoneSettings),
              ),
            ])],
          ),
          SSection(
            icon: Icons.policy_outlined,
            title: _t('Your data', 'بياناتك'),
            children: [SCard(children: [
              SRow(
                title: _t('Privacy Policy', 'سياسة الخصوصية'),
                onTap: () => _push(const TermsPrivacyPage()),
                trailing: Icon(_ar ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: SC.muted),
              ),
              SRow(
                title: _t('Delete my account', 'مسح حسابي'),
                desc: _t('From Account Settings.', 'من إعدادات الحساب.'),
                onTap: () => _push(const AccountSettingsPage()),
                trailing: Icon(_ar ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: SC.muted),
              ),
            ])],
          ),
        ],
      );
}
