import 'dart:math' as math;
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_lang.dart';
import '../brand.dart';
import '../competitions/competition_sports.dart';
import '../local_store.dart';
import '../media_cache.dart';
import '../motion_kit.dart';
import 'trophy_cabinet.dart' show ArenaLevelCard, ArenaLevel;
import 'level_looks.dart';

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
  /// the user's login id (same id the leaderboards already show) — to open his squads
  String? get uid => j['uid']?.toString();
  /// "Complete profile" trophy: name, username, governorate (GPS), birth date all set
  /// rounds with a saved squad in an arena (LOCAL / WORLD), counted at save time
  int savedRounds(String arena) => j['saved'] is Map ? (((j['saved'] as Map)[arena] as num?)?.toInt() ?? 0) : 0;
  bool get profileComplete => j['profile'] is Map && (j['profile'] as Map)['complete'] == true;
  /// gameweeks in a row with a saved squad (Egypt or World): current run + best ever (server `_streak_of`)
  int get streakCurrent => j['streak'] is Map ? (((j['streak'] as Map)['current'] as num?)?.toInt() ?? 0) : 0;
  int get streakBest => j['streak'] is Map ? (((j['streak'] as Map)['best'] as num?)?.toInt() ?? 0) : 0;

  /// head-to-head challenges won per arena (server `_ch_wins`)
  int h2hWins(String arena) => j['h2h'] is Map ? (((j['h2h'] as Map)[arena] as num?)?.toInt() ?? 0) : 0;

  /// wins over someone he already beat before in that arena (+ rematch bonus)
  int h2hRematch(String arena) => j['h2h'] is Map && (j['h2h'] as Map)['rematch'] is Map
      ? ((((j['h2h'] as Map)['rematch'] as Map)[arena] as num?)?.toInt() ?? 0) : 0;
  /// head-to-head challenges played (finished) per arena — the trophy lights after the first one
  int h2hPlayed(String arena) => j['h2h'] is Map && (j['h2h'] as Map)['played'] is Map
      ? ((((j['h2h'] as Map)['played'] as Map)[arena] as num?)?.toInt() ?? 0) : 0;

  static Future<ProfileTrophies?> load(int userId) async {
    try {
      final r = await Supabase.instance.client.rpc('profile_trophies', params: {'p_user_id': userId});
      if (r is! Map) return null;
      final t = ProfileTrophies(Map<String, dynamic>.from(r));
      cardOn = (t.j['card'] ?? 'card') != 'circle';
      if (t.j['ui'] is Map) ProfileUi.set(Map<String, dynamic>.from(t.j['ui'] as Map));
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
        // competitions hidden → only fantasy exists, so no filter menu (kept in the code)
        if (ProfileUi.competitions) ...[_filterMenu(), const SizedBox(height: 14)] else const SizedBox(height: 4),
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
  const FantasyProfileTab({super.key, required this.t, required this.isOwner, this.onPlay, this.arena,
      this.showNumbers = true, this.onRound});
  final ProfileTrophies? t;
  final bool isOwner;
  final VoidCallback? onPlay;
  /// 'LOCAL' / 'WORLD' = one arena only (launch tabs Egypt · World); null = both (old Fantasy tab)
  final String? arena;
  /// false = the trophy cabinet shows above instead of the numbers box
  final bool showNumbers;
  /// tap a round → that user's squad in that round
  final void Function(Map<String, dynamic> round)? onRound;

  @override
  Widget build(BuildContext context) {
    final t = this.t;
    if (t == null) {
      return const Padding(padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator(color: Color(0xFFFF2B2B), strokeWidth: 2)));
    }
    final arena = this.arena;
    Map<String, dynamic>? rating = t.rating;
    var rows = t.roundsList;
    var rounds = t.rounds;
    if (arena != null) {
      rating = null;
      for (final a in t.arenaRatings) {
        if (a['arena'] == arena && a['rank'] != null) rating = a;
      }
      rows = rows.where((r) => r['arena'] == arena).toList();
      rounds = rows.length;
      if (rating == null && rows.isEmpty) return _notPlayed(arena);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!showNumbers && arena != null) ...[ArenaLevelCard(t: t, arena: arena), const SizedBox(height: 14)],
        if (showNumbers) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF141418), borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10)),
          child: Row(children: [
            Expanded(child: _num(rating != null ? '#${fmtInt((rating['rank'] as num).toInt())}' : '—',
                AppLang.t('Badger Rating', 'تصنيف بادجر') + (rating != null && arena == null ? ' · ${_arenaShort(rating['arena'])}' : ''))),
            Expanded(child: _num(rating != null ? '${rating['rating']}' : '—', AppLang.t('Rating pts', 'نقط التصنيف'))),
            Expanded(child: _num('$rounds', AppLang.t('Rounds', 'جولات'))),
          ]),
        ),
        const SizedBox(height: 6),
        Text(AppLang.t('Rating = your places in the last 10 rounds + titles', 'التصنيف = مراكزك في آخر 10 جولات + الألقاب'),
            style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
        const SizedBox(height: 16),
        ],
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
                onRound == null ? _row(rows[i])
                    : GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onRound!(rows[i]), child: _row(rows[i], tap: true)),
              ],
            ]),
          ),
      ]),
    );
  }

  /// never played this arena: a calm message (+ Play for the owner)
  Widget _notPlayed(String arena) {
    final world = arena == 'WORLD';
    final an = _arenaName(arena);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
        decoration: BoxDecoration(color: const Color(0x99141418), borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12)),
        child: Column(children: [
          Text(world ? '🌍' : '🇪🇬', style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 10),
          Text(isOwner ? AppLang.t("You haven't played $an yet", 'لسه ما لعبتش $an')
                       : AppLang.t("Hasn't played $an yet", 'لسه ما لعبش $an'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700)),
          if (isOwner && onPlay != null) ...[
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onPlay,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF0000), foregroundColor: Colors.white,
                  elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10)),
              child: Text(AppLang.t('Play $an ›', 'العب $an ›'), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _num(String v, String l) => Column(children: [
    Text(v, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
    const SizedBox(height: 2),
    Text(l, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 11)),
  ]);

  Widget _row(Map<String, dynamic> r, {bool tap = false}) {
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
        if (tap) const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
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

/// Profile look switches from the DB (`app_settings.profile_*`, owner 27 Nov: launch = fantasy only).
/// Nothing is deleted: hidden parts stay in the code and come back when the switch says show.
/// Defaults = the launch look; the last server values are kept on the phone (no jump on the next open).
class ProfileUi {
  static bool competitions = false; // sport cards + Competitions card + Career/Stats tabs + sports chips
  static bool posts = false;        // Posts tab + "+ post"
  static bool cover = false;        // cover photo (hide = soft dark top with the faint badger)
  static bool fullEdit = false;     // Edit Profile sheet (false = change photo only)
  static bool bio = false;
  static bool socials = false;
  static bool fantasyCard = false;  // the overall Fantasy card in the carousel (hide = Egypt · BADGER · World)
  static bool cardPills = false;    // NEW / EGYPT / WORLD / BADGER pills on top of the cards
  static bool ownerButtons = false; // Change photo / View as Visitor (hide = FANTASY title only; photo = camera badge)
  static bool arenaTabs = true;     // tabs = FANTASY + Egypt / World (false = old Fantasy · Trophies)
  static bool bgMotion = true;      // moving glow + sparks behind the profile (colour = card tier)
  static bool cabinet = true;       // trophy cabinet under FANTASY (hide = the old numbers box in each arena tab)
  static bool navFill = true;
  static bool levelLooks = true;    // profile look grows with the level (frame, light, sparks, chip, ring, crown…)
  static bool editPencil = true;
  static bool firstAchv = true;     // first saved squad ever → first-achievement moment (profile_first_achv)
  /// owner 28 Nov: the main number is the LEVEL; the Badger Rating rank (#1,622 of …) stays hidden (switch profile_rating_rank)
  static bool ratingRank = false;
  static bool cardRank = false;     // arena cards: show the rating rank (#1,622) instead of the level name    // pencil at the top: photo · name · username
  /// level points per trophy + level thresholds (`profile_level_pts` / `profile_level_steps`); empty = app defaults
  static Map<String, int> levelPts = const {};
  static List<int> levelSteps = const [];
  /// streak milestone → level points (`profile_streak_pts`), they add up; empty = app defaults
  static Map<int, int> streakPts = const {};
  static List<String> levelNames = const [];   // profile_level_names (English, comma list of 8)       // the strip above the bottom bar takes the profile colour (no 2-colour line)
  static final ValueNotifier<int> changes = ValueNotifier(0);

  static void set(Map<String, dynamic> m, {bool save = true}) {
    bool on(String k, bool d) => m[k] == null ? d : m[k].toString() == 'show';
    competitions = on('competitions', competitions);
    posts = on('posts', posts);
    cover = on('cover', cover);
    fullEdit = m['edit'] == null ? fullEdit : m['edit'].toString() == 'full';
    bio = on('bio', bio);
    socials = on('socials', socials);
    fantasyCard = on('fantasy_card', fantasyCard);
    cardPills = on('card_pills', cardPills);
    ownerButtons = on('owner_buttons', ownerButtons);
    arenaTabs = m['tabs'] == null ? arenaTabs : m['tabs'].toString() == 'arena';
    bgMotion = on('bg_motion', bgMotion);
    navFill = on('nav_fill', navFill);
    cabinet = on('cabinet', cabinet);
    levelLooks = on('level_looks', levelLooks);
    editPencil = on('edit_pencil', editPencil);
    firstAchv = on('first_achv', firstAchv);
    cardRank = on('card_rank', cardRank);
    ratingRank = on('rating_rank', ratingRank);
    try {
      final lp = m['level_pts'];
      if (lp is String && lp.isNotEmpty) {
        levelPts = (jsonDecode(lp) as Map).map((k, v) => MapEntry('$k', (v as num).toInt()));
      }
      final ls = m['level_steps'];
      if (ls is String && ls.isNotEmpty) levelSteps = (jsonDecode(ls) as List).map((v) => (v as num).toInt()).toList();
      final sp = m['streak_pts'];
      if (sp is String && sp.isNotEmpty) {
        streakPts = (jsonDecode(sp) as Map).map((k, v) => MapEntry(int.parse('$k'), (v as num).toInt()));
      }
      final ln = m['level_names'];
      if (ln is String && ln.isNotEmpty) levelNames = ln.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    } catch (_) {}
    changes.value++;
    if (save) LocalStore.setStr('profile_ui', jsonEncode(m));
  }

  static bool _warmed = false;
  static Future<void> warm() async {
    if (_warmed) return;
    _warmed = true;
    try {
      final s = await LocalStore.getStr('profile_ui');
      if (s != null) set(Map<String, dynamic>.from(jsonDecode(s) as Map), save: false);
    } catch (_) {}
  }
}

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
      required this.pill, this.corner, required this.main, required this.label, this.photo, this.name, this.bg});
  final double width;
  final List<Color> frame;
  final Color text;
  final String pill;
  final String? corner;
  final Widget Function(double w) main; // السطر الكبير
  final String label;
  final ImageProvider? photo;
  final String? name; // في الكبير بس
  final ImageProvider? bg; // صورة اللعبة (الكارت كله، من غير صورة اليوزر)

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
            if (bg != null) ...[
              Image(image: bg!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.15), Colors.black.withOpacity(0.35), Colors.black.withOpacity(0.88)],
                stops: const [0, 0.45, 1],
              ))),
            ] else
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
            if (ProfileUi.cardPills && pill.isNotEmpty)
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

const _kFantasyImg = 'https://huggingface.co/datasets/Meekkii/IPLAY/resolve/main/Images/Fantasy';

/// صورة اللعبة (Hugging Face، بتتحفظ على الموبايل، ومتصغّرة عشان الذاكرة).
ImageProvider _bgImage(String url) => ResizeImage(MediaCache.image(url), width: 360, policy: ResizeImagePolicy.fit);
ImageProvider? _sportBg(String id) {
  final sp = _sportOf(id);
  return sp == null ? null : _bgImage(sp.imageUrl);
}
ImageProvider _arenaBg(dynamic arena) => _bgImage('$_kFantasyImg/${arena == 'WORLD' ? 'World' : 'Local'}.jpg');

Widget _iconTitle(double w, IconData icon, String title) => Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white, size: w * 0.12),
      SizedBox(width: w * 0.03),
      Text(title, style: TextStyle(color: Colors.white, fontSize: w * 0.105, fontWeight: FontWeight.w900, height: 1)),
    ]);

Widget _rankLine(double w, int rank, String tag, Color c) => Row(mainAxisSize: MainAxisSize.min, children: [
      Text('#${fmtInt(rank)}', style: TextStyle(color: Colors.white, fontSize: w * 0.15, fontWeight: FontWeight.w900, height: 1)),
      SizedBox(width: w * 0.03),
      Text(tag, style: TextStyle(color: c, fontSize: w * 0.075, fontWeight: FontWeight.w900)),
    ]);

/// الكارت الأساسي BADGER: صورة اليوزر + رياضاته + معانا من إمتى. لكل الناس.
Widget badgerProfileCard(double w, ProfileTrophies? t, {ImageProvider? photo, String? name, List<Color>? frame}) {
  final sports = ProfileUi.competitions ? (t?.cardSports ?? const []) : const <Map<String, dynamic>>[];
  final since = t?.memberSince?.toLocal();
  return ProfileCardFace(
    width: w, frame: frame ?? _idFrame, text: _idText, photo: photo, name: name,
    pill: 'BADGER',
    main: (w) => sports.isEmpty
        ? Image.asset('assets/badger_white.png', height: w * 0.13)
        : Row(mainAxisSize: MainAxisSize.min, children: [
            for (final s in sports.take(4)) Padding(
              padding: EdgeInsets.symmetric(horizontal: w * 0.015),
              child: Icon(_sportOf(s['id']?.toString() ?? '')?.icon ?? Icons.sports, color: Colors.white, size: w * 0.12)),
          ]),
    label: since == null ? 'MEMBER' : 'SINCE ${_months[since.month - 1]} ${since.year}',
  );
}

/// كارت رياضة: صورة الرياضة + المركز (كورة) + عدد الماتشات (0 لحد ما البطولات تبدأ).
Widget sportProfileCard(double w, Map<String, dynamic> s, {String? name}) {
  final id = s['id']?.toString() ?? '';
  final sp = _sportOf(id);
  final matches = (s['matches'] as num?)?.toInt() ?? 0;
  return ProfileCardFace(
    width: w, frame: _sportFrame, text: _sportText, bg: _sportBg(id), name: name,
    pill: matches == 0 ? 'NEW' : 'PLAYER',
    corner: _posCode(s['position']?.toString()),
    main: (w) => _iconTitle(w, sp?.icon ?? Icons.sports, (sp?.en ?? 'SPORT').toUpperCase()),
    label: '$matches ${matches == 1 ? 'MATCH' : 'MATCHES'}',
  );
}

/// المسابقات (رانك عام): لسه مفيش بطولات → NEW + "SOON".
Widget competitionsProfileCard(double w, ProfileTrophies t, {String? name}) {
  final fav = t.cardSports.isEmpty ? null : t.cardSports.first['id']?.toString();
  return ProfileCardFace(
    width: w, frame: _sportFrame, text: _sportText, bg: fav == null ? null : _sportBg(fav), name: name,
    pill: 'NEW',
    main: (w) => _iconTitle(w, Icons.emoji_events, 'COMPETITIONS'),
    label: 'RANK · SOON',
  );
}

/// الفانتازي (رانك عام = الأحسن بين مصر والعالم).
Widget fantasyOverallCard(double w, ProfileTrophies t, {String? name}) {
  final tt = _tierOf(t.tier);
  final r = t.rating;
  final rank = (r?['rank'] as num?)?.toInt();
  return ProfileCardFace(
    width: w, frame: tt.colors, text: tt.text, bg: _arenaBg(r?['arena']), name: name,
    pill: tt.en,
    main: (w) => rank == null
        ? _iconTitle(w, Icons.sports_soccer, 'FANTASY')
        : _rankLine(w, rank, _arenaShort(r?['arena']), tt.text),
    label: rank == null ? 'FANTASY' : 'FANTASY RATING',
  );
}

/// أرينا لوحدها (مصر / العالم).
Widget fantasyArenaCard(double w, ProfileTrophies t, Map<String, dynamic> a, {String? name}) {
  final tt = _tierOf(t.tier);
  final rank = (a['rank'] as num?)?.toInt();
  final world = a['arena'] == 'WORLD';
  return ProfileCardFace(
    width: w, frame: tt.colors, text: tt.text, bg: _arenaBg(a['arena']), name: name,
    pill: world ? 'WORLD' : 'EGYPT',
    main: (w) => rank == null
        ? Text('—', style: TextStyle(color: Colors.white, fontSize: w * 0.15, fontWeight: FontWeight.w900, height: 1))
        // owner 28 Nov: the LEVEL name big on the card (the rank lives in the spotlight); switch profile_card_rank
        : ProfileUi.cabinet && !ProfileUi.cardRank ? () {
            final lv = ArenaLevel.of(t, '${a['arena']}');
            return Text(lv.name.toUpperCase(), maxLines: 1,
                style: TextStyle(color: lv.color, fontSize: w * 0.12, fontWeight: FontWeight.w900, height: 1, letterSpacing: 0.5,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 6)]));
          }()
        : ProfileUi.cardPills ? _rankLine(w, rank, world ? '🌍' : 'EG', tt.text)
        : Text('#${fmtInt(rank)}', style: TextStyle(color: Colors.white, fontSize: w * 0.15, fontWeight: FontWeight.w900, height: 1)),
    // launch (owner 28 Nov): the arena LEVEL under the rank (cabinet on); old = rating pts · rounds
    label: rank == null ? 'NOT PLAYED'
        : ProfileUi.cabinet && !ProfileUi.cardRank ? '${fmtInt(ArenaLevel.of(t, '${a['arena']}').points)} PTS'
        : ProfileUi.cabinet ? ArenaLevel.of(t, '${a['arena']}').name.toUpperCase()
        : '${a['rating'] ?? 0} PTS · ${a['rounds'] ?? 0} GW',
  );
}

extension ProfileRatingsData on ProfileTrophies {
  List<Map<String, dynamic>> get arenaRatings =>
      ((j['ratings'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

String _fantasyHint(ProfileTrophies t) {
  final rounds = t.rounds;
  return switch (t.tier) {
    'new' => AppLang.t('Play ${3 - rounds.clamp(0, 3)} more round(s) to get your Bronze card',
        'العب ${3 - rounds.clamp(0, 3)} جولة كمان وكارتك يبقى برونز'),
    'bronze' => AppLang.t('Finish in the top 10% of a round → Silver', 'ادخل التوب 10% في جولة → فضة'),
    'silver' => AppLang.t('Top 3 in a round, or win a cup or the Badger League → Gold',
        'توب 3 في جولة، أو اكسب كاس أو دوري بادجر → دهب'),
    _ => AppLang.t('The highest level. Keep it 🔥', 'أعلى مستوى. حافظ عليه 🔥'),
  };
}

class _CardItem {
  _CardItem(this.label, this.face, this.open, {this.wrap});
  final String label;
  final Widget Function(double w) face;
  final void Function() open;
  /// extra things around the card that move with it (level ring / crown / rays)
  Widget Function(Widget card, double w)? wrap;
  /// false = no holo shine (low levels)
  bool shine = true;
}

/// كروت البروفايل (PROFILE v3, 27 نوفمبر): نفس مكان ومقاس الكارت.
/// النص = BADGER (لكل الناس، بيفتح عليه دايماً). شمال = المسابقات (رانك عام) ثم كل رياضة،
/// يمين = الفانتازي (رانك عام) ثم كل أرينا. صورة اليوزر في BADGER بس، والباقي خلفيته صورة اللعبة.
/// الكروت اللي جنبه أصغر وباهتة.
class ProfileCardCarousel extends StatefulWidget {
  const ProfileCardCarousel({super.key, required this.width, required this.t, required this.name,
      required this.isOwner, this.photo, this.onChangePhoto, this.onRound});
  final double width;
  /// a round line in the arena spotlight → that user's squad in that round
  final void Function(Map<String, dynamic> round)? onRound;
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
    final sports = ProfileUi.competitions ? t.cardSports.length : 0;
    final fantasy = !ProfileUi.fantasyCard ? 2 : t.playedFantasy ? 1 + t.arenaRatings.length : 0;
    return 1 + (sports > 0 ? sports + 1 : 0) + fantasy;
  }

  @override
  State<ProfileCardCarousel> createState() => _ProfileCardCarouselState();
}

class _ProfileCardCarouselState extends State<ProfileCardCarousel> {
  PageController? _pc;
  double _vf = 0;
  int _page = 0;
  int _center = 0;
  bool _entering = true; // the cards rise in once when the page opens
  /// launch trio (owner 28 Nov): 3 fixed spots; slot → card index. Tap a side card = it swaps with the middle one.
  List<int> _order = const [0, 1, 2];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1100), () { if (mounted) setState(() => _entering = false); });
  }

  @override
  void dispose() {
    _pc?.dispose();
    super.dispose();
  }

  void _swap(int slot) {
    if (slot == 1) return;
    Buzz.tap();
    setState(() {
      final o = [..._order];
      final t = o[slot];
      o[slot] = o[1];
      o[1] = t;
      _order = o;
    });
  }

  /// Egypt · [BADGER] · World: always 3 cards, the chosen one in the middle, the middle one takes its place.
  Widget _trio(List<_CardItem> items, double cw, double ch) => LayoutBuilder(builder: (context, c) {
    final w = c.maxWidth;
    final dx = cw * 0.86 + 14;
    _page = _order[1];
    const dur = Duration(milliseconds: 380);
    Widget slot(int s) {
      final i = _order[s];
      final mid = s == 1;
      return AnimatedPositioned(
        key: ValueKey('trio-$i'),
        duration: dur, curve: Curves.easeOutCubic,
        left: w / 2 - cw / 2 + (s - 1) * dx, top: 0, width: cw, height: ch,
        child: AnimatedScale(
          scale: mid ? 1 : 0.76, duration: dur, curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: mid ? 1 : 0.5, duration: dur,
            child: GestureDetector(
              // owner 28 Nov: cards never move; a side card opens its big spotlight in the middle of the screen
              onTap: () => items[i].open(),
              child: _faceAt(items, i, cw),
            ),
          ),
        ),
      );
    }
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          child: SizedBox(height: ch, width: w, child: Stack(clipBehavior: Clip.none, children: [
            slot(0), slot(2), slot(1), // middle painted last = on top
          ])),
        ),
        SizedBox(
          height: ProfileCardCarousel.dotsH,
          child: Center(child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(items[_order[1]].label, key: ValueKey(_order[1]),
                style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
          )),
        ),
      ]),
    );
  });

  Widget _faceAt(List<_CardItem> items, int i, double cw) {
    final gold = widget.t?.tier == 'gold';
    Widget f = HoloCard(
      key: ValueKey('holo-$i'),
      enabled: i == _page && items[i].shine,
      radius: cw * 0.12,
      strength: gold ? 1.5 : 1,
      child: items[i].face(cw),
    );
    if (items[i].wrap != null) f = items[i].wrap!(f, cw);
    if (_entering && (i - _center).abs() <= 1) {
      f = CardEntrance(
        fromSide: (i - _center).sign.toDouble(),
        delayMs: i == _center ? 60 : 260,
        child: f,
      );
    }
    return f;
  }

  String get _share => AppLang.t('My BDGR card 🦡 ${Brand.shareLinkBase}', 'كارتي في BDGR 🦡 ${Brand.shareLinkBase}');

  void _sheet(Widget Function(double w) face, String title, Color c, String hint, {String? sub, bool photo = false}) {
    _openCardSheet(context, face: face, title: title, titleColor: c, hint: hint, sub: sub, shareText: _share,
        onChangePhoto: photo && widget.isOwner ? widget.onChangePhoto : null);
  }

  List<_CardItem> _items() {
    final t = widget.t;
    final name = widget.name;
    final left = <_CardItem>[];
    final right = <_CardItem>[];
    if (t != null) {
      // ── المسابقات: الرانك العام جنب BADGER، وبعده كل رياضة (المفضلة الأقرب)
      final sports = ProfileUi.competitions ? t.cardSports : const <Map<String, dynamic>>[];
      if (sports.isNotEmpty) {
        left.add(_CardItem(AppLang.t('Competitions', 'المسابقات'), (w) => competitionsProfileCard(w, t), () => _sheet(
            (w) => competitionsProfileCard(w, t, name: name), AppLang.t('Competitions', 'المسابقات'), _sportText,
            AppLang.t('Your overall rank across all your sports', 'رانكك العام في كل رياضاتك'),
            sub: AppLang.t('Starts with the first tournament (soon)', 'هيبدأ مع أول بطولة (قريب)'))));
        for (final s in sports) {
          final id = s['id']?.toString() ?? '';
          final sp = _sportOf(id);
          final teams = (s['teams'] as num?)?.toInt() ?? 0;
          final pos = _posName(s['position']?.toString());
          final hint = [
            if (pos.isNotEmpty) pos,
            if (teams > 0) AppLang.t('$teams team${teams == 1 ? '' : 's'}${s['captain'] == true ? ' · captain' : ''}',
                '$teams ${teams == 1 ? 'فريق' : 'فرق'}${s['captain'] == true ? ' · كابتن' : ''}'),
          ].join(' · ');
          final title = '${sp?.name(AppLang.isArabic) ?? id}${s['fav'] == true ? ' ⭐' : ''}';
          left.add(_CardItem(sp?.name(AppLang.isArabic) ?? id, (w) => sportProfileCard(w, s), () => _sheet(
              (w) => sportProfileCard(w, s, name: name), title, _sportText,
              hint.isEmpty ? AppLang.t('Registered for this sport', 'مسجّل في الرياضة دي') : hint,
              sub: AppLang.t('Matches and stats appear after your first tournament (soon)',
                  'الماتشات والإحصائيات هتظهر بعد أول بطولة (قريب)'))));
        }
      }
      // ── launch (owner 27 Nov): Egypt on the left, World on the right, always (not played = "—")
      if (!ProfileUi.fantasyCard) {
        final tt = _tierOf(t.tier);
        for (final arena in const ['LOCAL', 'WORLD']) {
          final a = t.arenaRatings.firstWhere((x) => x['arena'] == arena, orElse: () => <String, dynamic>{'arena': arena});
          final an = _arenaName(arena);
          final played = a['rank'] != null;
          (arena == 'LOCAL' ? left : right).add(_CardItem(an, (w) => fantasyArenaCard(w, t, a), ProfileUi.cabinet
              ? () => _openSpotlight(context, t: t, arena: arena, a: a, isOwner: widget.isOwner, onRound: widget.onRound,
                  fromLeft: arena == 'LOCAL')
              : () => _sheet(
              (w) => fantasyArenaCard(w, t, a, name: name), AppLang.t('Fantasy · $an', 'الفانتازي · $an'), tt.text,
              played
                  ? AppLang.t('#${fmtInt((a['rank'] as num?)?.toInt() ?? 0)} of ${fmtInt((a['players'] as num?)?.toInt() ?? 0)} · ${a['rounds'] ?? 0} rounds',
                      '#${fmtInt((a['rank'] as num?)?.toInt() ?? 0)} من ${fmtInt((a['players'] as num?)?.toInt() ?? 0)} · ${a['rounds'] ?? 0} جولة')
                  : AppLang.t('No $an rounds yet', 'لسه ما لعبش $an'),
              sub: played ? AppLang.t('Badger Rating ${a['rating'] ?? 0} = your last 10 rounds',
                  'تصنيف بادجر ${a['rating'] ?? 0} = آخر 10 جولات ليك') : null)));
        }
      } else
      // ── الفانتازي: الرانك العام جنب BADGER، وبعده كل أرينا
      if (t.playedFantasy) {
        final tt = _tierOf(t.tier);
        final r = t.rating;
        // competitions hidden → Fantasy sits on the left so BADGER keeps cards on both sides
        (ProfileUi.competitions ? right : left).add(_CardItem(AppLang.t('Fantasy', 'الفانتازي'), (w) => fantasyOverallCard(w, t), () => _sheet(
            (w) => fantasyOverallCard(w, t, name: name), AppLang.t('${tt.en} card', 'كارت ${tt.ar}'), tt.text,
            _fantasyHint(t),
            sub: r == null ? null : AppLang.t(
                'Badger Rating ${r['rating']} · #${fmtInt((r['rank'] as num).toInt())} of ${fmtInt((r['players'] as num?)?.toInt() ?? 0)} · ${_arenaName(r['arena'])}\nYour last 10 rounds',
                'تصنيف بادجر ${r['rating']} · #${fmtInt((r['rank'] as num).toInt())} من ${fmtInt((r['players'] as num?)?.toInt() ?? 0)} · ${_arenaName(r['arena'])}\nآخر 10 جولات ليك'))));
        for (final a in t.arenaRatings) {
          final an = _arenaName(a['arena']);
          right.add(_CardItem(an, (w) => fantasyArenaCard(w, t, a), () => _sheet(
              (w) => fantasyArenaCard(w, t, a, name: name), AppLang.t('Fantasy · $an', 'الفانتازي · $an'), tt.text,
              AppLang.t('#${fmtInt((a['rank'] as num?)?.toInt() ?? 0)} of ${fmtInt((a['players'] as num?)?.toInt() ?? 0)} · ${a['rounds'] ?? 0} rounds',
                  '#${fmtInt((a['rank'] as num?)?.toInt() ?? 0)} من ${fmtInt((a['players'] as num?)?.toInt() ?? 0)} · ${a['rounds'] ?? 0} جولة'),
              sub: AppLang.t('Badger Rating ${a['rating'] ?? 0} = your last 10 rounds',
                  'تصنيف بادجر ${a['rating'] ?? 0} = آخر 10 جولات ليك'))));
        }
      }
    }
    final since = t?.memberSince?.toLocal();
    final sportNames = (!ProfileUi.competitions ? const <Map<String, dynamic>>[] : t?.cardSports ?? const []).map((s) => _sportOf(s['id']?.toString() ?? '')?.name(AppLang.isArabic))
        .whereType<String>().join(' · ');
    final look = LevelLook.of(t);
    final lf = ProfileUi.levelLooks ? look.frame : null;
    final badger = _CardItem('BADGER', (w) => badgerProfileCard(w, t, photo: widget.photo, frame: lf), () => _sheet(
        (w) => badgerProfileCard(w, t, photo: widget.photo, name: name, frame: lf), 'BADGER', _idText,
        since == null ? AppLang.t('BDGR member', 'عضو في BDGR')
            : AppLang.t('Member since ${_months[since.month - 1]} ${since.year}', 'معانا من ${_monthsAr[since.month - 1]} ${since.year}'),
        sub: sportNames.isEmpty ? null : sportNames, photo: true));
    if (ProfileUi.levelLooks) {
      badger.shine = look.shine;
      badger.wrap = (card, w) => LevelDecor(look: look, width: w, child: card);
    }
    _center = left.length;
    return [...left.reversed, badger, ...right];
  }

  @override
  Widget build(BuildContext context) {
    final items = _items();
    final cw = widget.width;
    final ch = cw * FantasyProfileCard.ratio;
    if (items.length == 1) {
      return GestureDetector(onTap: items.first.open, child: Center(child: _faceAt(items, 0, cw)));
    }
    if (items.length == 3 && !ProfileUi.fantasyCard) return _trio(items, cw, ch);
    return LayoutBuilder(builder: (context, c) {
      final vf = ((cw + 14) / c.maxWidth).clamp(0.1, 1.0).toDouble();
      if (_pc == null || _vf != vf) {
        final start = _pc == null ? _center : _page;
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
              onPageChanged: (i) { Buzz.tap(); setState(() => _page = i); },
              itemBuilder: (_, i) => AnimatedBuilder(
                animation: pc,
                builder: (_, child) {
                  final p = pc.hasClients && pc.position.haveDimensions ? (pc.page ?? _page.toDouble()) : _page.toDouble();
                  final d = (p - i).abs().clamp(0.0, 1.0).toDouble();
                  final side = (i - p).sign; // الكروت اللي جنبه بتقرّب من النص شوية
                  return Opacity(opacity: 1 - 0.5 * d,
                      child: Transform.translate(offset: Offset(-side * d * cw * 0.14, 0),
                          child: Transform.scale(scale: 1 - 0.24 * d, child: child)));
                },
                child: GestureDetector(
                  onTap: () => i == _page
                      ? items[i].open()
                      : pc.animateToPage(i, duration: const Duration(milliseconds: 280), curve: Curves.easeOut),
                  child: Center(child: _faceAt(items, i, cw)),
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
                    color: i == _page ? Colors.white : (i == _center ? Colors.white54 : Colors.white24),
                    borderRadius: BorderRadius.circular(3)),
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


// ═════════════════════════════════════════════════════════════════════════
// لحظة الترقية (27 نوفمبر، موشن المرحلة ١): لما كارت الفانتازي يطلع مستوى (new → bronze → silver → gold)
// صاحب البروفايل يشوفها مرة واحدة: الكارت القديم يلف ويقلب للجديد وينوّر.
// آخر مستوى اتشاف محفوظ على الموبايل (`card_tier_seen`). أول مرة = بيتحفظ من غير ما يظهر حاجة.
// ═════════════════════════════════════════════════════════════════════════
const _tierOrder = ['new', 'bronze', 'silver', 'gold'];

Future<void> maybeShowTierUp(BuildContext context, ProfileTrophies t) async {
  if (!t.playedFantasy) return;
  final now = t.tier;
  final seen = await LocalStore.getStr('card_tier_seen');
  await LocalStore.setStr('card_tier_seen', now);
  if (seen == null || !context.mounted) return;
  if (_tierOrder.indexOf(now) <= _tierOrder.indexOf(seen)) return;
  final old = ProfileTrophies({...t.j, 'tier': seen});
  await showGeneralDialog(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'tier',
    barrierColor: Colors.black.withOpacity(0.85),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, __, ___) => _TierUpView(old: old, now: t),
  );
}

class _TierUpView extends StatefulWidget {
  const _TierUpView({required this.old, required this.now});
  final ProfileTrophies old, now;
  @override
  State<_TierUpView> createState() => _TierUpViewState();
}

class _TierUpViewState extends State<_TierUpView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  bool _buzzed = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (!_buzzed && _c.value > 0.55) { _buzzed = true; Buzz.medium(); }
    });
    Future.delayed(const Duration(milliseconds: 350), () { if (mounted) _c.forward(); });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.of(context).size.width * 0.56).clamp(170.0, 240.0).toDouble();
    final tt = _tierOf(widget.now.tier);
    final calm = calmMotion(context);
    return Material(
      type: MaterialType.transparency,
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final v = calm ? 1.0 : _c.value;
            // 0 → 0.55: spins (2 turns, slows down) · old card until half way, then the new one
            final spin = Curves.easeOutCubic.transform((v / 0.55).clamp(0.0, 1.0).toDouble());
            final angle = spin * math.pi * 4;
            final showNew = spin > 0.5;
            final glow = v < 0.55 ? 0.0 : math.sin(((v - 0.55) / 0.45).clamp(0.0, 1.0).toDouble() * math.pi);
            final face = fantasyOverallCard(w, showNew ? widget.now : widget.old);
            return Stack(alignment: Alignment.center, children: [
              // light burst behind the card
              Container(
                width: w * 1.9, height: w * 1.9,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [
                  tt.text.withOpacity(0.55 * glow), tt.text.withOpacity(0)])),
              ),
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..setEntry(3, 2, 0.0015)..rotateY(angle),
                child: Transform.scale(scale: 1 + 0.08 * glow, child: face),
              ),
            ]);
          },
        ),
        const SizedBox(height: 26),
        AnimatedBuilder(
          animation: _c,
          builder: (_, child) => Opacity(opacity: calm ? 1 : ((_c.value - 0.6) / 0.3).clamp(0.0, 1.0).toDouble(), child: child),
          child: Column(children: [
            Text(AppLang.t('Your card is now ${tt.en}!', 'كارتك بقى ${tt.ar}!'),
                style: TextStyle(color: tt.text, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(_fantasyHint(widget.now), textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4)),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF0000), foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(AppLang.t('Nice!', 'حلو!'), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      ])),
    );
  }
}


/// Arena spotlight (owner 28 Nov): tap EGYPT / WORLD → the card grows into the middle of the screen with
/// the user's level, rank, highlights in that arena and the last round (tap = his squad). ✕ = back, nothing moves.
void _openSpotlight(BuildContext context, {required ProfileTrophies t, required String arena,
    required Map<String, dynamic> a, required bool isOwner, required bool fromLeft,
    void Function(Map<String, dynamic>)? onRound}) {
  Buzz.tap();
  showGeneralDialog(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'arena',
    barrierColor: Colors.black.withOpacity(0.82),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, _, __) => _ArenaSpotlight(t: t, arena: arena, a: a, isOwner: isOwner, onRound: onRound),
    transitionBuilder: (ctx, anim, _, child) {
      final c = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return FadeTransition(opacity: c, child: ScaleTransition(
        scale: Tween(begin: 0.55, end: 1.0).animate(c),
        alignment: Alignment(fromLeft ? -0.6 : 0.6, -0.55), // grows out of its spot
        child: child,
      ));
    },
  );
}

class _ArenaSpotlight extends StatelessWidget {
  const _ArenaSpotlight({required this.t, required this.arena, required this.a, required this.isOwner, this.onRound});
  final ProfileTrophies t;
  final String arena;
  final Map<String, dynamic> a;
  final bool isOwner;
  final void Function(Map<String, dynamic>)? onRound;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final cw = (mq.size.width * 0.42).clamp(140.0, 190.0).toDouble();
    final an = _arenaName(arena);
    final rows = t.roundsList.where((r) => r['arena'] == arena).toList();
    final played = rows.isNotEmpty || a['rank'] != null;
    final last = rows.isEmpty ? null : rows.first; // newest first
    int ri(dynamic v) => v is num ? v.toInt() : 0;
    double rd(dynamic v) => v is num ? v.toDouble() : 1;
    num? bestPts;
    int? bestRank;
    var podium = 0, top10 = 0;
    for (final r in rows) {
      final p = r['points'];
      if (p is num && (bestPts == null || p > bestPts)) bestPts = p;
      final k = ri(r['rank']);
      if (k > 0 && (bestRank == null || k < bestRank)) bestRank = k;
      if (k > 0 && k <= 3) podium++;
      if (k > 3 && rd(r['pct']) <= 0.10) top10++;
    }
    String pts(num? p) => p == null ? '—' : (p == p.roundToDouble() ? '${p.toInt()}' : '$p');
    Widget stat(String v, String l) => Expanded(child: Column(children: [
      Text(v, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
      const SizedBox(height: 2),
      Text(l, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
    ]));
    return SafeArea(child: Material(
      type: MaterialType.transparency,
      child: Center(child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: mq.size.height * 0.9),
        child: Stack(children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 44, 18, 18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: fantasyArenaCard(cw, t, a)),
              const SizedBox(height: 10),
              Text(AppLang.t('Fantasy · $an', 'الفانتازي · $an'), textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              if (!played)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: const Color(0xFF16171B), borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12)),
                  child: Text(isOwner ? AppLang.t("You haven't played $an yet", 'لسه ما لعبتش $an')
                                      : AppLang.t("Hasn't played $an yet", 'لسه ما لعبش $an'),
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                )
              else ...[
                ArenaLevelCard(t: t, arena: arena),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  decoration: BoxDecoration(color: const Color(0xFF16171B), borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12)),
                  child: Row(children: [
                    if (ProfileUi.ratingRank)
                      stat(a['rank'] == null ? '—' : '#${fmtInt(ri(a['rank']))}',
                          AppLang.t('Rank of ${fmtInt(ri(a['players']))}', 'الترتيب من ${fmtInt(ri(a['players']))}')),
                    stat(bestRank == null ? '—' : '#${fmtInt(bestRank)}', AppLang.t('Best round', 'أحسن جولة')),
                    stat(pts(bestPts), AppLang.t('Best points', 'أعلى نقط')),
                    stat('${rows.length}', AppLang.t('Rounds', 'جولات')),
                  ]),
                ),
                if (podium + top10 > 0) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    if (podium > 0) Expanded(child: _chip('🏆', AppLang.t('Top 3 ×$podium', 'توب 3 ×$podium'))),
                    if (podium > 0 && top10 > 0) const SizedBox(width: 8),
                    if (top10 > 0) Expanded(child: _chip('⭐', AppLang.t('Top 10% ×$top10', 'توب 10% ×$top10'))),
                  ]),
                ],
                if (last != null) ...[
                  const SizedBox(height: 14),
                  Text(AppLang.t('LAST ROUND', 'آخر جولة'), style: const TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.5)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onRound == null ? null : () { Navigator.of(context).pop(); onRound!(last); },
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                      decoration: BoxDecoration(color: const Color(0xFF1F2026), borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12)),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(AppLang.t('${last['name_en'] ?? ''}', '${last['name_ar'] ?? ''}'),
                              style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(AppLang.t('#${fmtInt(ri(last['rank']))} of ${fmtInt(ri(last['players']))}',
                              '#${fmtInt(ri(last['rank']))} من ${fmtInt(ri(last['players']))}'),
                              style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ])),
                        Text(AppLang.t('${pts(last['points'] as num?)} pts', '${pts(last['points'] as num?)} نقطة'),
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                        if (onRound != null) ...[
                          const SizedBox(width: 6),
                          Text(AppLang.t('Squad', 'التشكيلة'), style: const TextStyle(color: Color(0xFFFF4D4D), fontSize: 12, fontWeight: FontWeight.w800)),
                          const Icon(Icons.chevron_right, color: Color(0xFFFF4D4D), size: 18),
                        ],
                      ]),
                    ),
                  ),
                ],
              ],
            ]),
          ),
          Positioned(top: 0, right: 8, child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Container(width: 34, height: 34,
                decoration: BoxDecoration(color: Colors.white12, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                child: const Icon(Icons.close, color: Colors.white, size: 18)),
          )),
        ]),
      )),
    ));
  }

  Widget _chip(String icon, String text) => Container(
    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
    decoration: BoxDecoration(color: const Color(0xFF1F1A10), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x55E6B649))),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(icon, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 6),
      Flexible(child: Text(text, style: const TextStyle(color: Color(0xFFFFD27A), fontSize: 12.5, fontWeight: FontWeight.w800))),
    ]),
  );
}
