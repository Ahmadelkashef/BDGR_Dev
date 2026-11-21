import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_lang.dart';
import '../brand.dart';
import 'settings_ui.dart';

/// الشروط وسياسة الخصوصية: نفس المحتوى المنشور على الويب (bdgr-link/legal/content.json)
/// — مصدر واحد للتطبيق والتسجيل وGoogle Play. اسم الجهة والإيميل من legal_info().
class TermsPrivacyPage extends StatefulWidget {
  const TermsPrivacyPage({super.key, this.initialDoc = 'terms'});
  final String initialDoc;

  @override
  State<TermsPrivacyPage> createState() => _TermsPrivacyPageState();
}

class _TermsPrivacyPageState extends State<TermsPrivacyPage> {
  Map<String, dynamic>? _content;
  Map<String, dynamic> _info = const {'entity': 'BDGR', 'email': 'mekkawy4@gmail.com'};
  Map<String, dynamic>? _mine;
  late String _doc = widget.initialDoc;
  bool _failed = false;

  bool get _ar => AppLang.isArabic;
  String _t(String en, String ar) => AppLang.t(en, ar);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final res = await http
          .get(Uri.parse('${Brand.legalUrl}content.json'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final c = jsonDecode(utf8.decode(res.bodyBytes));
      if (!mounted) return;
      setState(() => _content = c is Map ? Map<String, dynamic>.from(c) : null);
    } catch (e) {
      debugPrint('legal content error: $e');
      if (mounted) setState(() => _failed = true);
    }
    try {
      final sb = Supabase.instance.client;
      final r = await Future.wait([sb.rpc('legal_info'), sb.rpc('legal_my_status')]);
      if (!mounted) return;
      setState(() {
        if (r[0] is Map && (r[0] as Map)['entity'] != null) _info = Map<String, dynamic>.from(r[0] as Map);
        if (r[1] is Map) _mine = Map<String, dynamic>.from(r[1] as Map);
      });
    } catch (e) {
      debugPrint('legal info error: $e');
    }
  }

  Future<void> _openWeb() async {
    final url = Uri.parse('${Brand.legalUrl}?lang=${_ar ? 'ar' : 'en'}#$_doc');
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && mounted) sToast(context, _t("Couldn't open the browser.", 'مقدرناش نفتح المتصفح.'));
  }

  String _fill(String s) => s
      .replaceAll('{entity}', (_info['entity'] ?? 'BDGR').toString())
      .replaceAll('{email}', (_info['email'] ?? '').toString());

  String _date(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year}';
  }

  Widget _section(Map s) {
    final lines = ((_ar ? s['ar'] : s['en']) as List? ?? const []).map((e) => _fill(e.toString())).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 8),
      decoration: BoxDecoration(color: SC.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: SC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((_ar ? s['h_ar'] : s['h_en']).toString(),
            style: const TextStyle(color: SC.text, fontSize: 14.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: l.startsWith('- ')
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(padding: EdgeInsets.only(top: 9),
                        child: CircleAvatar(radius: 2.2, backgroundColor: SC.muted)),
                    const SizedBox(width: 9),
                    Expanded(child: Text(l.substring(2),
                        style: const TextStyle(color: Color(0xFFD6D8DF), fontSize: 13, height: 1.75))),
                  ])
                : Text(l, style: const TextStyle(color: Color(0xFFD6D8DF), fontSize: 13, height: 1.75)),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = (_content?['docs'] as List?)?.whereType<Map>().toList() ?? const [];
    final doc = docs.firstWhere((d) => d['id'] == _doc, orElse: () => docs.isNotEmpty ? docs.first : const {});
    final accepted = _mine?['terms_version']?.toString();

    return Directionality(
      textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
      child: SPage(
        title: _t('Terms & Privacy', 'الشروط والخصوصية'),
        subtitle: _content == null ? ''
            : '${_t('Version', 'النسخة')} ${_content!['version']} · ${_t('Effective', 'سارية من')} ${_content!['effective']}',
        bottomText: '${_info['entity']} · ${_info['email']}',
        children: [
          if (_failed && _content == null) ...[
            SNotice(text: _t("Couldn't load the terms. Check your internet, or open them in the browser.",
                'مقدرناش نحمّل الشروط. اتأكد من النت، أو افتحها في المتصفح.')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: SBtn(_t('Try again', 'جرّب تاني'), expand: true, onTap: _load)),
              const SizedBox(width: 10),
              Expanded(child: SBtn(_t('Open in browser', 'افتح في المتصفح'), expand: true, onTap: _openWeb)),
            ]),
          ] else if (_content == null)
            const Padding(padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator(color: SC.accent, strokeWidth: 2)))
          else ...[
            if (accepted != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: SNotice(
                  plain: true, color: SC.success, icon: Icons.verified_outlined,
                  text: _t('You agreed to version $accepted on ${_date(_mine?['accepted_at']?.toString())}.',
                      'انت وافقت على النسخة $accepted يوم ${_date(_mine?['accepted_at']?.toString())}.'),
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final d in docs)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _doc = d['id'].toString()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _doc == d['id'] ? SC.accent.withOpacity(0.14) : SC.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _doc == d['id'] ? SC.accent : SC.border),
                        ),
                        child: Text((_ar ? d['title_ar'] : d['title_en']).toString(),
                            style: TextStyle(color: SC.text, fontSize: 12.5,
                                fontWeight: _doc == d['id'] ? FontWeight.w800 : FontWeight.w600)),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 14),
            for (final s in (doc['sections'] as List? ?? const []).whereType<Map>()) _section(s),
            const SizedBox(height: 6),
            SBtn(_t('Open in browser', 'افتح في المتصفح'), icon: Icons.open_in_new_rounded, expand: true, onTap: _openWeb),
          ],
        ],
      ),
    );
  }
}
