import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_config.dart';
import '../app_lang.dart';
import '../brand.dart';
import '../device_telemetry.dart';
import '../official_account.dart';
import 'settings_ui.dart';

/// المساعدة والدعم: أسئلة شائعة حقيقية + رسايل دعم بتتحفظ (support_*) + واتساب.
/// الردود بتيجي من لوحة التحكم (قسم 🎧 الدعم) وبتظهر باسم BDGR.
class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _Faq {
  const _Faq(this.cat, this.qEn, this.qAr, this.aEn, this.aAr);
  final String cat, qEn, qAr, aEn, aAr;
}

const _faqs = <_Faq>[
  _Faq('account', "I didn't get the login code", 'الكود ما وصلنيش',
      'Check that your number is correct, wait a minute, then tap resend. Still nothing? Message us on WhatsApp.',
      'اتأكد إن الرقم صح، واستنى دقيقة ودوس "ابعت تاني". لسه ما وصلش؟ كلمنا واتساب.'),
  _Faq('account', 'I want to change my phone number', 'عايز أغيّر رقم موبايلي',
      "Changing the number isn't available in the app yet. Send us a message from Contact Support or WhatsApp and we'll help you.",
      'تغيير الرقم لسه مش متاح من التطبيق. ابعتلنا من "كلّم الدعم" أو واتساب وهنساعدك.'),
  _Faq('account', 'How do I edit my profile?', 'إزاي أعدّل بروفايلي؟',
      'Open the Profile tab and tap Edit. Your name, username and birth date are also in Account Settings.',
      'افتح تاب البروفايل ودوس "تعديل". الاسم واليوزرنيم وتاريخ الميلاد موجودين كمان في إعدادات الحساب.'),
  _Faq('account', 'How do I delete my account?', 'إزاي أمسح حسابي؟',
      'Account Settings → Delete my account. It is deleted after 30 days. Log in again within 30 days to cancel.',
      'إعدادات الحساب ← امسح حسابي. بيتمسح بعد 30 يوم، ولو دخلت تاني في خلالهم الطلب بيتلغي.'),
  _Faq('fantasy', 'How do I play Fantasy?', 'إزاي ألعب فانتازي؟',
      'Pick 11 players within the round budget, choose a captain (captain points count double), and save before the deadline.',
      'اختار 11 لاعب في حدود ميزانية الجولة، واختار كابتن (نقطه بتتحسب ×2)، واحفظ قبل الديدلاين.'),
  _Faq('fantasy', 'When is the deadline?', 'الديدلاين إمتى؟',
      'Squads lock 3 hours before the first match of the round. The countdown is on Home and in Fantasy.',
      'التشكيلة بتقفل قبل أول ماتش في الجولة بـ 3 ساعات. العداد ظاهر في الهوم وفي الفانتازي.'),
  _Faq('fantasy', 'A player price changed. Does it affect me?', 'سعر لاعب اتغير، ده بيأثر عليّا؟',
      'Prices can change between rounds, but players already in your squad keep the price you paid.',
      'الأسعار ممكن تتغير بين الجولات، بس اللاعيبة اللي في تشكيلتك بيفضلوا بالسعر اللي اشتريتهم بيه.'),
  _Faq('fantasy', 'How do I create or join a league?', 'إزاي أعمل دوري أو أدخل دوري؟',
      'Fantasy → Leagues: create a league and share its code, or tap "Join with code".',
      'الفانتازي ← الدوريات: اعمل دوري وابعت الكود لصحابك، أو دوس "ادخل بكود".'),
  _Faq('fantasy', 'How is my governorate ranking decided?', 'ترتيب المحافظة بيتحسب إزاي؟',
      'From your real location (GPS). You can update it from Account Settings → Your Location.',
      'من مكانك الحقيقي بالـ GPS. تقدر تحدّثه من إعدادات الحساب ← مكانك.'),
  _Faq('safety', 'How do I block or report someone?', 'إزاي أعمل بلوك أو أبلّغ عن حد؟',
      "Open their profile and tap ⋯ → Block. To report a moment, use the report button on it. Your blocked list is in Privacy.",
      'افتح بروفايله ودوس ⋯ ← بلوك. ولو عايز تبلّغ عن مومنت، استخدم زرار البلاغ اللي عليه. الحسابات اللي عامل لها بلوك في صفحة الخصوصية.'),
  _Faq('safety', 'Someone asked me for my code', 'حد طلب مني الكود',
      'Never share it, even if they say they are from BDGR. BDGR will never ask for your code.',
      'ماتديهوش لأي حد، حتى لو قال إنه من BDGR. BDGR عمره ما هيطلب منك الكود.'),
  _Faq('app', "A video or page isn't loading", 'فيديو أو صفحة مش بتفتح',
      'Check your internet, then App Preferences → Clear temporary files. Still happening? Report a problem.',
      'اتأكد من النت، وبعدين تفضيلات التطبيق ← امسح الملفات المؤقتة. لسه؟ بلّغ عن مشكلة.'),
];

const _cats = <(String, String, String)>[
  ('all', 'All', 'الكل'),
  ('account', 'Account', 'الحساب'),
  ('fantasy', 'Fantasy', 'الفانتازي'),
  ('safety', 'Safety', 'الأمان'),
  ('app', 'App', 'التطبيق'),
];

const _formCats = <(String, String, String)>[
  ('account', 'Account & login', 'الحساب والدخول'),
  ('fantasy', 'Fantasy', 'الفانتازي'),
  ('competitions', 'Competitions', 'المسابقات'),
  ('profile', 'Profile', 'البروفايل'),
  ('technical', 'Something is broken', 'حاجة مش شغالة'),
  ('other', 'Other', 'حاجة تانية'),
];

String _statusLabel(String? s) => switch (s) {
      'resolved' => AppLang.t('Resolved', 'اتحلت'),
      'seen' => AppLang.t('We are on it', 'بنشوفها'),
      _ => AppLang.t('Sent', 'اتبعتت'),
    };

Color _statusColor(String? s) => switch (s) {
      'resolved' => SC.success,
      'seen' => SC.warning,
      _ => SC.muted,
    };

String _when(String? iso) {
  final d = DateTime.tryParse(iso ?? '')?.toLocal();
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 2) return AppLang.t('now', 'دلوقتي');
  if (diff.inHours < 1) return AppLang.t('${diff.inMinutes} min', '${diff.inMinutes} د');
  if (diff.inDays < 1) return AppLang.t('${diff.inHours} h', '${diff.inHours} س');
  return '${d.day}/${d.month}/${d.year}';
}

/// بيفتح محادثة دعم بعينها (من إشعار "BDGR رد عليك").
Route<void> supportThreadRoute(int ticketId) =>
    MaterialPageRoute<void>(builder: (_) => _ThreadPage(ticketId: ticketId));

class _HelpSupportPageState extends State<HelpSupportPage> {
  final _sb = Supabase.instance.client;
  final _search = TextEditingController();
  String _cat = 'all';
  int? _open;
  String? _whatsapp;
  int _unread = 0;

  bool get _ar => AppLang.isArabic;
  String _t(String en, String ar) => AppLang.t(en, ar);

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadInfo() async {
    try {
      final res = await _sb.rpc('support_info');
      if (!mounted || res is! Map) return;
      setState(() {
        final w = (res['whatsapp'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
        _whatsapp = w.isEmpty ? null : w;
        _unread = (res['unread'] as num?)?.toInt() ?? 0;
      });
    } catch (e) {
      debugPrint('support_info error: $e');
    }
  }

  Future<void> _openWhatsapp() async {
    final n = _whatsapp;
    if (n == null) return;
    final msg = Uri.encodeComponent(_t('Hi BDGR, I need help with: ', 'أهلاً BDGR، محتاج مساعدة في: '));
    final ok = await launchUrl(Uri.parse('https://wa.me/$n?text=$msg'), mode: LaunchMode.externalApplication)
        .catchError((_) => false);
    if (!ok && mounted) sToast(context, _t("Couldn't open WhatsApp.", 'مقدرناش نفتح واتساب.'));
  }

  Future<void> _openForm(bool problem) async {
    final sent = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => _SupportFormPage(problem: problem)));
    if (sent == true && mounted) {
      sToast(context, _t('Sent ✓ We will reply here soon.', 'اتبعتت ✓ هنرد عليك هنا قريب.'));
      _loadInfo();
    }
  }

  Future<void> _openMine() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const _MyRequestsPage()));
    _loadInfo();
  }

  List<_Faq> get _visible {
    final q = _search.text.trim().toLowerCase();
    return _faqs.where((f) {
      if (_cat != 'all' && f.cat != _cat) return false;
      if (q.isEmpty) return true;
      return '${f.qEn} ${f.qAr} ${f.aEn} ${f.aAr}'.toLowerCase().contains(q);
    }).toList();
  }

  Widget _quick(IconData icon, String title, String desc, VoidCallback onTap, {Widget? badge}) => SRow(
        icon: icon, title: title, desc: desc, onTap: onTap,
        trailing: badge ?? Icon(_ar ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: SC.muted),
      );

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Directionality(
      textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
      child: SPage(
        title: _t('Help & Support', 'المساعدة والدعم'),
        subtitle: _t('Answers, and a way to reach us.', 'إجابات، وطريقة توصل لنا.'),
        bottomText: 'BDGR · ${AppConfig.appVersion}',
        children: [
          SSection(
            icon: Icons.support_agent_rounded,
            title: _t('Talk to us', 'كلمنا'),
            children: [SCard(children: [
              _quick(Icons.chat_bubble_outline_rounded, _t('Contact support', 'كلّم الدعم'),
                  _t('Ask a question about your account or the app.', 'اسأل عن حسابك أو التطبيق.'), () => _openForm(false)),
              _quick(Icons.bug_report_outlined, _t('Report a problem', 'بلّغ عن مشكلة'),
                  _t("Something isn't working? Tell us.", 'حاجة مش شغالة؟ قولنا.'), () => _openForm(true)),
              _quick(Icons.inbox_outlined, _t('My requests', 'طلباتي'),
                  _t('Your messages and our replies.', 'رسايلك وردودنا عليها.'), _openMine,
                  badge: _unread > 0 ? SPill(_t('$_unread new', '$_unread جديد'), color: SC.accent) : null),
              if (_whatsapp != null)
                _quick(Icons.chat_rounded, _t('WhatsApp', 'كلمنا واتساب'),
                    _t('Chat with the BDGR team.', 'اتكلم مع فريق BDGR.'), _openWhatsapp),
            ])],
          ),
          SSection(
            icon: Icons.help_outline_rounded,
            title: _t('Common questions', 'أسئلة شائعة'),
            children: [
              TextField(
                controller: _search,
                onChanged: (_) => setState(() => _open = null),
                style: const TextStyle(color: SC.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: _t('Search questions…', 'دوّر في الأسئلة…'),
                  hintStyle: const TextStyle(color: Color(0xFF777D8A)),
                  prefixIcon: const Icon(Icons.search_rounded, color: SC.muted),
                  filled: true, fillColor: SC.card, isDense: true,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SC.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SC.accent)),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final c in _cats)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: GestureDetector(
                        onTap: () => setState(() { _cat = c.$1; _open = null; }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                          decoration: BoxDecoration(
                            color: _cat == c.$1 ? SC.accent.withOpacity(0.14) : SC.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _cat == c.$1 ? SC.accent : SC.border),
                          ),
                          child: Text(_ar ? c.$3 : c.$2, style: TextStyle(color: SC.text, fontSize: 12.5,
                              fontWeight: _cat == c.$1 ? FontWeight.w800 : FontWeight.w600)),
                        ),
                      ),
                    ),
                ]),
              ),
              SCard(children: [
                if (visible.isEmpty)
                  SRow(title: _t('No matching questions. Contact support instead.', 'مفيش سؤال زي ده. كلّم الدعم.'))
                else
                  for (var i = 0; i < visible.length; i++)
                    InkWell(
                      onTap: () => setState(() => _open = _open == i ? null : i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(_ar ? visible[i].qAr : visible[i].qEn,
                                style: const TextStyle(color: SC.text, fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.4))),
                            Icon(_open == i ? Icons.remove_rounded : Icons.add_rounded, color: SC.muted, size: 20),
                          ]),
                          if (_open == i) ...[
                            const SizedBox(height: 8),
                            Text(_ar ? visible[i].aAr : visible[i].aEn,
                                style: const TextStyle(color: Color(0xFFC5C9D2), fontSize: 12.5, height: 1.7)),
                          ],
                        ]),
                      ),
                    ),
              ]),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══ فورم الرسالة ═══════════════════════════════════════════════════════════
class _SupportFormPage extends StatefulWidget {
  const _SupportFormPage({required this.problem});
  final bool problem;

  @override
  State<_SupportFormPage> createState() => _SupportFormPageState();
}

class _SupportFormPageState extends State<_SupportFormPage> {
  final _subject = TextEditingController();
  final _body = TextEditingController();
  late String _cat = widget.problem ? 'technical' : 'account';
  bool _sending = false;
  String? _error;

  bool get _ar => AppLang.isArabic;
  String _t(String en, String ar) => AppLang.t(en, ar);

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF777D8A)),
        filled: true, fillColor: SC.chip, isDense: true, counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF41444F))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: SC.accent)),
      );

  Future<void> _send() async {
    final s = _subject.text.trim(), b = _body.text.trim();
    if (s.length < 3) {
      setState(() => _error = _t('Write a short title (3+ letters).', 'اكتب عنوان قصير (3 حروف على الأقل).'));
      return;
    }
    if (b.length < 10) {
      setState(() => _error = _t('Tell us a bit more (10+ letters).', 'اكتب تفاصيل أكتر شوية (10 حروف على الأقل).'));
      return;
    }
    setState(() { _sending = true; _error = null; });
    String? device;
    try {
      final t = await getDeviceTelemetry();
      device = [t.manufacturer, t.model, if (t.osName != null) '${t.osName} ${t.osVersion ?? ''}'.trim()]
          .whereType<String>().where((x) => x.isNotEmpty).join(' · ');
    } catch (_) {}
    try {
      await Supabase.instance.client.rpc('support_create', params: {
        'p_kind': widget.problem ? 'problem' : 'support',
        'p_category': _cat,
        'p_subject': s,
        'p_body': b,
        'p_app_version': AppConfig.appVersion,
        'p_device': device,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('support_create error: $e');
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.toString().contains('too_many_requests')
            ? _t('You sent many messages today. Please wait for our reply.', 'بعت رسايل كتير النهارده. استنى ردنا لو سمحت.')
            : _t('Something went wrong. Try again.', 'حصلت مشكلة. جرّب تاني.');
      });
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
        child: SPage(
          title: widget.problem ? _t('Report a problem', 'بلّغ عن مشكلة') : _t('Contact support', 'كلّم الدعم'),
          subtitle: widget.problem
              ? _t('What went wrong, and what were you doing?', 'إيه اللي حصل، وكنت بتعمل إيه؟')
              : _t("Ask us anything. We'll reply here.", 'اسألنا في أي حاجة، وهنرد عليك هنا.'),
          children: [
            Text(_t('Topic', 'الموضوع'), style: const TextStyle(color: SC.muted, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in _formCats)
                GestureDetector(
                  onTap: () => setState(() => _cat = c.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _cat == c.$1 ? SC.accent.withOpacity(0.14) : SC.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _cat == c.$1 ? SC.accent : SC.border),
                    ),
                    child: Text(_ar ? c.$3 : c.$2, style: TextStyle(color: SC.text, fontSize: 12.5,
                        fontWeight: _cat == c.$1 ? FontWeight.w800 : FontWeight.w600)),
                  ),
                ),
            ]),
            const SizedBox(height: 18),
            Text(_t('Title', 'العنوان'), style: const TextStyle(color: SC.muted, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(controller: _subject, maxLength: 120,
                style: const TextStyle(color: SC.text, fontSize: 14),
                decoration: _deco(_t('In a few words', 'في كلمتين'))),
            const SizedBox(height: 16),
            Text(_t('Details', 'التفاصيل'), style: const TextStyle(color: SC.muted, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(controller: _body, maxLength: 2000, minLines: 5, maxLines: 10,
                style: const TextStyle(color: SC.text, fontSize: 14, height: 1.5),
                decoration: _deco(widget.problem
                    ? _t('What happened? Which page? What did you expect?', 'إيه اللي حصل؟ في أنهي صفحة؟ وكنت متوقع إيه؟')
                    : _t('Write your question…', 'اكتب سؤالك…'))),
            const SizedBox(height: 10),
            Text(_t("Your app version and phone model are sent with it, to help us. Never write your login code.",
                    'نسخة التطبيق ونوع موبايلك بيتبعتوا معاها علشان يساعدونا. ماتكتبش كود الدخول أبدًا.'),
                style: const TextStyle(color: SC.muted, fontSize: 11.5, height: 1.6)),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: SC.danger, fontSize: 12.5)),
            ],
            const SizedBox(height: 18),
            _sending
                ? const Center(child: CircularProgressIndicator(color: SC.accent, strokeWidth: 2))
                : SBtn(_t('Send', 'ابعت'), primary: true, expand: true, icon: Icons.send_rounded, onTap: _send),
          ],
        ),
      );
}

// ═══ طلباتي ════════════════════════════════════════════════════════════════
class _MyRequestsPage extends StatefulWidget {
  const _MyRequestsPage();

  @override
  State<_MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<_MyRequestsPage> {
  List<Map<String, dynamic>>? _items;
  bool _failed = false;

  bool get _ar => AppLang.isArabic;
  String _t(String en, String ar) => AppLang.t(en, ar);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Supabase.instance.client.rpc('support_my_tickets');
      if (!mounted) return;
      setState(() {
        _items = (res as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _failed = false;
      });
    } catch (e) {
      debugPrint('support_my_tickets error: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _openThread(int id) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _ThreadPage(ticketId: id)));
    _load();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
        child: SPage(
          title: _t('My requests', 'طلباتي'),
          subtitle: _t('Your messages and our replies.', 'رسايلك وردودنا عليها.'),
          children: [
            if (_failed)
              Center(child: SBtn(_t('Try again', 'جرّب تاني'), onTap: _load))
            else if (_items == null)
              const Center(child: CircularProgressIndicator(color: SC.accent, strokeWidth: 2))
            else if (_items!.isEmpty)
              SEmpty(icon: Icons.inbox_outlined, title: _t('No requests yet', 'مفيش طلبات لسه'),
                  text: _t('Messages you send to support will show here.', 'الرسايل اللي بتبعتها للدعم هتظهر هنا.'))
            else
              SCard(children: [
                for (final t in _items!)
                  SRow(
                    icon: t['kind'] == 'problem' ? Icons.bug_report_outlined : Icons.chat_bubble_outline_rounded,
                    highlight: t['unread'] == true,
                    title: (t['subject'] ?? '').toString(),
                    desc: '${_statusLabel(t['status']?.toString())} · ${_when(t['updated_at']?.toString())}',
                    onTap: () => _openThread((t['id'] as num).toInt()),
                    trailing: t['unread'] == true
                        ? SPill(_t('New reply', 'رد جديد'), color: SC.accent)
                        : SPill(_statusLabel(t['status']?.toString()), color: _statusColor(t['status']?.toString())),
                  ),
              ]),
          ],
        ),
      );
}

// ═══ المحادثة ══════════════════════════════════════════════════════════════
class _ThreadPage extends StatefulWidget {
  const _ThreadPage({required this.ticketId});
  final int ticketId;

  @override
  State<_ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends State<_ThreadPage> {
  final _reply = TextEditingController();
  Map<String, dynamic>? _d;
  bool _sending = false;
  bool _failed = false;

  bool get _ar => AppLang.isArabic;
  String _t(String en, String ar) => AppLang.t(en, ar);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await Supabase.instance.client.rpc('support_thread', params: {'p_ticket_id': widget.ticketId});
      if (!mounted) return;
      setState(() { _d = res is Map ? Map<String, dynamic>.from(res) : null; _failed = _d == null; });
    } catch (e) {
      debugPrint('support_thread error: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _send() async {
    final b = _reply.text.trim();
    if (b.isEmpty) return;
    setState(() => _sending = true);
    try {
      await Supabase.instance.client.rpc('support_user_reply', params: {'p_ticket_id': widget.ticketId, 'p_body': b});
      _reply.clear();
      await _load();
    } catch (e) {
      debugPrint('support_user_reply error: $e');
      if (mounted) sToast(context, _t('Something went wrong. Try again.', 'حصلت مشكلة. جرّب تاني.'));
    }
    if (mounted) setState(() => _sending = false);
  }

  Widget _bubble(Map m) {
    final bdgr = m['from_bdgr'] == true;
    return Align(
      alignment: bdgr ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            color: bdgr ? SC.card : SC.accent.withOpacity(0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: bdgr ? OfficialAccount.gold.withOpacity(0.45) : SC.accent.withOpacity(0.35)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (bdgr)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Image.asset(Brand.badger, width: 16, color: OfficialAccount.gold),
                  const SizedBox(width: 5),
                  const Text('BDGR', style: TextStyle(color: SC.text, fontSize: 12, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 3),
                  const OfficialBadge(size: 13),
                ]),
              ),
            Text((m['body'] ?? '').toString(), style: const TextStyle(color: SC.text, fontSize: 13.5, height: 1.55)),
            const SizedBox(height: 4),
            Text(_when(m['created_at']?.toString()), style: const TextStyle(color: SC.muted, fontSize: 10.5)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _d?['ticket'] is Map ? Map<String, dynamic>.from(_d!['ticket'] as Map) : null;
    final msgs = (_d?['messages'] as List?)?.whereType<Map>().toList() ?? const [];
    return Directionality(
      textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: SC.bg,
        appBar: AppBar(
          backgroundColor: SC.bg, foregroundColor: SC.text, elevation: 0,
          title: Text((t?['subject'] ?? '').toString(),
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
          actions: [
            if (t != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: Center(child: SPill(_statusLabel(t['status']?.toString()), color: _statusColor(t['status']?.toString()))),
              ),
          ],
        ),
        body: _failed
            ? Center(child: SBtn(_t('Try again', 'جرّب تاني'), onTap: _load))
            : _d == null
                ? const Center(child: CircularProgressIndicator(color: SC.accent, strokeWidth: 2))
                : Column(children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        children: [
                          for (final m in msgs) _bubble(m),
                          if (msgs.isNotEmpty && msgs.last['from_bdgr'] != true)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(_t("We'll reply here as soon as we can.", 'هنرد عليك هنا في أقرب وقت.'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: SC.muted, fontSize: 11.5)),
                            ),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                        decoration: const BoxDecoration(color: SC.cardAlt, border: Border(top: BorderSide(color: SC.border))),
                        child: Row(children: [
                          Expanded(child: TextField(
                            controller: _reply, maxLength: 2000, minLines: 1, maxLines: 4,
                            style: const TextStyle(color: SC.text, fontSize: 14),
                            decoration: InputDecoration(
                              counterText: '', isDense: true, filled: true, fillColor: SC.chip,
                              hintText: _t('Write a reply…', 'اكتب رد…'),
                              hintStyle: const TextStyle(color: Color(0xFF777D8A)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                            ),
                          )),
                          const SizedBox(width: 8),
                          _sending
                              ? const SizedBox(width: 40, height: 40,
                                  child: Padding(padding: EdgeInsets.all(10),
                                      child: CircularProgressIndicator(color: SC.accent, strokeWidth: 2)))
                              : IconButton(
                                  onPressed: _send,
                                  icon: Icon(Icons.send_rounded, color: SC.accent,
                                      textDirection: _ar ? TextDirection.rtl : TextDirection.ltr),
                                ),
                        ]),
                      ),
                    ),
                  ]),
      ),
    );
  }
}
