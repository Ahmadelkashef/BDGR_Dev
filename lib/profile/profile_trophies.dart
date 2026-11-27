import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_lang.dart';
import '../brand.dart';

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
    final rating = widget.t?.rating;
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),
          RepaintBoundary(key: _key, child: Padding(
            padding: const EdgeInsets.all(6),
            child: FantasyProfileCard(width: w, tier: tier, rating: rating, photo: widget.photo, name: widget.name),
          )),
          const SizedBox(height: 14),
          Text(AppLang.t('${tt.en} card', 'كارت ${tt.ar}'),
              style: TextStyle(color: tt.text, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(hint, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4)),
          if (rating != null) ...[
            const SizedBox(height: 10),
            Text(AppLang.t(
                'Badger Rating ${rating['rating']} · #${fmtInt((rating['rank'] as num).toInt())} of ${fmtInt((rating['players'] as num?)?.toInt() ?? 0)} · ${_arenaName(rating['arena'])}\nYour last 10 rounds',
                'تصنيف بادجر ${rating['rating']} · #${fmtInt((rating['rank'] as num).toInt())} من ${fmtInt((rating['players'] as num?)?.toInt() ?? 0)} · ${_arenaName(rating['arena'])}\nآخر 10 جولات ليك'),
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.4)),
          ],
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
