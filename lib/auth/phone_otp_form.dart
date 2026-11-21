import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_config.dart';
import '../local_store.dart';
import 'login_config.dart';

// ======================================================================
// نموذج بيانات الدول
// ======================================================================
class _Country {
  const _Country({
    required this.flag,
    required this.name,
    required this.dialCode,
    required this.minDigits,
    required this.maxDigits,
    this.validate,
  });

  final String flag;
  final String name;
  final String dialCode;
  final int    minDigits;
  final int    maxDigits;

  /// تحقق إضافي من شكل الرقم (بعد حذف الكود)
  final String? Function(String local)? validate;
}

const List<_Country> _countries = [
  _Country(
    flag: '🇪🇬', name: 'Egypt', dialCode: '+20',
    minDigits: 10, maxDigits: 11,
    validate: _validateEgypt,
  ),
  _Country(
    flag: '🇸🇦', name: 'Saudi Arabia', dialCode: '+966',
    minDigits: 9, maxDigits: 9,
    validate: _validateSaudi,
  ),
  _Country(
    flag: '🇦🇪', name: 'UAE', dialCode: '+971',
    minDigits: 9, maxDigits: 9,
    validate: _validateUAE,
  ),
];

String? _validateEgypt(String local) {
  if (!RegExp(r'^01[0125][0-9]{8}$').hasMatch(local)) {
    return 'Enter a valid Egyptian number (01x XXXXXXXX)';
  }
  return null;
}

String? _validateSaudi(String local) {
  if (!RegExp(r'^0?5[0-9]{8}$').hasMatch(local)) {
    return 'Enter a valid Saudi number (05x XXXXXXXX)';
  }
  return null;
}

String? _validateUAE(String local) {
  if (!RegExp(r'^0?5[0-9]{8}$').hasMatch(local)) {
    return 'Enter a valid UAE number (05x XXXXXXXX)';
  }
  return null;
}

// ======================================================================
// الفورم الرئيسي
// ======================================================================

/// فورم الدخول برقم الموبايل: الرقم ← OTP ← تأكيد.
/// لما الكود يطلع صح بينادي onVerified بالجلسة.
class PhoneOtpForm extends StatefulWidget {
  const PhoneOtpForm({
    super.key,
    required this.isArabic,
    required this.onVerified,
  });

  final bool                            isArabic;
  final void Function(Session session) onVerified;

  @override
  State<PhoneOtpForm> createState() => _PhoneOtpFormState();
}

class _PhoneOtpFormState extends State<PhoneOtpForm> {
  static const Color _green   = Color(0xFF00FF87);
  static const Color _dark    = Color(0xFF0B0B0F);
  static const Color _warn    = Color(0xFFFFCC80);
  static const Color _errRed  = Color(0xFFFF5C5C);

  final _phoneCtrl = TextEditingController();
  final _otpCtrl   = TextEditingController();

  _Country _country       = _countries.first;
  bool     _termsAccepted = false;
  bool     _marketingAccepted = false;
  bool     _otpStep       = false;
  bool     _busy          = false;
  String?  _error;
  String?  _devOtp;
  String   _sentTo        = '';
  String?  _lastTried;

  bool get _ar => widget.isArabic;

  // ---- validation ----

  // neutral hint = لا تحذير ولا خطأ
  String get _neutralHint => _ar ? 'أدخل رقم الموبايل' : 'Enter your mobile number';

  /// نوع الـ hint: null = neutral, true = valid, false = error
  ({String text, bool? state}) get _phoneHintInfo {
    final t = _phoneCtrl.text;
    final c = _country;

    if (t.isEmpty) return (text: _neutralHint, state: null);

    // مصر
    if (c.dialCode == '+20') {
      if (t.length >= 1 && t[0] != '0')
        return (text: _ar ? 'يبدأ بـ 0' : 'Must start with 0', state: false);
      if (t.length >= 2 && t[1] != '1')
        return (text: _ar ? 'يبدأ بـ 01' : 'Must start with 01', state: false);
      if (t.length >= 3 && !['0','1','2','5'].contains(t[2]))
        return (text: _ar ? 'الرقم الثالث 0 أو 1 أو 2 أو 5' : 'Third digit: 0, 1, 2, or 5', state: false);
      if (t.length >= 3 && t.length < c.minDigits)
        return (text: _neutralHint, state: null);
    } else {
      // السعودية والإمارات
      if (t.length >= 1 && t[0] != '0')
        return (text: _ar ? 'يبدأ بـ 0' : 'Must start with 0', state: false);
      if (t.length >= 2 && t[1] != '5')
        return (text: _ar ? 'يبدأ بـ 05' : 'Must start with 05', state: false);
      if (t.length >= 2 && t.length < c.minDigits)
        return (text: _neutralHint, state: null);
    }

    if (t.length > c.maxDigits)
      return (text: _ar ? 'الرقم طويل جدًا' : 'Number too long', state: false);

    final err = c.validate?.call(t);
    if (t.length == c.maxDigits && err != null)
      return (text: err, state: false);
    if (t.length == c.maxDigits && err == null)
      return (text: _ar ? 'الرقم صحيح ✓' : 'Valid ✓', state: true);

    return (text: _neutralHint, state: null);
  }

  String get _phoneHint => _phoneHintInfo.text;

  bool get _phoneValid {
    final t = _phoneCtrl.text;
    final c = _country;
    if (t.length < c.minDigits || t.length > c.maxDigits) return false;
    return c.validate?.call(t) == null;
  }

  bool get _canSend => _phoneValid && _termsAccepted;

  // e.164 from local
  String _e164(String local) {
    // أزل أي صفر في الأول لو الكود بيتكرر (مثلًا 0566… في السعودية → 566…)
    final clean = local.replaceFirst(RegExp(r'^0+'), '');
    return '${_country.dialCode}$clean';
  }

  // ---- listeners ----

  @override
  void initState() {
    super.initState();
    _phoneCtrl.addListener(_onPhoneChanged);
    _otpCtrl.addListener(_onOtpChanged);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _onPhoneChanged() => setState(() => _error = null);

  void _onOtpChanged() {
    if (_otpCtrl.text.length < 6) _lastTried = null;
    if (_otpCtrl.text != _lastTried && _error != null) {
      setState(() => _error = null);
    } else {
      setState(() {});
    }
    if (_otpCtrl.text.length == 6 &&
        _otpCtrl.text != _lastTried &&
        !_busy) {
      _lastTried = _otpCtrl.text;
      _verify();
    }
  }

  // ---- send code ----

  Future<void> _sendCode() async {
    if (!_canSend || _busy) return;

    setState(() { _busy = true; _error = null; });

    try {
      await LocalStore.setPendingConsents(
        terms:     _termsAccepted,
        marketing: _marketingAccepted,
      );

      final phone = _e164(_phoneCtrl.text);
      await supa.auth.signInWithOtp(phone: phone);

      String? devOtp;
      if (AppConfig.devMode) {
        try {
          final res = await supa.rpc(
            'dev_get_otp',
            params: {'p_phone': phone},
          );
          if (res is String && res.isNotEmpty) devOtp = res;
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _otpStep = true;
        _sentTo  = _phoneCtrl.text;
        _devOtp  = devOtp;
        _lastTried = null;
        _otpCtrl.clear();
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _sendErrorText(e.message));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = _genericError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _sendErrorText(String msg) {
    if (msg.toLowerCase().contains('rate')) {
      return _ar ? 'استنى شوية قبل الطلب التالي' : 'Wait a moment before retrying';
    }
    return _genericError;
  }

  String get _genericError =>
      _ar ? 'حصل خطأ، حاول تاني' : 'Something went wrong, please try again';

  // ---- verify ----

  Future<void> _verify() async {
    if (_otpCtrl.text.length != 6 || _busy) return;

    setState(() { _busy = true; _error = null; });

    try {
      final phone = _e164(_sentTo);
      final res   = await supa.auth.verifyOTP(
        type:  OtpType.sms,
        phone: phone,
        token: _otpCtrl.text,
      );

      final session = res.session;
      if (session == null) throw const AuthException('no_session');

      if (mounted) widget.onVerified(session);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy  = false;
        _error = _ar ? 'الكود غلط أو منتهي' : 'Incorrect or expired code';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _busy = false; _error = _genericError; });
    }
  }

  void _changeNumber() => setState(() {
    _otpStep = false;
    _devOtp  = null;
    _error   = null;
    _lastTried = null;
    _otpCtrl.clear();
  });

  // ---- UI helpers ----

  BoxDecoration get _box => BoxDecoration(
    color: const Color(0x1AFFFFFF),
    border: Border.all(color: const Color(0x33FFFFFF)),
    borderRadius: BorderRadius.circular(14),
    boxShadow: const [
      BoxShadow(color: Color(0x4D000000), blurRadius: 15, offset: Offset(0, 4)),
    ],
  );

  Widget _line(String text, Color color) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Text(text, style: TextStyle(color: color, fontSize: 12)),
  );

  Widget _mainButton({
    required String     label,
    required bool       enabled,
    required VoidCallback onPressed,
  }) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding:              const EdgeInsets.symmetric(vertical: 15),
        backgroundColor:      _green,
        disabledBackgroundColor: const Color(0x4000FF87),
        foregroundColor:      _dark,
        disabledForegroundColor: const Color(0x73FFFFFF),
        elevation:            enabled ? 6 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: enabled && !_busy ? onPressed : null,
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
  );

  // ---- country picker ----

  Widget _countryPicker() => GestureDetector(
    onTap: _pickCountry,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.white.withAlpha(38))),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_country.flag, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Text(
            _country.dialCode,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 18),
        ],
      ),
    ),
  );

  Future<void> _pickCountry() async {
    final chosen = await showModalBottomSheet<_Country>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => ListView.separated(
        shrinkWrap: true,
        itemCount: _countries.length,
        separatorBuilder: (_, __) => Divider(
          color: Colors.white.withAlpha(20),
          height: 1,
        ),
        itemBuilder: (ctx, i) {
          final c = _countries[i];
          return ListTile(
            leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
            title: Text(c.name, style: const TextStyle(color: Colors.white)),
            trailing: Text(
              c.dialCode,
              style: const TextStyle(color: Colors.white54),
            ),
            onTap: () => Navigator.of(ctx).pop(c),
          );
        },
      ),
    );

    if (chosen != null) {
      setState(() {
        _country = chosen;
        _phoneCtrl.clear();
        _error = null;
      });
    }
  }

  // ---- phone field ----

  Widget _phoneFieldInner() => Directionality(
    textDirection: TextDirection.ltr,
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        border: Border.all(color: const Color(0x1AFFFFFF)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _countryPicker(),
          Expanded(
            child: TextField(
              controller: _phoneCtrl,
              enabled: !_busy,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_country.maxDigits),
              ],
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: _country == _countries[0] ? '01XXXXXXXXX' : '0XXXXXXXXX',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (_) => _sendCode(),
            ),
          ),
        ],
      ),
    ),
  );

  // ---- OTP field ----

  Widget _otpField() => Directionality(
    textDirection: TextDirection.ltr,
    child: Container(
      decoration: _box,
      child: TextField(
        controller: _otpCtrl,
        enabled: !_busy,
        autofocus: true,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          letterSpacing: 10,
          fontWeight: FontWeight.bold,
        ),
        decoration: const InputDecoration(
          hintText: '••••••',
          hintStyle: TextStyle(color: Colors.white38, letterSpacing: 10),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
        onSubmitted: (_) => _verify(),
      ),
    ),
  );

  Widget _devOtpBanner() => GestureDetector(
    onTap: () => _otpCtrl.text = _devOtp!,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x33FFCC80),
        border: Border.all(color: const Color(0x80FFCC80)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _ar ? 'كود التجربة: $_devOtp  (دوس للصق)' : 'Test code: $_devOtp  (tap to fill)',
        textAlign: TextAlign.center,
        style: const TextStyle(color: _warn, fontSize: 14, fontWeight: FontWeight.bold),
      ),
    ),
  );

  Future<void> _openTerms() async {
    try {
      await launchUrl(
        Uri.parse(LoginConfig.termsUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  Widget _checkRow({
    required bool          value,
    required ValueChanged<bool> onChanged,
    required String        text,
    String?                linkText,
    VoidCallback?          onLinkTap,
  }) {
    const style = TextStyle(color: Colors.white, fontSize: 14, height: 1.5);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: value,
            activeColor: _green,
            checkColor: _dark,
            side: const BorderSide(color: Colors.white54),
            onChanged: _busy ? null : (v) => onChanged(v ?? false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            children: [
              GestureDetector(
                onTap: _busy ? null : () => onChanged(!value),
                child: Text(text, style: style),
              ),
              if (linkText != null)
                GestureDetector(
                  onTap: onLinkTap,
                  child: Text(linkText, style: style.copyWith(color: _green)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _consentsInner() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
        _checkRow(
          value:     _termsAccepted,
          onChanged: (v) => setState(() => _termsAccepted = v),
          text:      _ar ? 'عندي 13 سنة أو أكتر، وأوافق على ' : "I'm 13 or older and agree to the ",
          linkText:  _ar ? 'الشروط وسياسة الخصوصية' : 'Terms & Privacy Policy',
          onLinkTap: _openTerms,
        ),
        const SizedBox(height: 12),
        _checkRow(
          value:     _marketingAccepted,
          onChanged: (v) => setState(() => _marketingAccepted = v),
          text:      _ar
              ? 'أوافق على استقبال عروض وأحداث (اختياري)'
              : 'I\'d like to receive offers & events (optional)',
        ),
    ],
  );

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    if (!_otpStep) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: _box,
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _phoneFieldInner(),
                const SizedBox(height: 8),
                _line(
                  _phoneHint,
                  _phoneHintInfo.state == true
                      ? _green
                      : _phoneHintInfo.state == false
                          ? _errRed
                          : Colors.white38,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  _line(_error!, _errRed),
                ],
                const Divider(color: Color(0x14FFFFFF), height: 28),
                _consentsInner(),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _mainButton(
            label:     _busy
                ? (_ar ? 'جاري الإرسال…' : 'Sending…')
                : (_ar ? 'ابعت الكود' : 'Send code'),
            enabled:   _canSend,
            onPressed: _sendCode,
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _line(
          _ar ? 'اكتب الكود اللي اتبعت لـ $_sentTo' : 'Enter the code sent to $_sentTo',
          const Color(0xFFDDDDDD),
        ),
        const SizedBox(height: 10),
        if (AppConfig.devMode && _devOtp != null) ...[
          _devOtpBanner(),
          const SizedBox(height: 10),
        ],
        _otpField(),
        if (_error != null) ...[
          const SizedBox(height: 8),
          _line(_error!, _errRed),
        ],
        const SizedBox(height: 20),
        _mainButton(
          label:     _busy
              ? (_ar ? 'جاري التأكيد…' : 'Verifying…')
              : (_ar ? 'تأكيد' : 'Verify'),
          enabled:   _otpCtrl.text.length == 6,
          onPressed: _verify,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _busy ? null : _changeNumber,
              child: Text(
                _ar ? 'تغيير الرقم' : 'Change number',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : _sendCode,
              child: Text(
                _ar ? 'ابعت الكود تاني' : 'Resend code',
                style: const TextStyle(color: _green, fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
