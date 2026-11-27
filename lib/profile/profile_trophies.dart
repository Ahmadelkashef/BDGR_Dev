import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_lang.dart';
import '../brand.dart';
import '../competitions/competition_sports.dart';

/// كارت الفانتازي + تابات الإنجازات والفانتازي في البروفايل (27 نوفمبر 2026).
/// كله من `profile_trophies(user)` (قراية بس، مفيش ملفات = إيجرس تقريباً صفر).
/// - المستوى: new (أقل من 3 جولات) · bronze · silver (توب 10% مرة) · gold (توب 3 / كاس / دوري بادجر).
/// - تصنيف بادجر (rating): مجموع نقط آخر 10 جولات، بيتحسب على السيرفر لما الجولة تخلص.
///   الكارت بيعرض الأحسن بين مصر والعالم.
/// - الإنجازات = ألقاب (الأول في أي حاجة) + أوسمة.
/// السويتش `app_settings.profile_card` = card | circle بيرجع في نفس الرد (`card`).

class ProfileTrophies {
  ProfileTrophies(this.j);
  final Map<String, dynamic> j;

  /// آخر قيمة للسويتش في التشغيل ده (عشان الصفحة ما تقفزش بين الدايرة والكارت).
  static bool cardOn = true;

  String get tier => (j['tier'] ?? 'new').toString();
  int get rounds => (j['rounds'] as num?)?.toInt() ?? 0;
  int get trophies => (j['trophies'] as num?)?.toInt() ?? 0;
  Map<String, dynamic>? get rating => j['rating'] is Map ? Map<String, dynamic>.from(j['rating'] as Map) : null;
  List<Map<String, dynamic>> _list(String k) =>
      ((j[k] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  List<Map<String, dynamic>> get titles => _list('titles');
  List<Map<String, dynamic>> get badges => _list('badges');
  List<Map<String, dynamic>> get roundsList => _list('rounds_list');

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

String fmtInt(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

String _arenaShort(dynamic a) => a == 'WORLD' ? '🌍' : 'EG';
String _arenaName(dynamic a) => a == 'WORLD' ? AppLang.t('World', 'العالم') : AppLang.t('Egypt', 'مصر');

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

/// الكارت نفسه. بيترسم بأي عرض (في الهيدر، وكبير في الشيت).
class FantasyProfileCard extends StatelessWidget {
  const FantasyProfileCard({super.key, required this.width, required this.tier, this.rating, this.photo, this.name});

  final double width;
  final String tier;
  final Map<String, dynamic>? rating; // {rank, players, arena, rating}
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
    final rank = (rating?['rank'] as num?)?.toInt();
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: w, height: h,
        padding: EdgeInsets.all(b),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: t.colors),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r - b),
          child: Stack(fit: StackFit.expand, children: [
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1414), Color(0xFF0B0909)],
            ))),
            Positioned(left: 0, right: 0, top: 0, height: h * 0.68,
              child: ShaderMask(
                shaderCallback: (rc) => const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.white, Colors.transparent], stops: [0, 0.68, 1],
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
            Positioned(top: h * 0.035, left: w * 0.07,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: w * 0.06, vertical: w * 0.015),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(w),
                  border: Border.all(color: t.text.withOpacity(0.6), width: 0.8),
                ),
                child: Text(t.en, style: TextStyle(color: t.text, fontSize: w * 0.075,
                    fontWeight: FontWeight.w900, letterSpacing: 0.8)),
              ),
            ),
            Positioned(left: w * 0.06, right: w * 0.06, bottom: h * 0.04,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (big) ...[
                  FittedBox(fit: BoxFit.scaleDown, child: Text(name!, maxLines: 1,
                      style: TextStyle(color: Colors.white, fontSize: w * 0.09, fontWeight: FontWeight.w900))),
                  SizedBox(height: h * 0.01),
                ],
                if (rank != null)
                  FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('#${fmtInt(rank)}', style: TextStyle(color: Colors.white, fontSize: w * 0.15,
                        fontWeight: FontWeight.w900, height: 1)),
                    SizedBox(width: w * 0.03),
                    Text(_arenaShort(rating?['arena']), style: TextStyle(color: t.text, fontSize: w * 0.075,
                        fontWeight: FontWeight.w900)),
                  ])),
                SizedBox(height: h * 0.012),
                Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [
                  t.text.withOpacity(0), t.text.withOpacity(0.8), t.text.withOpacity(0)]))),
                SizedBox(height: h * 0.014),
                FittedBox(fit: BoxFit.scaleDown, child: Text(rank != null ? 'FANTASY RATING' : 'FANTASY',
                    style: TextStyle(color: t.text, fontSize: w * 0.068, fontWeight: FontWeight.w800, letterSpacing: 1))),
                if (big) ...[
                  SizedBox(height: h * 0.012),
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
/// [onPick] = صاحب البروفايل يخلّي الكارت ده هو اللي يظهر الأول للناس.
Future<void> openProfileCardSheet(BuildContext context, {required ProfileTrophies? t, required String name,
    ImageProvider? photo, VoidCallback? onChangePhoto, bool picked = false, Future<void> Function()? onPick}) {
  final tier = t?.tier ?? 'new';
  final tt = _tierOf(tier);
  final rounds = t?.rounds ?? 0;
  final rating = t?.rating;
  final hint = switch (tier) {
    'new' => AppLang.t('Play ${3 - rounds.clamp(0, 3)} more round(s) to get your Bronze card',
        'العب ${3 - rounds.clamp(0, 3)} جولة كمان وكارتك يبقى برونز'),
    'bronze' => AppLang.t('Finish in the top 10% of a round → Silver', 'ادخل التوب 10% في جولة → فضة'),
    'silver' => AppLang.t('Top 3 in a round, or win a cup or the Badger League → Gold',
        'توب 3 في جولة، أو اكسب كاس أو دوري بادجر → دهب'),
    _ => AppLang.t('The highest level. Keep it 🔥', 'أعلى مستوى. حافظ عليه 🔥'),
  };
  final sub = rating == null ? null : AppLang.t(
      'Badger Rating ${rating['rating']} · #${fmtInt((rating['rank'] as num).toInt())} of ${fmtInt((rating['players'] as num?)?.toInt() ?? 0)} · ${_arenaName(rating['arena'])}\nYour last 10 rounds',
      'تصنيف بادجر ${rating['rating']} · #${fmtInt((rating['rank'] as num).toInt())} من ${fmtInt((rating['players'] as num?)?.toInt() ?? 0)} · ${_arenaName(rating['arena'])}\nآخر 10 جولات ليك');
  return _openCardSheet(context,
      face: (w) => FantasyProfileCard(width: w, tier: tier, rating: rating, photo: photo, name: name),
      title: AppLang.t('${tt.en} card', 'كارت ${tt.ar}'), titleColor: tt.text, hint: hint, sub: sub,
      shareText: AppLang.t('My BDGR Fantasy card 🦡 ${Brand.shareLinkBase}', 'كارتي في فانتازي BDGR 🦡 ${Brand.shareLinkBase}'),
      onChangePhoto: onChangePhoto, picked: picked, onPick: onPick);
}

Future<void> _openCardSheet(BuildContext context, {required Widget Function(double w) face, required String title,
    required Color titleColor, required String hint, String? sub, required String shareText,
    VoidCallback? onChangePhoto, bool picked = false, Future<void> Function()? onPick}) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF111111),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _CardSheet(face: face, title: title, titleColor: titleColor, hint: hint, sub: sub,
        shareText: shareText, onChangePhoto: onChangePhoto, picked: picked, onPick: onPick),
  );
}

class _CardSheet extends StatefulWidget {
  const _CardSheet({required this.face, required this.title, required this.titleColor, required this.hint,
      this.sub, required this.shareText, this.onChangePhoto, this.picked = false, this.onPick});
  final Widget Function(double w) face;
  final String title, hint, shareText;
  final Color titleColor;
  final String? sub;
  final VoidCallback? onChangePhoto;
  final bool picked;
  final Future<void> Function()? onPick;
  @override
  State<_CardSheet> createState() => _CardSheetState();
}

class _CardSheetState extends State<_CardSheet> {
  final _key = GlobalKey();
  bool _sharing = false;
  late bool _picked = widget.picked;
  bool _picking = false;

  Future<void> _pick() async {
    if (_picked || _picking || widget.onPick == null) return;
    setState(() => _picking = true);
    try {
      await widget.onPick!();
      if (mounted) setState(() => _picked = true);
    } catch (e) {
      debugPrint('card pick error: $e');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

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
        [XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png', name: 'bdgr_card.png')],
        text: widget.shareText,
      );
    } catch (e) {
      debugPrint('card share error: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.of(context).size.width * 0.58).clamp(180.0, 260.0).toDouble();
    return Directionality(
      textDirection: AppLang.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),
          RepaintBoundary(key: _key, child: Padding(
            padding: const EdgeInsets.all(6),
            child: widget.face(w),
          )),
          const SizedBox(height: 14),
          Text(widget.title, style: TextStyle(color: widget.titleColor, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(widget.hint, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4)),
          if (widget.sub != null) ...[
            const SizedBox(height: 10),
            Text(widget.sub!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.4)),
          ],
          if (widget.onPick != null) ...[
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: _picked || _picking ? null : _pick,
              icon: Icon(_picked ? Icons.check_circle : Icons.push_pin_outlined, size: 18,
                  color: _picked ? const Color(0xFF5FE08A) : Colors.white),
              label: Text(_picked
                  ? AppLang.t('Shown first on your profile', 'ده اللي بيظهر الأول على بروفايلك')
                  : AppLang.t('Show this card first on my profile', 'خلّي الكارت ده يظهر الأول'),
                  style: TextStyle(color: _picked ? const Color(0xFF5FE08A) : Colors.white)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: _picked ? const Color(0x665FE08A) : Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            )),
          ],
          const SizedBox(height: 12),
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

// ── تاب الإنجازات ───────────────────────────────────────────────────────────
class TrophiesTab extends StatefulWidget {
  const TrophiesTab({super.key, required this.t, required this.isOwner, this.onPlay});
  final ProfileTrophies? t;
  final bool isOwner;
  final VoidCallback? onPlay;
  @override
  State<TrophiesTab> createState() => _TrophiesTabState();
}

class _TrophiesTabState extends State<TrophiesTab> {
  String _filter = 'all'; // all | fantasy (tournaments / challenges = قريب)

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final titles = t?.titles ?? const [];
    final badges = t?.badges ?? const [];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _filterMenu(),
        const SizedBox(height: 14),
        if (t == null)
          const Padding(padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: Color(0xFFFF2B2B), strokeWidth: 2)))
        else if (titles.isEmpty && badges.isEmpty)
          _empty()
        else ...[
          if (titles.isNotEmpty) ...[
            _head('🏆', AppLang.t('Titles', 'ألقاب'), titles.length, const Color(0xFFF2C75C)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.82,
              children: [for (final x in titles) _titleTile(context, x)],
            ),
            const SizedBox(height: 18),
          ],
          if (badges.isNotEmpty) ...[
            _head('🎖️', AppLang.t('Badges', 'أوسمة'),
                badges.fold<int>(0, (a, b) => a + ((b['count'] as num?)?.toInt() ?? 1)), Colors.white),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [for (final b in badges) _badgeTile(b)]),
          ],
        ],
      ]),
    );
  }

  Widget _filterMenu() {
    String label(String k) => switch (k) {
      'fantasy' => AppLang.t('Fantasy', 'الفانتازي'),
      'tournaments' => AppLang.t('Tournaments · soon', 'البطولات · قريب'),
      'challenges' => AppLang.t('Challenges · soon', 'التشالنجات · قريب'),
      _ => AppLang.t('All', 'الكل'),
    };
    return PopupMenuButton<String>(
      color: const Color(0xFF1A1A1F),
      onSelected: (v) => setState(() => _filter = v),
      itemBuilder: (_) => [
        for (final k in const ['all', 'fantasy', 'tournaments', 'challenges'])
          PopupMenuItem(value: k, enabled: k == 'all' || k == 'fantasy',
              child: Text(label(k), style: TextStyle(color: (k == 'all' || k == 'fantasy') ? Colors.white : Colors.white38))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFF17171C), borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF2A2A30))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label(_filter), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, color: Colors.white60, size: 18),
        ]),
      ),
    );
  }

  Widget _head(String icon, String label, int n, Color c) => Row(children: [
    Text('$icon  $label', style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.w800)),
    const SizedBox(width: 6),
    Text('· $n', style: const TextStyle(color: Colors.white38, fontSize: 14, fontWeight: FontWeight.w700)),
  ]);

  Widget _empty() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
    decoration: BoxDecoration(color: const Color(0xFF141111), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10)),
    child: Row(children: [
      const Opacity(opacity: 0.35, child: Text('🏆', style: TextStyle(fontSize: 28))),
      const SizedBox(width: 12),
      Expanded(child: Text(
        widget.isOwner ? AppLang.t('Your first trophy is waiting', 'أول كاس مستنيك')
                       : AppLang.t('No trophies yet', 'لسه مفيش إنجازات'),
        style: const TextStyle(color: Colors.white70, fontSize: 13.5, fontWeight: FontWeight.w600))),
      if (widget.isOwner && widget.onPlay != null)
        TextButton(onPressed: widget.onPlay,
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF4D4D)),
          child: Text(AppLang.t('Play ›', 'العب ›'), style: const TextStyle(fontWeight: FontWeight.w800))),
    ]),
  );

  static String _round(Map<String, dynamic> x) =>
      AppLang.t('${x['name_en'] ?? 'Round'}', '${x['name_ar'] ?? 'جولة'}');

  Widget _titleTile(BuildContext context, Map<String, dynamic> x) {
    final kind = x['kind'];
    final (String icon, String title, String sub) = switch (kind) {
      'app1' => ('🥇', AppLang.t('#1 on BDGR', 'الأول على BDGR'), '${_round(x)} · ${_arenaName(x['arena'])}'),
      'gov1' => ('📍', AppLang.t('#1 in ${x['gov'] ?? ''}', 'الأول في ${x['gov'] ?? ''}'), '${_round(x)} · ${_arenaName(x['arena'])}'),
      'league1' => ('🏅', AppLang.t('#1 in ${x['league'] ?? 'league'}', 'الأول في ${x['league'] ?? 'الليج'}'), '${_round(x)} · ${_arenaName(x['arena'])}'),
      'cup' => ('🏆', AppLang.t('${x['name_en'] ?? 'Badger Cup'}', '${x['name_ar'] ?? 'كاس بادجر'}'), AppLang.t('Champion', 'البطل')),
      'bl' => ('🛡️', AppLang.t('Badger League', 'دوري بادجر'), '${x['icon'] ?? ''} ${x['name'] ?? ''} · ${x['month'] ?? ''}'),
      _ => ('🏆', '', ''),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0x26F2C75C), Color(0xFF141111)]),
        border: Border.all(color: const Color(0x40F2C75C)),
      ),
      child: Column(children: [
        Text(icon, style: const TextStyle(fontSize: 30)),
        const SizedBox(height: 6),
        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFF2C75C), fontSize: 12, fontWeight: FontWeight.w800, height: 1.2)),
        const SizedBox(height: 3),
        Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 10.5, height: 1.2)),
      ]),
    );
  }

  Widget _badgeTile(Map<String, dynamic> b) {
    final n = (b['count'] as num?)?.toInt() ?? 1;
    final (String icon, String label) = switch (b['kind']) {
      'rank2' => ('🥈', AppLang.t('#2 in a round', 'التاني في جولة')),
      'rank3' => ('🥉', AppLang.t('#3 in a round', 'التالت في جولة')),
      'top10' => ('⭐', AppLang.t('Top 10%', 'توب 10%')),
      'played' => ('🎯', AppLang.t('${b['n']} rounds', '${b['n']} جولة')),
      _ => ('🎖️', ''),
    };
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(color: const Color(0xFF141418), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10)),
      child: Column(children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(n > 1 ? '$label ×$n' : label, textAlign: TextAlign.center, maxLines: 2,
            style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.2)),
      ]),
    );
  }
}

// ── تاب الفانتازي ───────────────────────────────────────────────────────────
class FantasyProfileTab extends StatelessWidget {
  const FantasyProfileTab({super.key, required this.t, required this.isOwner, this.onPlay});
  final ProfileTrophies? t;
  final bool isOwner;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final t = this.t;
    if (t == null) {
      return const Padding(padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator(color: Color(0xFFFF2B2B), strokeWidth: 2)));
    }
    final rating = t.rating;
    final rows = t.roundsList;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF141418), borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10)),
          child: Row(children: [
            Expanded(child: _num(rating != null ? '#${fmtInt((rating['rank'] as num).toInt())}' : '—',
                AppLang.t('Badger Rating', 'تصنيف بادجر') + (rating != null ? ' · ${_arenaShort(rating['arena'])}' : ''))),
            Expanded(child: _num(rating != null ? '${rating['rating']}' : '—', AppLang.t('Rating pts', 'نقط التصنيف'))),
            Expanded(child: _num('${t.rounds}', AppLang.t('Rounds', 'جولات'))),
          ]),
        ),
        const SizedBox(height: 6),
        Text(AppLang.t('Rating = your places in the last 10 rounds + titles', 'التصنيف = مراكزك في آخر 10 جولات + الألقاب'),
            style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF141111), borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10)),
            child: Row(children: [
              Expanded(child: Text(isOwner ? AppLang.t('No finished rounds yet', 'لسه مفيش جولات خلصت')
                                           : AppLang.t('No rounds yet', 'لسه ما لعبش جولات'),
                  style: const TextStyle(color: Colors.white70, fontSize: 13.5))),
              if (isOwner && onPlay != null)
                TextButton(onPressed: onPlay, style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF4D4D)),
                    child: Text(AppLang.t('Play ›', 'العب ›'), style: const TextStyle(fontWeight: FontWeight.w800))),
            ]),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: const Color(0xFF141418), borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10)),
            child: Column(children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: Colors.white10),
                _row(rows[i]),
              ],
            ]),
          ),
      ]),
    );
  }

  Widget _num(String v, String l) => Column(children: [
    Text(v, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
    const SizedBox(height: 2),
    Text(l, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 11)),
  ]);

  Widget _row(Map<String, dynamic> r) {
    final rank = (r['rank'] as num?)?.toInt() ?? 0;
    final n = (r['players'] as num?)?.toInt() ?? 0;
    final pts = r['points'];
    final ptsTxt = pts is num ? (pts == pts.roundToDouble() ? pts.toInt().toString() : pts.toString()) : '—';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Text(_arenaShort(r['arena']), style: const TextStyle(fontSize: 13, color: Colors.white54, fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        Expanded(child: Text(AppLang.t('${r['name_en'] ?? ''}', '${r['name_ar'] ?? ''}'),
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
        Text(AppLang.t('$ptsTxt pts', '$ptsTxt نقطة'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(width: 12),
        Text(AppLang.t('#${fmtInt(rank)} of ${fmtInt(n)}', '#${fmtInt(rank)} من ${fmtInt(n)}'),
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// كروت البروفايل (27 نوفمبر، PROFILE v3): كذا كارت في نفس مكان ومقاس كارت الفانتازي،
// بتتقلب بالسحب. فانتازي (لو لعب) · كارت لكل رياضة مسجّل فيها · BDGR ID (لكل الناس).
// صاحب البروفايل بيختار الكارت اللي يظهر الأول (`profile_card_pick_set`).
// الداتا من نفس `profile_trophies` → `cards` {pick, since, sports[{id, fav, position, teams, captain, matches}]}.
// ═════════════════════════════════════════════════════════════════════════

extension ProfileCardsData on ProfileTrophies {
  Map<String, dynamic> get cards => j['cards'] is Map ? Map<String, dynamic>.from(j['cards'] as Map) : const {};
  String? get cardPick => cards['pick']?.toString();
  DateTime? get memberSince => DateTime.tryParse(cards['since']?.toString() ?? '');
  List<Map<String, dynamic>> get cardSports =>
      ((cards['sports'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  bool get playedFantasy => rounds > 0 || rating != null;
}

CompSport? _sportOf(String id) {
  for (final s in kCompSports) {
    if (s.id == id) return s;
  }
  return null;
}

const _months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
const _monthsAr = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];

String _posCode(String? p) => switch (p) { 'gk' => 'GK', 'def' => 'DEF', 'mid' => 'MID', 'att' => 'ATT', _ => '' };
String _posName(String? p) => switch (p) {
      'gk' => AppLang.t('Goalkeeper', 'حارس'),
      'def' => AppLang.t('Defender', 'مدافع'),
      'mid' => AppLang.t('Midfielder', 'وسط'),
      'att' => AppLang.t('Attacker', 'مهاجم'),
      _ => '',
    };

/// وش كارت عام بنفس شكل ومقاسات كارت الفانتازي (إطار + صورة + شريط تحت).
class ProfileCardFace extends StatelessWidget {
  const ProfileCardFace({super.key, required this.width, required this.frame, required this.text,
      required this.pill, this.corner, required this.main, required this.label, this.photo, this.name});
  final double width;
  final List<Color> frame;
  final Color text;
  final String pill;
  final String? corner;
  final Widget Function(double w) main; // السطر الكبير
  final String label;
  final ImageProvider? photo;
  final String? name; // في الكبير بس

  @override
  Widget build(BuildContext context) {
    final w = width, h = width * FantasyProfileCard.ratio;
    final b = (w * 0.035).clamp(2.0, 6.0).toDouble();
    final r = w * 0.12;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: w, height: h,
        padding: EdgeInsets.all(b),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: frame),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r - b),
          child: Stack(fit: StackFit.expand, children: [
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1414), Color(0xFF0B0909)],
            ))),
            Positioned(left: 0, right: 0, top: 0, height: h * 0.68,
              child: ShaderMask(
                shaderCallback: (rc) => const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.white, Colors.transparent], stops: [0, 0.68, 1],
                ).createShader(rc),
                blendMode: BlendMode.dstIn,
                child: photo != null
                    ? Image(image: photo!, fit: BoxFit.cover)
                    : Padding(
                        padding: EdgeInsets.all(w * 0.2),
                        child: Image.asset('assets/badger_white.png', color: text.withOpacity(0.55), fit: BoxFit.contain)),
              ),
            ),
            Positioned(top: h * 0.035, left: w * 0.07,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: w * 0.06, vertical: w * 0.015),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(w),
                  border: Border.all(color: text.withOpacity(0.6), width: 0.8),
                ),
                child: Text(pill, style: TextStyle(color: text, fontSize: w * 0.075,
                    fontWeight: FontWeight.w900, letterSpacing: 0.8)),
              ),
            ),
            if (corner != null && corner!.isNotEmpty)
              Positioned(top: h * 0.04, right: w * 0.08,
                child: Text(corner!, style: TextStyle(color: Colors.white, fontSize: w * 0.085,
                    fontWeight: FontWeight.w900, shadows: const [Shadow(color: Colors.black, blurRadius: 4)]))),
            Positioned(left: w * 0.06, right: w * 0.06, bottom: h * 0.04,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (name != null) ...[
                  FittedBox(fit: BoxFit.scaleDown, child: Text(name!, maxLines: 1,
                      style: TextStyle(color: Colors.white, fontSize: w * 0.09, fontWeight: FontWeight.w900))),
                  SizedBox(height: h * 0.01),
                ],
                FittedBox(fit: BoxFit.scaleDown, child: main(w)),
                SizedBox(height: h * 0.012),
                Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [
                  text.withOpacity(0), text.withOpacity(0.8), text.withOpacity(0)]))),
                SizedBox(height: h * 0.014),
                FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1,
                    style: TextStyle(color: text, fontSize: w * 0.068, fontWeight: FontWeight.w800, letterSpacing: 1))),
                if (name != null) ...[
                  SizedBox(height: h * 0.012),
                  Text('B D G R', style: TextStyle(color: text.withOpacity(0.55), fontSize: w * 0.04,
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

const _sportFrame = [Color(0xFFFF8A8A), Color(0xFF9E1B1B), Color(0xFFFF5050)];
const _sportText = Color(0xFFFFD2D2);
const _idFrame = [Color(0xFFFFFFFF), Color(0xFF8C8C8C), Color(0xFFE6E6E6)];
const _idText = Color(0xFFF2F2F2);

/// كارت رياضة: الرياضة + المركز (كورة) + عدد الماتشات (0 لحد ما البطولات تبدأ).
Widget sportProfileCard(double w, Map<String, dynamic> s, {ImageProvider? photo, String? name}) {
  final sp = _sportOf(s['id']?.toString() ?? '');
  final matches = (s['matches'] as num?)?.toInt() ?? 0;
  return ProfileCardFace(
    width: w, frame: _sportFrame, text: _sportText, photo: photo, name: name,
    pill: matches == 0 ? 'NEW' : 'PLAYER',
    corner: _posCode(s['position']?.toString()),
    main: (w) => Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(sp?.icon ?? Icons.sports, color: Colors.white, size: w * 0.12),
      SizedBox(width: w * 0.03),
      Text((sp?.en ?? 'SPORT').toUpperCase(), style: TextStyle(color: Colors.white, fontSize: w * 0.105,
          fontWeight: FontWeight.w900, height: 1)),
    ]),
    label: '$matches ${matches == 1 ? 'MATCH' : 'MATCHES'}',
  );
}

/// BDGR ID: لكل يوزر. رياضاته (أيقونات) + معانا من إمتى.
Widget idProfileCard(double w, ProfileTrophies? t, {ImageProvider? photo, String? name}) {
  final sports = t?.cardSports ?? const [];
  final since = t?.memberSince?.toLocal();
  return ProfileCardFace(
    width: w, frame: _idFrame, text: _idText, photo: photo, name: name,
    pill: 'BDGR ID',
    main: (w) => sports.isEmpty
        ? Text('🦡', style: TextStyle(fontSize: w * 0.12, height: 1))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            for (final s in sports.take(4)) Padding(
              padding: EdgeInsets.symmetric(horizontal: w * 0.015),
              child: Icon(_sportOf(s['id']?.toString() ?? '')?.icon ?? Icons.sports, color: Colors.white, size: w * 0.12)),
          ]),
    label: since == null ? 'MEMBER' : 'SINCE ${_months[since.month - 1]} ${since.year}',
  );
}

class _CardItem {
  _CardItem(this.key, this.label, this.face, this.open);
  final String key, label;
  final Widget Function(double w) face;
  final void Function() open;
}

/// كروت البروفايل بتتقلب: نفس مكان ومقاس الكارت، والكروت اللي جنبه صغيرة وباهتة.
class ProfileCardCarousel extends StatefulWidget {
  const ProfileCardCarousel({super.key, required this.width, required this.t, required this.name,
      required this.isOwner, this.photo, this.onChangePhoto});
  final double width;
  final ProfileTrophies? t;
  final String name;
  final bool isOwner;
  final ImageProvider? photo;
  final VoidCallback? onChangePhoto;

  /// ارتفاع سطر النقط تحت الكارت (بيظهر بس لو فيه أكتر من كارت)
  static const double dotsH = 20;

  /// عدد الكروت (عشان الهيدر يسيب مكان سطر النقط)
  static int count(ProfileTrophies? t) {
    if (t == null) return 1;
    return (t.playedFantasy ? 1 : 0) + t.cardSports.length + 1;
  }

  @override
  State<ProfileCardCarousel> createState() => _ProfileCardCarouselState();
}

class _ProfileCardCarouselState extends State<ProfileCardCarousel> {
  PageController? _pc;
  double _vf = 0;
  int _page = 0;
  String? _pick; // آخر اختيار (بيتحدث من غير ما نعيد تحميل)

  @override
  void initState() {
    super.initState();
    _pick = widget.t?.cardPick;
  }

  @override
  void dispose() {
    _pc?.dispose();
    super.dispose();
  }

  Future<void> _setPick(String key) async {
    await Supabase.instance.client.rpc('profile_card_pick_set', params: {'p_pick': key});
    final c = widget.t?.j['cards'];
    if (c is Map) c['pick'] = key;
    if (mounted) setState(() => _pick = key);
  }

  List<_CardItem> _items() {
    final t = widget.t;
    final photo = widget.photo;
    final owner = widget.isOwner;
    final items = <_CardItem>[];
    for (final s in t?.cardSports ?? const <Map<String, dynamic>>[]) {
      final id = s['id']?.toString() ?? '';
      final sp = _sportOf(id);
      final key = 'sport:$id';
      final teams = (s['teams'] as num?)?.toInt() ?? 0;
      final pos = _posName(s['position']?.toString());
      final hintLine = [
        if (pos.isNotEmpty) pos,
        if (teams > 0) AppLang.t('$teams team${teams == 1 ? '' : 's'}${s['captain'] == true ? ' · captain' : ''}',
            '$teams ${teams == 1 ? 'فريق' : 'فرق'}${s['captain'] == true ? ' · كابتن' : ''}'),
      ].join(' · ');
      items.add(_CardItem(key, sp?.name(AppLang.isArabic) ?? id, (w) => sportProfileCard(w, s, photo: photo), () {
        _openCardSheet(context,
            face: (w) => sportProfileCard(w, s, photo: photo, name: widget.name),
            title: '${sp?.name(AppLang.isArabic) ?? id}${s['fav'] == true ? ' ⭐' : ''}',
            titleColor: _sportText,
            hint: hintLine.isEmpty ? AppLang.t('Registered for this sport', 'مسجّل في الرياضة دي') : hintLine,
            sub: AppLang.t('Matches and stats appear after your first tournament (soon)',
                'الماتشات والإحصائيات هتظهر بعد أول بطولة (قريب)'),
            shareText: AppLang.t('My BDGR card 🦡 ${Brand.shareLinkBase}', 'كارتي في BDGR 🦡 ${Brand.shareLinkBase}'),
            onChangePhoto: owner ? widget.onChangePhoto : null,
            picked: _pick == key, onPick: owner ? () => _setPick(key) : null);
      }));
    }
    if (t == null || t.playedFantasy) {
      items.add(_CardItem('fantasy', AppLang.t('Fantasy', 'الفانتازي'),
          (w) => FantasyProfileCard(width: w, tier: t?.tier ?? 'new', rating: t?.rating, photo: photo),
          () => openProfileCardSheet(context, t: t, name: widget.name, photo: photo,
              onChangePhoto: owner ? widget.onChangePhoto : null,
              picked: _pick == 'fantasy', onPick: owner ? () => _setPick('fantasy') : null)));
    }
    if (t != null) {
      final since = t.memberSince?.toLocal();
      items.add(_CardItem('id', 'BDGR ID', (w) => idProfileCard(w, t, photo: photo), () {
        _openCardSheet(context,
            face: (w) => idProfileCard(w, t, photo: photo, name: widget.name),
            title: 'BDGR ID', titleColor: _idText,
            hint: since == null ? AppLang.t('BDGR member', 'عضو في BDGR')
                : AppLang.t('Member since ${_months[since.month - 1]} ${since.year}',
                    'معانا من ${_monthsAr[since.month - 1]} ${since.year}'),
            shareText: AppLang.t('My BDGR ID 🦡 ${Brand.shareLinkBase}', 'كارت BDGR بتاعي 🦡 ${Brand.shareLinkBase}'),
            onChangePhoto: owner ? widget.onChangePhoto : null,
            picked: _pick == 'id', onPick: owner ? () => _setPick('id') : null);
      }));
    }
    return items;
  }

  /// أول كارت يظهر: اللي صاحب البروفايل اختاره، وإلا الفانتازي لو لعب، وإلا رياضته المفضلة، وإلا BDGR ID.
  int _startIndex(List<_CardItem> items) {
    int find(bool Function(_CardItem) f) => items.indexWhere(f);
    final pick = widget.t?.cardPick;
    var i = pick == null ? -1 : find((x) => x.key == pick);
    if (i < 0) i = find((x) => x.key == 'fantasy');
    if (i < 0) i = find((x) => x.key.startsWith('sport:'));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items();
    final cw = widget.width;
    final ch = cw * FantasyProfileCard.ratio;
    if (items.length == 1) {
      return GestureDetector(onTap: items.first.open, child: Center(child: items.first.face(cw)));
    }
    return LayoutBuilder(builder: (context, c) {
      final vf = ((cw + 14) / c.maxWidth).clamp(0.1, 1.0).toDouble();
      if (_pc == null || _vf != vf) {
        final start = _pc == null ? _startIndex(items) : _page;
        _pc?.dispose();
        _pc = PageController(viewportFraction: vf, initialPage: start);
        _vf = vf;
        _page = start;
      }
      final pc = _pc!;
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: ch,
            child: PageView.builder(
              controller: pc,
              clipBehavior: Clip.none,
              itemCount: items.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => AnimatedBuilder(
                animation: pc,
                builder: (_, child) {
                  final p = pc.hasClients && pc.position.haveDimensions ? (pc.page ?? _page.toDouble()) : _page.toDouble();
                  final d = (p - i).abs().clamp(0.0, 1.0).toDouble();
                  final side = (i - p).sign; // الكروت اللي جنبه بتقرّب من النص شوية
                  return Opacity(opacity: 1 - 0.62 * d,
                      child: Transform.translate(offset: Offset(-side * d * cw * 0.14, 0),
                          child: Transform.scale(scale: 1 - 0.24 * d, child: child)));
                },
                child: GestureDetector(
                  onTap: () => i == _page
                      ? items[i].open()
                      : pc.animateToPage(i, duration: const Duration(milliseconds: 280), curve: Curves.easeOut),
                  child: Center(child: items[i].face(cw)),
                ),
              ),
            ),
          ),
          SizedBox(
            height: ProfileCardCarousel.dotsH,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < items.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: i == _page ? 14 : 5, height: 5,
                  decoration: BoxDecoration(
                    color: i == _page ? Colors.white : Colors.white24, borderRadius: BorderRadius.circular(3)),
                ),
              const SizedBox(width: 8),
              Text(items[_page.clamp(0, items.length - 1)].label,
                  style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      );
    });
  }
}

/// تاب "قريب" (المشوار / الإحصائيات) لحد ما البطولات تشتغل.
class ProfileSoonTab extends StatelessWidget {
  const ProfileSoonTab({super.key, required this.kind, this.t});
  final String kind; // career | stats
  final ProfileTrophies? t;

  @override
  Widget build(BuildContext context) {
    final career = kind == 'career';
    final sports = t?.cardSports ?? const [];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (career)
          for (final s in sports.where((s) => ((s['teams'] as num?)?.toInt() ?? 0) > 0))
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 11, height: 11, margin: const EdgeInsets.only(top: 4),
                    decoration: const BoxDecoration(color: Color(0xFFFF2B2B), shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(
                        '${_sportOf(s['id']?.toString() ?? '')?.name(AppLang.isArabic) ?? ''} · '
                        '${AppLang.t('${s['teams']} team(s)', '${s['teams']} فرق')}',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800))),
                    const SizedBox(width: 6),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF2A2A30), borderRadius: BorderRadius.circular(6)),
                        child: const Text('SELF', style: TextStyle(color: Colors.white54, fontSize: 9.5, fontWeight: FontWeight.w800))),
                  ]),
                  if (s['captain'] == true)
                    Padding(padding: const EdgeInsets.only(top: 3),
                        child: Text(AppLang.t('Captain', 'كابتن'), style: const TextStyle(color: Colors.white54, fontSize: 12))),
                ])),
              ]),
            ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: const Color(0xFF141418), borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10)),
          child: Column(children: [
            Icon(career ? Icons.timeline : Icons.bar_chart_rounded, color: Colors.white38, size: 30),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFF2A2A30), borderRadius: BorderRadius.circular(8)),
                child: Text(AppLang.t('SOON', 'قريب'),
                    style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w800))),
            const SizedBox(height: 10),
            Text(career
                ? AppLang.t('Your career: teams, academies, clubs and tournaments, verified by the organizers.',
                    'مشوارك: الفرق والأكاديميات والأندية والبطولات، ومتأكّد منها من المنظمين.')
                : AppLang.t('Matches, goals, assists and more for every season and competition.',
                    'الماتشات والأهداف والأسيستات وغيرها لكل موسم وكل بطولة.'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.45)),
          ]),
        ),
      ]),
    );
  }
}
