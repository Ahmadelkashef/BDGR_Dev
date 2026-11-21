import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_lang.dart';
import '../auth/landing_screen.dart';
import '../local_store.dart';
import '../profile/profile_page.dart' show captureVerifiedLocation;
import 'login_security_page.dart';
import 'settings_ui.dart';
import '../push/push_service.dart';

/// إعدادات الحساب: متوصلة بالداتابيز (account_settings_get / account_settings_save).
/// المكان من الـ GPS بس. مسح الحساب = طلب بيتنفذ بعد 30 يوم، ويتلغي لو اليوزر دخل تاني.
class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final _sb = Supabase.instance.client;
  Map<String, dynamic>? _d;
  bool _loading = true;
  bool _failed = false;
  bool _locBusy = false;

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
      final res = await _sb.rpc('account_settings_get');
      if (!mounted) return;
      setState(() {
        _d = res is Map ? Map<String, dynamic>.from(res) : null;
        _loading = false;
        _failed = _d == null;
      });
    } catch (e) {
      debugPrint('account_settings_get error: $e');
      if (mounted) setState(() { _loading = false; _failed = true; });
    }
  }

  String? _s(String k) {
    final v = _d?[k]?.toString().trim() ?? '';
    return v.isEmpty ? null : v;
  }

  String _err(Object e) {
    final m = e.toString();
    if (m.contains('username_taken')) return _t('This username is taken.', 'اليوزرنيم ده مستخدم.');
    if (m.contains('username_invalid')) {
      return _t('Username: 3–30 small English letters, numbers, . or _',
          'اليوزرنيم: من 3 لـ 30 حرف إنجليزي صغير أو أرقام أو . _');
    }
    if (m.contains('display_name_required')) return _t('Enter a display name.', 'اكتب اسم العرض.');
    if (m.contains('birth_date_invalid')) return _t('Check the birth date.', 'راجع تاريخ الميلاد.');
    if (m.contains('admin_account')) {
      return _t('Admin accounts can\'t be deleted from the app.', 'حسابات الأدمن مينفعش تتمسح من التطبيق.');
    }
    return _t('Something went wrong. Try again.', 'حصلت مشكلة. جرّب تاني.');
  }

  Future<bool> _save(Map<String, dynamic> patch) async {
    try {
      final res = await _sb.rpc('account_settings_save', params: {'p': patch});
      if (!mounted) return false;
      setState(() => _d = res is Map ? Map<String, dynamic>.from(res) : _d);
      sToast(context, _t('Saved ✓', 'اتحفظ ✓'));
      return true;
    } catch (e) {
      debugPrint('account_settings_save error: $e');
      if (mounted) sToast(context, _err(e));
      return false;
    }
  }

  // ── تعديل خانة نص ──────────────────────────────────────────────────────────
  Future<void> _editText(String key, String title, {int max = 50, String? hint, bool ltr = false}) async {
    final ctrl = TextEditingController(text: _s(key) ?? '');
    final ok = await _sheet(title, [
      TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: max,
        textDirection: ltr ? TextDirection.ltr : null,
        style: const TextStyle(color: SC.text, fontSize: 14),
        decoration: _input(hint),
      ),
    ]);
    if (ok != true) return;
    var v = ctrl.text.trim();
    if (key == 'username') v = v.toLowerCase();
    if (v == (_s(key) ?? '')) return;
    await _save({key: v});
  }

  InputDecoration _input(String? hint) => InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF777D8A)),
        filled: true,
        fillColor: SC.chip,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF41444F))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: SC.accent)),
      );

  Future<bool?> _sheet(String title, List<Widget> body, {String? saveLabel}) => showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: SC.card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => Directionality(
          textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18,
                18 + MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(title, style: const TextStyle(color: SC.text, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              ...body,
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                SBtn(_t('Cancel', 'إلغاء'), onTap: () => Navigator.of(ctx).pop(false)),
                const SizedBox(width: 10),
                SBtn(saveLabel ?? _t('Save', 'حفظ'), primary: true, onTap: () => Navigator.of(ctx).pop(true)),
              ]),
            ]),
          ),
        ),
      );

  // ── تاريخ الميلاد ──────────────────────────────────────────────────────────
  Future<void> _editBirth() async {
    final now = DateTime.now();
    final cur = DateTime.tryParse(_s('birth_date') ?? '');
    final last = DateTime(now.year - 13, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: cur ?? DateTime(now.year - 20),
      firstDate: DateTime(1920),
      lastDate: last,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: SC.accent, surface: SC.card),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final v = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    await _save({'birth_date': v});
  }

  // ── النوع ──────────────────────────────────────────────────────────────────
  Future<void> _editGender() async {
    var g = _s('gender') ?? '';
    final ok = await _sheet(_t('Gender', 'النوع'), [
      StatefulBuilder(builder: (ctx, setS) => Row(children: [
        for (final o in [('male', _t('Male', 'ذكر')), ('female', _t('Female', 'أنثى'))]) ...[
          Expanded(child: GestureDetector(
            onTap: () => setS(() => g = o.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: g == o.$1 ? SC.accent.withOpacity(0.12) : SC.chip,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: g == o.$1 ? SC.accent : const Color(0xFF41444F)),
              ),
              child: Text(o.$2, textAlign: TextAlign.center,
                  style: TextStyle(color: SC.text, fontSize: 14,
                      fontWeight: g == o.$1 ? FontWeight.w800 : FontWeight.w600)),
            ),
          )),
          if (o.$1 == 'male') const SizedBox(width: 10),
        ],
      ])),
    ]);
    if (ok == true && g.isNotEmpty && g != (_s('gender') ?? '')) await _save({'gender': g});
  }

  // ── المكان بالـ GPS ────────────────────────────────────────────────────────
  Future<void> _updateLocation() async {
    setState(() => _locBusy = true);
    final r = await captureVerifiedLocation(context);
    if (!mounted) return;
    setState(() => _locBusy = false);
    if (r != null) {
      await _load();
      if (mounted) sToast(context, _t('Location updated ✓', 'مكانك اتحدّث ✓'));
    }
  }

  // ── اللغة ──────────────────────────────────────────────────────────────────
  Future<void> _setLang(String lang) async {
    if ((lang == 'ar') == _ar) return;
    AppLang.set(lang);
    await LocalStore.setLang(lang);
    if (mounted) setState(() {});
  }

  // ── مسح الحساب ─────────────────────────────────────────────────────────────
  static const _reasons = [
    ('not_using', 'I don\'t use the app', 'مش بستخدم التطبيق'),
    ('privacy', 'Privacy concerns', 'قلقان على خصوصيتي'),
    ('another_account', 'I have another account', 'عندي حساب تاني'),
    ('other', 'Another reason', 'سبب تاني'),
  ];

  Future<void> _deleteAccount() async {
    String? reason;
    final ok = await _sheet(_t('Delete your account?', 'تمسح حسابك؟'), [
      SBullets([
        _t('Your account will be deleted permanently after 30 days.',
            'حسابك هيتمسح نهائي بعد 30 يوم.'),
        _t('This includes your profile, photos, moments, fantasy squads and points.',
            'ده يشمل البروفايل والصور والمومنتس وتشكيلات الفانتازي والنقط.'),
        _t('Changed your mind? Just log in again within 30 days and the request is cancelled.',
            'غيّرت رأيك؟ ادخل تاني في خلال الـ 30 يوم والطلب هيتلغي.'),
      ], color: const Color(0xFFD4D7DF), size: 13),
      const SizedBox(height: 14),
      Text(_t('Why are you leaving? (optional)', 'ليه عايز تمشي؟ (اختياري)'),
          style: const TextStyle(color: SC.muted, fontSize: 12)),
      const SizedBox(height: 8),
      StatefulBuilder(builder: (ctx, setS) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final r in _reasons)
          GestureDetector(
            onTap: () => setS(() => reason = reason == r.$1 ? null : r.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: reason == r.$1 ? SC.danger.withOpacity(0.14) : SC.chip,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: reason == r.$1 ? SC.danger : const Color(0xFF41444F)),
              ),
              child: Text(_ar ? r.$3 : r.$2, style: const TextStyle(color: SC.text, fontSize: 12.5)),
            ),
          ),
      ])),
    ], saveLabel: _t('Continue', 'كمّل'));
    if (ok != true || !mounted) return;

    final sure = await sInfo(context,
        title: _t('Are you sure?', 'متأكد؟'),
        icon: Icons.delete_outline_rounded,
        body: [_t('You will be logged out now. Your account will be deleted after 30 days unless you log in again.',
                  'هيتعمل لك تسجيل خروج دلوقتي، وحسابك هيتمسح بعد 30 يوم إلا لو دخلت تاني.')],
        confirm: _t('Delete my account', 'امسح حسابي'),
        danger: true);
    if (sure != true || !mounted) return;

    try {
      await _sb.rpc('account_request_deletion', params: {'p_reason': reason});
    } catch (e) {
      debugPrint('account_request_deletion error: $e');
      if (mounted) sToast(context, _err(e));
      return;
    }
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

  Future<void> _cancelDeletion() async {
    try {
      await _sb.rpc('account_cancel_deletion');
      await _load();
      if (mounted) sToast(context, _t('Deletion cancelled ✓', 'طلب المسح اتلغى ✓'));
    } catch (e) {
      if (mounted) sToast(context, _err(e));
    }
  }

  // ── عرض ────────────────────────────────────────────────────────────────────
  String _date(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '—';
    const en = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const ar = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return _ar ? '${d.day} ${ar[d.month - 1]} ${d.year}' : '${d.day} ${en[d.month - 1]} ${d.year}';
  }

  Widget _row(String title, String? value, {VoidCallback? onEdit, String? button}) => SRow(
        title: title,
        value: value ?? _t('Not set', 'مش متحدد'),
        valueMuted: value == null,
        trailing: onEdit == null ? null : SBtn(button ?? _t('Edit', 'تعديل'), onTap: onEdit),
        onTap: onEdit,
      );

  Widget _langSeg() => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: SC.chip, borderRadius: BorderRadius.circular(11)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final o in [('ar', 'عربي'), ('en', 'English')])
            GestureDetector(
              onTap: () => _setLang(o.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: (o.$1 == 'ar') == _ar ? SC.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(o.$2, style: TextStyle(color: SC.text, fontSize: 12.5,
                    fontWeight: (o.$1 == 'ar') == _ar ? FontWeight.w800 : FontWeight.w600)),
              ),
            ),
        ]),
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
                      Text(_t("Couldn't load your account.", 'مقدرناش نحمّل بيانات حسابك.'),
                          style: const TextStyle(color: SC.muted, fontSize: 14)),
                      const SizedBox(height: 12),
                      SBtn(_t('Try again', 'جرّب تاني'), onTap: _load),
                    ])))
                : _page(),
      );

  Widget _page() {
    final gender = _s('gender');
    final place = [_s('city'), _s('governorate')].whereType<String>().join('، ');
    final deletion = _d?['deletion'] is Map ? Map<String, dynamic>.from(_d!['deletion'] as Map) : null;
    final email = _s('email');
    final phone = _s('phone');

    return SPage(
      title: _t('Account Settings', 'إعدادات الحساب'),
      subtitle: _t('Your account information and preferences.', 'بيانات حسابك وتفضيلاتك.'),
      bottomText: 'BDGR · ${_t('Account Settings', 'إعدادات الحساب')}',
      children: [
        if (deletion != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: SNotice(
              color: SC.danger,
              icon: Icons.schedule_rounded,
              title: _t('Your account is scheduled for deletion', 'حسابك هيتمسح'),
              text: _t('On ${_date(deletion['delete_after']?.toString())}. Cancel if you want to keep it.',
                  'يوم ${_date(deletion['delete_after']?.toString())}. الغي الطلب لو عايز تحتفظ بيه.'),
            ),
          ),
        SSection(
          icon: Icons.person_outline_rounded,
          title: _t('Account Information', 'معلومات الحساب'),
          children: [SCard(children: [
            _row(_t('Full Name', 'الاسم الكامل'), _s('full_name'),
                onEdit: () => _editText('full_name', _t('Full Name', 'الاسم الكامل'), max: 100)),
            _row(_t('Display Name', 'اسم العرض'), _s('display_name'),
                onEdit: () => _editText('display_name', _t('Display Name', 'اسم العرض'))),
            _row(_t('Username', 'اليوزرنيم'), _s('username') == null ? null : '@${_s('username')}',
                onEdit: () => _editText('username', _t('Username', 'اليوزرنيم'), max: 30, hint: 'username', ltr: true)),
            _row(_t('Phone Number', 'رقم الموبايل'), phone,
                button: _t('Manage', 'إدارة'),
                onEdit: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LoginSecurityPage()))),
            if (email != null) _row(_t('Email', 'الإيميل'), email),
          ])],
        ),
        SSection(
          icon: Icons.calendar_month_outlined,
          title: _t('Personal Details', 'بيانات شخصية'),
          children: [SCard(children: [
            _row(_t('Date of Birth', 'تاريخ الميلاد'), _s('birth_date') == null ? null : _date(_s('birth_date')),
                onEdit: _editBirth),
            _row(_t('Gender', 'النوع'),
                gender == null ? null : gender == 'male' ? _t('Male', 'ذكر') : _t('Female', 'أنثى'),
                onEdit: _editGender),
          ])],
        ),
        SSection(
          icon: Icons.location_on_outlined,
          title: _t('Your Location', 'مكانك'),
          description: _t('Taken from your phone GPS only. Used for your governorate and city rankings.',
              'بيتاخد من الـ GPS بتاع موبايلك بس، وبيتحسب بيه ترتيب محافظتك ومدينتك.'),
          children: [SCard(children: [
            SRow(
              title: _t('Governorate / City', 'المحافظة / المدينة'),
              value: place.isEmpty ? _t('Not set yet', 'لسه مش متحدد') : place,
              valueMuted: place.isEmpty,
              trailing: _locBusy
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: SC.accent, strokeWidth: 2))
                  : SBtn(_t('Update', 'حدّث'), icon: Icons.my_location_rounded, onTap: _updateLocation),
            ),
          ])],
        ),
        SSection(
          icon: Icons.translate_rounded,
          title: _t('Language', 'اللغة'),
          children: [SCard(children: [
            SRow(title: _t('App language', 'لغة التطبيق'), trailing: _langSeg()),
          ])],
        ),
        SSection(
          icon: Icons.verified_user_outlined,
          title: _t('Account Status', 'حالة الحساب'),
          children: [SCard(children: [
            SRow(
              title: _t('Status', 'الحالة'),
              below: Align(
                alignment: AlignmentDirectional.centerStart,
                child: deletion == null
                    ? SPill(_t('Active', 'نشط'), color: SC.success)
                    : SPill(_t('Deletion requested', 'مطلوب مسحه'), color: SC.danger),
              ),
              trailing: deletion == null ? null : SBtn(_t('Cancel request', 'الغي الطلب'), onTap: _cancelDeletion),
            ),
            _row(_t('Member Since', 'عضو من'), _date(_s('member_since'))),
          ])],
        ),
        if (deletion == null)
          SSection(
            icon: Icons.delete_outline_rounded,
            title: _t('Delete Account', 'مسح الحساب'),
            children: [SCard(children: [
              SRow(
                title: _t('Delete my account', 'امسح حسابي'),
                desc: _t('Deleted after 30 days. Log in again within 30 days to cancel.',
                    'بيتمسح بعد 30 يوم. لو دخلت تاني في خلالهم الطلب بيتلغي.'),
                trailing: SBtn(_t('Delete', 'مسح'), danger: true, onTap: _deleteAccount),
              ),
            ])],
          ),
      ],
    );
  }
}
