import 'package:flutter/material.dart';

import '../../app_lang.dart';
import '../../brand.dart';
import '../../fantasy.dart' show cardBg, brandRed, surface2, muted, line;
import '../../profile/profile_page.dart' show captureVerifiedLocation;
import 'team_api.dart';

String _t(String en, String ar) => AppLang.t(en, ar);
const String _other = '__other__';

/// بيتأكد إن بيانات اللاعب كاملة؛ لو ناقصة يفتح الفورم. بيرجّع true لو كاملة.
Future<bool> ensureAthleteComplete(BuildContext context) async {
  try {
    final a = await TeamApi.athlete();
    if (a['complete'] == true) return true;
  } catch (_) {}
  if (!context.mounted) return false;
  return openAthleteForm(context);
}

Future<bool> openAthleteForm(BuildContext context) async {
  final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const AthleteFormPage()));
  return ok == true;
}

/// بيانات اللاعب: الموقع من الـ GPS (متسجّل ومش بيتعدّل) + منطقته اللي بيختارها (بتتعدّل) + الميلاد + النوع + المركز
class AthleteFormPage extends StatefulWidget {
  const AthleteFormPage({super.key});
  @override
  State<AthleteFormPage> createState() => _AthleteFormPageState();
}

class _AthleteFormPageState extends State<AthleteFormPage> {
  bool _loading = true, _locating = false, _saving = false;
  Map<String, dynamic>? _gps;
  List<Map<String, dynamic>> _govs = [];
  List<Map<String, dynamic>> _cities = [];
  String? _gov, _city, _district;
  final _cityOther = TextEditingController();
  final _districtOther = TextEditingController();
  DateTime? _birth;
  String? _gender, _position;
  bool get _ar => AppLang.isArabic;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cityOther.dispose();
    _districtOther.dispose();
    super.dispose();
  }

  Future<void> _load({bool fromGps = false}) async {
    try {
      final a = await TeamApi.athlete();
      _gps = a['gps'] == null ? null : Map<String, dynamic>.from(a['gps'] as Map);
      if (!fromGps) {
        _birth = DateTime.tryParse('${a['birth_date'] ?? ''}');
        _gender = const {'male', 'female'}.contains(a['gender']) ? a['gender'] as String : null;
        _position = a['position'] as String?;
      }
      final manual = (a['manual'] == null || fromGps) ? null : Map<String, dynamic>.from(a['manual'] as Map);
      final src = manual ?? _gps;
      final gov = src?['governorate'] as String?;
      final areas = await TeamApi.areas(gov);
      _govs = ((areas['governorates'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _cities = ((areas['cities'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _gov = _govs.any((g) => g['key'] == gov) ? gov : null;
      _setCity(src?['city'] as String?);
      _setDistrict(src?['district'] as String?);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TeamApi.error(e))));
    }
    if (mounted) setState(() => _loading = false);
  }

  // بنطابق اللي جه (من الـ GPS أو المحفوظ) مع القايمة؛ مش موجود → "أخرى" + النص
  void _setCity(String? v) {
    _cityOther.clear();
    if (v == null || v.trim().isEmpty) { _city = null; return; }
    final hit = _cities.firstWhere((c) => (c['en'] as String).toLowerCase() == v.toLowerCase(), orElse: () => const {});
    if (hit.isNotEmpty) { _city = hit['en'] as String; } else { _city = _other; _cityOther.text = v; }
  }

  List<Map<String, dynamic>> get _districts {
    final c = _cities.firstWhere((c) => c['en'] == _city, orElse: () => const {});
    return ((c['districts'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _setDistrict(String? v) {
    _districtOther.clear();
    if (v == null || v.trim().isEmpty) { _district = null; return; }
    final hit = _districts.firstWhere((d) => (d['en'] as String).toLowerCase() == v.toLowerCase(), orElse: () => const {});
    if (hit.isNotEmpty) { _district = hit['en'] as String; } else { _district = _other; _districtOther.text = v; }
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final r = await captureVerifiedLocation(context);
    if (r != null && mounted) {
      setState(() => _loading = true);
      await _load(fromGps: true);
    }
    if (mounted) setState(() => _locating = false);
  }

  Future<void> _pickGov(String? g) async {
    setState(() { _gov = g; _city = null; _district = null; _cities = []; _cityOther.clear(); _districtOther.clear(); });
    try {
      final areas = await TeamApi.areas(g);
      if (mounted) setState(() => _cities = ((areas['cities'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (_) {}
  }

  String? get _cityValue => _city == _other ? _cityOther.text.trim() : _city;
  String? get _districtValue => _district == _other ? _districtOther.text.trim() : _district;

  bool get _valid =>
      _gps != null && _birth != null && _gender != null && _gov != null && (_cityValue ?? '').isNotEmpty;

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    try {
      final b = _birth!;
      await TeamApi.athleteSave({
        'birth_date': '${b.year.toString().padLeft(4, '0')}-${b.month.toString().padLeft(2, '0')}-${b.day.toString().padLeft(2, '0')}',
        'gender': _gender, 'position': _position,
        'country': 'Egypt', 'governorate': _gov, 'city': _cityValue,
        'district': (_districtValue ?? '').isEmpty ? null : _districtValue,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TeamApi.error(e))));
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final last = DateTime(now.year - 13, now.month, now.day);
    final d = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 22, 1, 1),
      firstDate: DateTime(1920), lastDate: last,
      builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: brandRed, surface: Color(0xFF1A1A1A))), child: child!),
    );
    if (d != null) setState(() => _birth = d);
  }

  // ── UI ──
  Widget _section(String title, {String? sub, required List<Widget> children, IconData? icon}) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (icon != null) ...[Icon(icon, color: Colors.white70, size: 18), const SizedBox(width: 8)],
            Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900))),
          ]),
          if (sub != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(sub, style: const TextStyle(color: muted, fontSize: 12, height: 1.4))),
          const SizedBox(height: 10),
          ...children,
        ]),
      );

  Widget _lockedRow(String label, String? value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 78, child: Text(label, style: const TextStyle(color: muted, fontSize: 12.5))),
          Expanded(child: Text((value ?? '').isEmpty ? '—' : value!, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700))),
        ]),
      );

  /// قايمة اختيار (bottom sheet) — شكل الـ dropdown من غير DropdownButtonFormField
  Widget _dropdown<T>({required String label, required T? value, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) {
    final cur = items.where((i) => i.value == value).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () async {
          final picked = await showModalBottomSheet<T>(
            context: context, backgroundColor: const Color(0xFF161616), isScrollControlled: true,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
            builder: (ctx) => Directionality(
              textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
                child: ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 10), children: [
                  Padding(padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900))),
                  for (final i in items) ListTile(
                    dense: true,
                    title: DefaultTextStyle(style: TextStyle(color: i.value == value ? brandRed : Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700), child: i.child),
                    trailing: i.value == value ? const Icon(Icons.check_rounded, color: brandRed, size: 18) : null,
                    onTap: () => Navigator.pop(ctx, i.value),
                  ),
                ]),
              ),
            ),
          );
          if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
          decoration: _deco(label).copyWith(suffixIcon: const Icon(Icons.expand_more_rounded, color: muted)),
          child: cur.isEmpty
              ? Text(_t('Choose', 'اختار'), style: const TextStyle(color: muted, fontSize: 14))
              : DefaultTextStyle(style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), child: cur.first.child),
        ),
      ),
    );
  }

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: muted),
        filled: true, fillColor: surface2, isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  Widget _chip(String text, bool on, VoidCallback tap) => GestureDetector(
        onTap: tap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: on ? brandRed.withOpacity(0.16) : surface2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: on ? brandRed : Colors.transparent),
          ),
          child: Text(text, style: TextStyle(color: on ? Colors.white : Colors.white70, fontSize: 13, fontWeight: FontWeight.w800)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final gps = _gps;
    return Directionality(
      textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Brand.background,
        appBar: AppBar(
          backgroundColor: Brand.background, foregroundColor: Colors.white, elevation: 0,
          title: Text(_t('Player info', 'بيانات اللاعب'), style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: brandRed, strokeWidth: 2))
            : ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 24), children: [
                Text(_t('Needed once, so organizers can build fair tournaments near you.',
                        'مرة واحدة بس، عشان نعمل بطولات عادلة وقريبة منك.'),
                    style: const TextStyle(color: muted, fontSize: 12.5, height: 1.4)),
                const SizedBox(height: 14),
                // 1) الـ GPS — مش بيتعدّل
                _section(_t('Your location (GPS)', 'موقعك (GPS)'), icon: Icons.my_location_rounded,
                    sub: _t('Taken from your phone\'s GPS only. It can\'t be edited; only a new GPS reading updates it.',
                            'بيتاخد من الـ GPS بتاع موبايلك بس. مش بيتعدّل، وبيتحدّث بس لو عملت تحديد جديد.'),
                    children: [
                      if (gps != null) ...[
                        _lockedRow(_t('Country', 'البلد'), gps['country'] == 'Egypt' || gps['country'] == null ? _t('Egypt', 'مصر') : gps['country'] as String),
                        _lockedRow(_t('Governorate', 'المحافظة'), _ar ? gps['governorate_ar'] as String? : gps['governorate'] as String?),
                        _lockedRow(_t('City', 'المدينة'), gps['city'] as String?),
                        _lockedRow(_t('District', 'الحي'), gps['district'] as String?),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(width: double.infinity, height: 44, child: OutlinedButton.icon(
                        onPressed: _locating ? null : _locate,
                        icon: _locating
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.gps_fixed_rounded, size: 18),
                        label: Text(gps == null ? _t('Locate me', 'حدّد موقعي') : _t('Update location', 'حدّث موقعي'),
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white,
                            side: BorderSide(color: gps == null ? brandRed : Colors.white24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      )),
                    ]),
                // 2) منطقته — بيأكد أو يغيّر
                if (gps != null)
                  _section(_t('Your area', 'منطقتك'), icon: Icons.place_outlined,
                      sub: _t('Filled from GPS. Confirm it or change what you want.', 'جاية من الـ GPS. أكّدها أو غيّر اللي إنت عايزه.'),
                      children: [
                        _lockedRow(_t('Country', 'البلد'), _t('Egypt', 'مصر')),
                        const SizedBox(height: 6),
                        _dropdown<String>(
                          label: _t('Governorate', 'المحافظة'), value: _gov,
                          items: [for (final g in _govs) DropdownMenuItem(value: g['key'] as String, child: Text(_ar ? '${g['ar']}' : '${g['key']}'))],
                          onChanged: _pickGov,
                        ),
                        _dropdown<String>(
                          label: _t('City', 'المدينة'), value: _city,
                          items: [
                            for (final c in _cities) DropdownMenuItem(value: c['en'] as String, child: Text(_ar ? '${c['ar']}' : '${c['en']}')),
                            DropdownMenuItem(value: _other, child: Text(_t('Other…', 'أخرى…'))),
                          ],
                          onChanged: (v) => setState(() { _city = v; _district = null; _districtOther.clear(); }),
                        ),
                        if (_city == _other) Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(
                          controller: _cityOther, maxLength: 60, onChanged: (_) => setState(() {}),
                          style: const TextStyle(color: Colors.white), decoration: _deco(_t('Write your city', 'اكتب مدينتك')).copyWith(counterText: ''))),
                        _dropdown<String>(
                          label: _t('District (optional)', 'الحي (اختياري)'), value: _district,
                          items: [
                            for (final d in _districts) DropdownMenuItem(value: d['en'] as String, child: Text(_ar ? '${d['ar']}' : '${d['en']}')),
                            DropdownMenuItem(value: _other, child: Text(_t('Other…', 'أخرى…'))),
                          ],
                          onChanged: (v) => setState(() => _district = v),
                        ),
                        if (_district == _other) TextField(
                          controller: _districtOther, maxLength: 60, onChanged: (_) => setState(() {}),
                          style: const TextStyle(color: Colors.white), decoration: _deco(_t('Write your district', 'اكتب الحي')).copyWith(counterText: '')),
                      ]),
                // 3) الميلاد + النوع + المركز
                _section(_t('About you', 'عنك'), icon: Icons.person_outline_rounded, children: [
                  GestureDetector(
                    onTap: _pickBirth,
                    child: InputDecorator(
                      decoration: _deco(_t('Date of birth', 'تاريخ الميلاد')),
                      child: Text(_birth == null ? _t('Pick a date', 'اختار التاريخ')
                          : '${_birth!.day}/${_birth!.month}/${_birth!.year}',
                          style: TextStyle(color: _birth == null ? muted : Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(_t('Gender', 'النوع'), style: const TextStyle(color: muted, fontSize: 12.5)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, children: [
                    _chip(_t('Male', 'ذكر'), _gender == 'male', () => setState(() => _gender = 'male')),
                    _chip(_t('Female', 'أنثى'), _gender == 'female', () => setState(() => _gender = 'female')),
                  ]),
                  const SizedBox(height: 12),
                  Text(_t('Position (optional)', 'مركزك في الملعب (اختياري)'), style: const TextStyle(color: muted, fontSize: 12.5)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final p in const [['gk', 'Goalkeeper', 'حارس'], ['def', 'Defender', 'دفاع'], ['mid', 'Midfielder', 'وسط'], ['att', 'Attacker', 'هجوم']])
                      _chip(_t(p[1], p[2]), _position == p[0], () => setState(() => _position = _position == p[0] ? null : p[0])),
                  ]),
                ]),
                Text(_t('🔒 Teammates see only your area and position. Your exact location and birth date are never shown.',
                        '🔒 زمايلك في الفريق بيشوفوا منطقتك ومركزك بس. موقعك بالظبط وتاريخ ميلادك عمرهم ما بيظهروا.'),
                    style: const TextStyle(color: muted, fontSize: 11.5, height: 1.4)),
                const SizedBox(height: 16),
                SizedBox(height: 50, child: ElevatedButton(
                  onPressed: _valid && !_saving ? _save : null,
                  style: ElevatedButton.styleFrom(backgroundColor: brandRed, foregroundColor: Colors.white,
                      disabledBackgroundColor: surface2, disabledForegroundColor: muted, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_t('Save', 'حفظ'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                )),
              ]),
      ),
    );
  }
}
