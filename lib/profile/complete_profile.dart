import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_lang.dart';
import '../local_store.dart';
import '../motion_kit.dart';
import 'profile_page.dart' show captureVerifiedLocation;

// ═════════════════════════════════════════════════════════════════════════
// "Complete your profile" (owner, 28 Nov): asked once per round right after a squad is saved, and from the
// glowing "Complete profile" trophy in the cabinet. Only what is missing: name (still the default), username
// (still bdgrNNNN), governorate (GPS only, same rule as the prizes), birth date (13+). Skip any time.
// Completing = the "Complete profile" trophy + its level points (profile_level_pts.profile, 30).
// Server: my_profile_completeness() · account_settings_save · save_my_gps_location. Switch profile_complete_prompt.
// ═════════════════════════════════════════════════════════════════════════

final _sb = Supabase.instance.client;

/// After a squad save: once per round, only if something is missing and the switch is on.
/// Returns true when the sheet was shown (so the caller can skip other popups).
Future<bool> maybePromptCompleteProfile(BuildContext context, String eventId) async {
  try {
    final key = 'cp_prompt_$eventId';
    if (await LocalStore.getStr(key) != null) return false;
    final r = await _sb.rpc('my_profile_completeness');
    if (r is! Map) return false;
    final m = Map<String, dynamic>.from(r);
    if (m['complete'] == true || m['prompt'] == 'hide') return false;
    await LocalStore.setStr(key, '1');
    if (!context.mounted) return false;
    await showCompleteProfileSheet(context, data: m);
    return true;
  } catch (_) {
    return false;
  }
}

/// The sheet. [data] = my_profile_completeness() (loaded here when null). Returns true when the profile became complete.
Future<bool> showCompleteProfileSheet(BuildContext context, {Map<String, dynamic>? data}) async {
  var m = data;
  if (m == null) {
    try {
      final r = await _sb.rpc('my_profile_completeness');
      if (r is Map) m = Map<String, dynamic>.from(r);
    } catch (_) {}
  }
  if (m == null || !context.mounted) return false;
  final done = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF16171B),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _CompleteSheet(data: m!),
  );
  return done == true;
}

class _CompleteSheet extends StatefulWidget {
  const _CompleteSheet({required this.data});
  final Map<String, dynamic> data;
  @override
  State<_CompleteSheet> createState() => _CompleteSheetState();
}

class _CompleteSheetState extends State<_CompleteSheet> {
  late final Set<String> _missing = {...((widget.data['missing'] as List?) ?? const []).map((e) => '$e')};
  late final int _pts = (widget.data['points'] as num?)?.toInt() ?? 30;
  late final _name = TextEditingController(
      text: '${widget.data['display_name'] ?? ''}' == 'BDGR Athlete' ? '' : '${widget.data['display_name'] ?? ''}');
  late final _user = TextEditingController();
  String? _gov;
  bool _govBusy = false;
  DateTime? _birth;
  bool _busy = false;
  String? _err;

  String t(String en, String ar) => AppLang.t(en, ar);

  @override
  void dispose() {
    _name.dispose();
    _user.dispose();
    super.dispose();
  }

  InputDecoration _deco(String label, {String? prefix, String? hint}) => InputDecoration(
    labelText: label, prefixText: prefix, hintText: hint,
    labelStyle: const TextStyle(color: Colors.white54), prefixStyle: const TextStyle(color: Colors.white54),
    hintStyle: const TextStyle(color: Colors.white24),
    filled: true, fillColor: const Color(0xFF1F2026), counterText: '',
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  );

  String _errText(Object e) {
    final s = e.toString();
    if (s.contains('username_taken')) return t('This username is taken, try another', 'اليوزرنيم ده مستخدم، جرّب واحد تاني');
    if (s.contains('username_invalid')) return t('Username: 3–30 English letters, numbers, . or _', 'اليوزرنيم: من 3 لـ 30 حرف إنجليزي أو أرقام أو . أو _');
    if (s.contains('display_name_too_long')) return t('Name is too long (max 50)', 'الاسم طويل (أقصى حاجة 50)');
    if (s.contains('birth_date_invalid')) return t('You must be 13 or older', 'لازم يكون سنك 13 سنة أو أكتر');
    return t('Could not save, try again', 'ما اتحفظش، جرّب تاني');
  }

  Future<void> _pickGov() async {
    setState(() => _govBusy = true);
    final r = await captureVerifiedLocation(context);
    if (!mounted) return;
    setState(() {
      _govBusy = false;
      if (r != null && r['governorate'] != null) _gov = '${r['governorate']}';
    });
  }

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final last = DateTime(now.year - 13, now.month, now.day);
    final d = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 20),
      firstDate: DateTime(1920),
      lastDate: last,
      helpText: t('Your birth date', 'تاريخ ميلادك'),
    );
    if (d != null && mounted) setState(() => _birth = d);
  }

  Future<void> _save() async {
    final p = <String, dynamic>{};
    if (_missing.contains('name') && _name.text.trim().isNotEmpty) p['display_name'] = _name.text.trim();
    final u = _user.text.trim().toLowerCase().replaceAll('@', '');
    if (_missing.contains('username') && u.isNotEmpty) p['username'] = u;
    if (_missing.contains('birth_date') && _birth != null) {
      p['birth_date'] = '${_birth!.year.toString().padLeft(4, '0')}-${_birth!.month.toString().padLeft(2, '0')}-${_birth!.day.toString().padLeft(2, '0')}';
    }
    setState(() { _busy = true; _err = null; });
    try {
      if (p.isNotEmpty) await _sb.rpc('account_settings_save', params: {'p': p});
      final r = await _sb.rpc('my_profile_completeness');
      final complete = r is Map && r['complete'] == true;
      if (!mounted) return;
      if (complete) Buzz.medium();
      Navigator.of(context).pop(complete);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(complete
          ? t('Profile complete 🎉 +$_pts level points', 'بروفايلك كمل 🎉 +$_pts نقطة في مستواك')
          : t('Saved ✓ finish the rest any time from your profile', 'اتحفظ ✓ كمّل الباقي في أي وقت من بروفايلك'))));
    } catch (e) {
      if (mounted) setState(() { _busy = false; _err = _errText(e); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = AppLang.isArabic;
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Row(children: [
            const Text('🎯', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('Complete your profile, get $_pts points', 'كمّل بروفايلك واكسب $_pts نقطة'),
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(t('They count toward your level: Rookie → Amateur', 'بتتحسب في مستواك: من مبتدئ لهاوي'),
                  style: const TextStyle(color: Color(0xFFFFD27A), fontSize: 12.5, fontWeight: FontWeight.w700)),
            ])),
          ]),
          const SizedBox(height: 16),
          if (_missing.contains('name')) ...[
            TextField(controller: _name, maxLength: 50, style: const TextStyle(color: Colors.white),
                decoration: _deco(t('Your name', 'اسمك'))),
            const SizedBox(height: 4),
            Text(t('Your name can be the same as others', 'الاسم ممكن يكون زي ناس تانية'),
                style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
            const SizedBox(height: 12),
          ],
          if (_missing.contains('username')) ...[
            TextField(controller: _user, maxLength: 30, autocorrect: false, style: const TextStyle(color: Colors.white),
                decoration: _deco(t('Username', 'اليوزرنيم'), prefix: '@', hint: 'ahmed_10')),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF14231B), borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x552ECC71))),
              child: Text(t('Your username is yours only: nobody else in the app has it. Share it and anyone finds your profile at once.',
                  'اليوزرنيم ده بتاعك لوحدك، محدش تاني في التطبيق ليه نفسه. ابعته لأي حد يلاقي بروفايلك على طول.'),
                  style: const TextStyle(color: Color(0xFFB9F0D0), fontSize: 12, height: 1.4)),
            ),
            const SizedBox(height: 12),
          ],
          if (_missing.contains('governorate')) ...[
            _rowButton(
              icon: Icons.location_on_outlined,
              label: _gov != null ? '📍 $_gov' : t('Find my governorate', 'حدد محافظتي'),
              sub: t('From your location (GPS), used for the governorate rankings', 'من موقعك (GPS)، وبتتحسب في ترتيب المحافظات'),
              busy: _govBusy, done: _gov != null,
              onTap: _govBusy || _gov != null ? null : _pickGov,
            ),
            const SizedBox(height: 12),
          ],
          if (_missing.contains('birth_date')) ...[
            _rowButton(
              icon: Icons.cake_outlined,
              label: _birth != null ? '🎂 ${_birth!.day}/${_birth!.month}/${_birth!.year}' : t('Your birth date', 'تاريخ ميلادك'),
              sub: t('13 or older', '13 سنة أو أكتر'),
              done: _birth != null,
              onTap: _pickBirth,
            ),
            const SizedBox(height: 12),
          ],
          if (_err != null) ...[
            Text(_err!, style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13)),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          SizedBox(height: 48, child: ElevatedButton(
            onPressed: _busy ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF0000), foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(t('Save', 'حفظ'), style: const TextStyle(fontWeight: FontWeight.w900)),
          )),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: Text(t('Later', 'بعدين'), style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w700)),
          ),
        ])),
      ),
    );
  }

  Widget _rowButton({required IconData icon, required String label, required String sub,
      bool busy = false, bool done = false, VoidCallback? onTap}) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(color: const Color(0xFF1F2026), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: done ? const Color(0x882ECC71) : Colors.white10)),
      child: Row(children: [
        Icon(icon, color: done ? const Color(0xFF2ECC71) : Colors.white70, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700)),
          Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
        ])),
        if (busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))
        else Icon(done ? Icons.check_circle : Icons.chevron_right, color: done ? const Color(0xFF2ECC71) : Colors.white38),
      ]),
    ),
  );
}
