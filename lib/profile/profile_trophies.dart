import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_lang.dart';
import '../brand.dart';

/// كارت الفانتازي + دولاب الإنجازات في البروفايل (27 نوفمبر 2026).
/// كله من `profile_trophies(user)` على السيرفر (قراية بس، مفيش ملفات = إيجرس تقريباً صفر).
/// المستوى: new (أقل من 3 جولات) · bronze · silver (توب 10% مرة) · gold (توب 3 / كاس / دوري بادجر).
/// السويتش `app_settings.profile_card` = card | circle بيرجع في نفس الرد (`card`).

class ProfileTrophies {
  ProfileTrophies(this.j);
  final Map<String, dynamic> j;

  /// آخر قيمة للسويتش في التشغيل ده (عشان الصفحة ما تقفزش بين الدايرة والكارت).
  static bool cardOn = true;

  String get tier => (j['tier'] ?? 'new').toString();
  int get rounds => (j['rounds'] as num?)?.toInt() ?? 0;
  int get top10 => (j['top10'] as num?)?.toInt() ?? 0;
  List<Map<String, dynamic>> _list(String k) =>
      ((j[k] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  List<Map<String, dynamic>> get podium => _list('podium');
  List<Map<String, dynamic>> get top10List => _list('top10_list');
  List<Map<String, dynamic>> get cups => _list('cups');
  List<Map<String, dynamic>> get leagues => _list('leagues');
  bool get isEmpty => podium.isEmpty && top10 == 0 && cups.isEmpty && leagues.isEmpty;

  static Future<ProfileTrophies?> load(int userId) async {
    try {
      final r = await Supabase.instance.client.rpc('profile_trophies', params: {'p_user_id': userId});
      if (r is! Map) return null;
      final t = ProfileTrophies(Map<String, dynamic>.from(r));
      cardOn = (t.j['card'] ?? 'card') != 'circle';
      if (t.j['blocked'] == true) return null;
      return t;
    } catch (e) {
      debugPrint('profile_trophies error: $e');
      return null;
    }
  }
}

// ── ألوان المستويات ─────────────────────────────────────────────────────────
class _Tier {
  const _Tier(this.en, this.ar, this.colors, this.text);
  final String en, ar;
  final List<Color> colors; // الإطار
  final Color text;
}

const _tiers = <String, _Tier>{
  'new': _Tier('NEW', 'جديد', [Color(0xFF5A5A5A), Color(0xFF2A2A2A), Color(0xFF5A5A5A)], Color(0xFFDADADA)),
  'bronze': _Tier('BRONZE', 'برونز', [Color(0xFFE3A06B), Color(0xFF8C4F24), Color(0xFFD08A55)], Color(0xFFF0BB8E)),
  'silver': _Tier('SILVER', 'فضة', [Color(0xFFF4F6F8), Color(0xFF8E979F), Color(0xFFD9DEE2)], Color(0xFFE9EDF0)),
  'gold': _Tier('GOLD', 'دهب', [Color(0xFFFFE9A8), Color(0xFFA8771F), Color(0xFFE6B649)], Color(0xFFFFE08A)),
};

_Tier _tierOf(String k) => _tiers[k] ?? _tiers['new']!;

/// الكارت نفسه. بيترسم بأي عرض (صغير في الهيدر، كبير في الشيت).
class FantasyProfileCard extends StatelessWidget {
  const FantasyProfileCard({super.key, required this.width, required this.tier, required this.rounds,
      this.photo, this.name});

  final double width;
  final String tier;
  final int rounds;
  final ImageProvider? photo;
  final String? name; // بيظهر في الكبير بس
  static const double ratio = 1.36;

  @override
  Widget build(BuildContext context) {
    final t = _tierOf(tier);
    final w = width, h = width * ratio;
    final b = (w * 0.035).clamp(2.0, 6.0).toDouble();
    final r = w * 0.12;
    final big = name != null;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: w, height: h,
        padding: EdgeInsets.all(b),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: t.colors),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r - b),
          child: Stack(fit: StackFit.expand, children: [
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1414), Color(0xFF0B0909)],
            ))),
            // الصورة
            Positioned(left: 0, right: 0, top: 0, height: h * 0.70,
              child: ShaderMask(
                shaderCallback: (rc) => const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.white, Colors.transparent], stops: [0, 0.7, 1],
                ).createShader(rc),
                blendMode: BlendMode.dstIn,
                child: photo != null
                    ? Image(image: photo!, fit: BoxFit.cover)
                    : Padding(
                        padding: EdgeInsets.all(w * 0.2),
                        child: Image.asset('assets/badger_white.png', color: t.text.withOpacity(0.55),
                            fit: BoxFit.contain)),
              ),
            ),
            // المستوى فوق
            Positioned(top: h * 0.035, left: w * 0.07,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: w * 0.06, vertical: w * 0.015),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(w),
                  border: Border.all(color: t.text.withOpacity(0.6), width: 0.8),
                ),
                child: Text(t.en, style: TextStyle(color: t.text, fontSize: w * 0.085,
                    fontWeight: FontWeight.w900, letterSpacing: 0.8)),
              ),
            ),
            // تحت: الاسم (الكبير) + FANTASY + الجولات
            Positioned(left: w * 0.06, right: w * 0.06, bottom: h * 0.045,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (big) ...[
                  FittedBox(fit: BoxFit.scaleDown, child: Text(name!, maxLines: 1,
                      style: TextStyle(color: Colors.white, fontSize: w * 0.09, fontWeight: FontWeight.w900))),
                  SizedBox(height: h * 0.012),
                ],
                Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [
                  t.text.withOpacity(0), t.text.withOpacity(0.8), t.text.withOpacity(0)]))),
                SizedBox(height: h * 0.018),
                FittedBox(fit: BoxFit.scaleDown, child: Text('FANTASY · $rounds GW',
                    style: TextStyle(color: t.text, fontSize: w * 0.08, fontWeight: FontWeight.w800,
                        letterSpacing: 1))),
                if (big) ...[
                  SizedBox(height: h * 0.014),
                  Text('B D G R', style: TextStyle(color: t.text.withOpacity(0.55), fontSize: w * 0.04,
                      fontWeight: FontWeight.w800, letterSpacing: 3)),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// الكارت كبير + شير PNG (+ تغيير الصورة لصاحب الحساب).
Future<void> openProfileCardSheet(BuildContext context, {required ProfileTrophies? t, required String name,
    ImageProvider? photo, VoidCallback? onChangePhoto}) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF111111),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _CardSheet(t: t, name: name, photo: photo, onChangePhoto: onChangePhoto),
  );
}

class _CardSheet extends StatefulWidget {
  const _CardSheet({required this.t, required this.name, this.photo, this.onChangePhoto});
  final ProfileTrophies? t;
  final String name;
  final ImageProvider? photo;
  final VoidCallback? onChangePhoto;
  @override
  State<_CardSheet> createState() => _CardSheetState();
}

class _CardSheetState extends State<_CardSheet> {
  final _key = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final rb = _key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (rb == null) return;
      final img = await rb.toImage(pixelRatio: 3);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      await Share.shareXFiles(
        [XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png', name: 'bdgr_fantasy_card.png')],
        text: AppLang.t('My BDGR Fantasy card 🦡 ${Brand.shareLinkBase}', 'كارتي في فانتازي BDGR 🦡 ${Brand.shareLinkBase}'),
      );
    } catch (e) {
      debugPrint('card share error: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tier = widget.t?.tier ?? 'new';
    final tt = _tierOf(tier);
    final rounds = widget.t?.rounds ?? 0;
    final w = (MediaQuery.of(context).size.width * 0.58).clamp(180.0, 260.0).toDouble();
    final hint = switch (tier) {
      'new' => AppLang.t('Play ${3 - rounds.clamp(0, 3)} more round(s) to get your Bronze card',
          'العب ${3 - rounds.clamp(0, 3)} جولة كمان وكارتك يبقى برونز'),
      'bronze' => AppLang.t('Finish in the top 10% of a round → Silver', 'ادخل التوب 10% في جولة → فضة'),
      'silver' => AppLang.t('Top 3 in a round, or win a cup or the Badger League → Gold',
          'توب 3 في جولة، أو اكسب كاس أو دوري بادجر → دهب'),
      _ => AppLang.t('The highest level. Keep it 🔥', 'أعلى مستوى. حافظ عليه 🔥'),
    };
    return Directionality(
      textDirection: AppLang.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),
          RepaintBoundary(key: _key, child: Padding(
            padding: const EdgeInsets.all(6),
            child: FantasyProfileCard(width: w, tier: tier, rounds: rounds, photo: widget.photo, name: widget.name),
          )),
          const SizedBox(height: 14),
          Text(AppLang.t('${tt.en} card', 'كارت ${tt.ar}'),
              style: TextStyle(color: tt.text, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(hint, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4)),
          const SizedBox(height: 18),
          Row(children: [
            if (widget.onChangePhoto != null) ...[
              Expanded(child: OutlinedButton(
                onPressed: () { Navigator.pop(context); widget.onChangePhoto!(); },
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(AppLang.t('Change photo', 'غيّر الصورة')),
              )),
              const SizedBox(width: 10),
            ],
            Expanded(child: FilledButton.icon(
              onPressed: _sharing ? null : _share,
              icon: const Icon(Icons.ios_share, size: 18),
              label: Text(AppLang.t('Share', 'شير')),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF0000), foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            )),
          ]),
        ]),
      ),
    );
  }
}

// ── دولاب الإنجازات ─────────────────────────────────────────────────────────
class TrophyShelf extends StatelessWidget {
  const TrophyShelf({super.key, required this.t, required this.isOwner, this.onPlay});
  final ProfileTrophies t;
  final bool isOwner;
  final VoidCallback? onPlay; // يوديه الفانتازي (لما الرف فاضي)

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    if (t.cups.isNotEmpty) {
      items.add(_tile(context, '🏆', AppLang.t('Badger Cup', 'كاس بادجر'), t.cups.length, const Color(0xFFFFB300),
          () => _details(context, AppLang.t('Badger Cup champion', 'بطل كاس بادجر'),
              t.cups.map((c) => _line(AppLang.t(c['name_en'], c['name_ar']), _arena(c['arena']))).toList())));
    }
    if (t.leagues.isNotEmpty) {
      items.add(_tile(context, '🛡️', AppLang.t('Badger League', 'دوري بادجر'), t.leagues.length, const Color(0xFFFF4D4D),
          () => _details(context, AppLang.t('Badger League champion', 'بطل دوري بادجر'),
              t.leagues.map((l) => _line('${l['icon'] ?? ''} ${l['name'] ?? ''}', '${l['month'] ?? ''}')).toList())));
    }
    for (final p in const [1, 2, 3]) {
      final rows = t.podium.where((x) => (x['rank'] as num?)?.toInt() == p).toList();
      if (rows.isEmpty) continue;
      final medal = ['🥇', '🥈', '🥉'][p - 1];
      final color = [const Color(0xFFFFD54F), const Color(0xFFCFD8DC), const Color(0xFFD08A55)][p - 1];
      items.add(_tile(context, medal, AppLang.t('#$p in a round', 'المركز $p في جولة'), rows.length, color,
          () => _details(context, AppLang.t('#$p in a round', 'المركز $p في جولة'), rows.map(_roundLine).toList())));
    }
    if (t.top10 > 0) {
      items.add(_tile(context, '⭐', AppLang.t('Top 10%', 'توب 10%'), t.top10, const Color(0xFF7FD1FF),
          () => _details(context, AppLang.t('Top 10% of a round', 'توب 10% في جولة'), t.top10List.map(_roundLine).toList())));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(AppLang.t('Trophies', 'الإنجازات'),
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Text(AppLang.t('Fantasy', 'الفانتازي'), style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ]),
        const SizedBox(height: 10),
        if (items.isEmpty)
          _empty(context)
        else
          Container(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
            decoration: BoxDecoration(
              color: const Color(0xFF141111),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(children: [
              SizedBox(
                height: 104,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => items[i],
                ),
              ),
              // الرف
              Container(height: 6, margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  gradient: LinearGradient(colors: [Colors.white.withOpacity(0.02), Colors.white.withOpacity(0.12),
                    Colors.white.withOpacity(0.02)]),
                )),
            ]),
          ),
      ]),
    );
  }

  Widget _empty(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    decoration: BoxDecoration(
      color: const Color(0xFF141111),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white10),
    ),
    child: Row(children: [
      const Opacity(opacity: 0.35, child: Text('🏆', style: TextStyle(fontSize: 28))),
      const SizedBox(width: 12),
      Expanded(child: Text(
        isOwner ? AppLang.t('Your first trophy is waiting', 'أول كاس مستنيك')
                : AppLang.t('No trophies yet', 'لسه مفيش إنجازات'),
        style: const TextStyle(color: Colors.white70, fontSize: 13.5, fontWeight: FontWeight.w600))),
      if (isOwner && onPlay != null)
        TextButton(onPressed: onPlay,
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF4D4D)),
          child: Text(AppLang.t('Play ›', 'العب ›'), style: const TextStyle(fontWeight: FontWeight.w800))),
    ]),
  );

  Widget _tile(BuildContext context, String icon, String label, int n, Color c, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: SizedBox(width: 84, child: Column(children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 58, height: 58, alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [c.withOpacity(0.28), Colors.transparent])),
            child: Text(icon, style: const TextStyle(fontSize: 32)),
          ),
          if (n > 1)
            Positioned(right: -2, top: 0, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(10)),
              child: Text('×$n', style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900)),
            )),
        ]),
        const SizedBox(height: 6),
        Text(label, maxLines: 2, textAlign: TextAlign.center,
            style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.2)),
      ])),
    );

  static String _arena(dynamic a) => a == 'WORLD' ? AppLang.t('World', 'العالم') : AppLang.t('Egypt', 'مصر');

  static Widget _roundLine(Map<String, dynamic> r) {
    final rank = (r['rank'] as num?)?.toInt() ?? 0;
    final n = (r['players'] as num?)?.toInt() ?? 0;
    return _line('${AppLang.t(r['name_en'], r['name_ar'])} · ${_arena(r['arena'])}',
        AppLang.t('#$rank of $n', '#$rank من $n'));
  }

  static Widget _line(String a, String b) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      Expanded(child: Text(a, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
      Text(b, style: const TextStyle(color: Colors.white54, fontSize: 13)),
    ]),
  );

  void _details(BuildContext context, String title, List<Widget> lines) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Directionality(
        textDirection: AppLang.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView(shrinkWrap: true, children: [
                for (final l in lines) ...[l, const Divider(height: 1, color: Colors.white10)],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
