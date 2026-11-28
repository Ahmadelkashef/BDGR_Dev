import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../ads/ad_widgets.dart';
import '../app_config.dart';
import '../app_lang.dart';
import '../brand.dart';
import '../fantasy.dart' show FantasyLangToggle, cardBg, brandRed, surface2, muted, line;
import 'badger_card.dart';
import 'teams/team_pages.dart';
import 'competition_sports.dart';

/// صفحة المسابقات: تسجيل اهتمام بس.
/// اليوزر يختار الألعاب اللي عايز ينافس فيها ويدوس "سجّلني"، وده بيتحفظ في
/// competition_interest (RPC competition_set_interests). الأعداد بتتشاف من
/// mgmt_competition_interest_stats في الداشبورد.
///
/// الترتيب مهم: أول لعبة في _picked هي "المفضلة" (pick_order = 1 في الداتابيز)،
/// والباقي "اهتمامات تانية" بترتيب ما اتعلّموا. لو شال المفضلة، اللي بعدها تطلع
/// مكانها. "تعديل المفضلة" بيطلّع أي لعبة أول القايمة والقديمة تنزل تانية.

const Color _gold = Color(0xFFFFD54F);

/// DB switches for the competitions page (`competition_ui()`); teams hidden until the owner shows them.
class CompUi {
  CompUi._();
  /// `app_settings.competition_teams` = show | hide (default hide): team hub, captain / join, team links
  static bool teams = false;
  static Future<void> load() async {
    try {
      final r = await supa.rpc('competition_ui');
      if (r is Map) teams = r['teams']?.toString() == 'show';
    } catch (_) {}
  }
}

class CompetitionsPage extends StatefulWidget {
  const CompetitionsPage({super.key});

  @override
  State<CompetitionsPage> createState() => _CompetitionsPageState();
}

class _CompetitionsPageState extends State<CompetitionsPage> {
  bool _ar = AppLang.isArabic;
  bool _loading = true;
  bool _saving = false;
  List<String> _saved = [];     // المتسجل فعلاً في الداتابيز (بالترتيب)
  List<String> _picked = [];    // اختيار اليوزر دلوقتي (الأولى = المفضلة)

  String t(String en, String ar) => _ar ? ar : en;

  bool get _dirty => _picked.join(',') != _saved.join(',');

  CompSport? _sport(String id) {
    for (final s in kCompSports) { if (s.id == id) return s; }
    return null;
  }

  @override
  void initState() {
    super.initState();
    competitionPreselect.addListener(_applyPreselect);
    _load();
  }

  @override
  void dispose() {
    competitionPreselect.removeListener(_applyPreselect);
    super.dispose();
  }

  /// جاي من الهوم: علّم اللعبة دي جاهزة (من غير حفظ)
  void _applyPreselect() {
    final id = competitionPreselect.value;
    if (id == null || _loading || !mounted) return;
    competitionPreselect.value = null;
    if (!_picked.contains(id)) setState(() => _picked.add(id));
  }

  Future<void> _load() async {
    await CompUi.load();
    try {
      final res = await supa.rpc('competition_my_interests');
      final list = (res as List?)?.map((e) => e.toString()).toList() ?? <String>[];
      if (!mounted) return;
      setState(() { _saved = list; _picked = [...list]; _loading = false; });
    } catch (e) {
      debugPrint('competition_my_interests error: $e');
      if (mounted) setState(() => _loading = false);
    }
    _applyPreselect();   // لو اليوزر جه من الهوم قبل ما الصفحة تحمّل
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final res = await supa.rpc('competition_set_interests', params: {'p_sports': _picked});
      final list = (res as List?)?.map((e) => e.toString()).toList() ?? <String>[];
      if (!mounted) return;
      final firstTime = _saved.isEmpty && list.isNotEmpty;
      final oldFav = _saved.isEmpty ? null : _saved.first;
      setState(() { _saved = list; _picked = [...list]; });
      // أول تسجيل أو المفضلة اتغيرت → كارت WELCOME NEW BADGER
      final fav = list.isEmpty ? null : _sport(list.first);
      if (fav != null && list.first != oldFav) {
        final next = await showBadgerWelcomeCard(context, fav, arabic: _ar);
        if (!mounted) return;
        // Edit = he picked the main sport by mistake → choose again, then save (card shows again)
        if (next == 'edit') {
          final before = _picked.isEmpty ? null : _picked.first;
          await _editFavorite();
          if (mounted && _picked.isNotEmpty && _picked.first != before) {
            setState(() => _saving = false);
            await _save();
          }
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: surface2, behavior: SnackBarBehavior.floating,
        content: Text(list.isEmpty
            ? t('Registration removed', 'اتلغى تسجيلك')
            : firstTime
                ? t("You're in! We'll let you know first when it opens 🔥", 'إنت جوه! أول ما البطولة تفتح هتعرف قبل أي حد 🔥')
                : t('Your sports were updated', 'اتحدّثت ألعابك')),
      ));
    } catch (e) {
      debugPrint('competition_set_interests error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: surface2, behavior: SnackBarBehavior.floating,
        content: Text(t('Something went wrong, try again', 'حصلت مشكلة، جرّب تاني')),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// تعليم/شيل. أول تعليم = المفضلة؛ لو شال المفضلة اللي بعدها تطلع مكانها.
  /// owner 28 Nov: the first tap = the MAIN sport (one only); after that taps = other interests.
  /// Tapping the main sport = change it (sheet).
  void _toggle(String id) {
    if (_picked.isNotEmpty && _picked.first == id) { _editFavorite(); return; }
    setState(() {
      if (!_picked.remove(id)) _picked.add(id);
    });
  }

  /// اللعبة دي تبقى المفضلة، والمفضلة القديمة تنزل أول "اهتمامات تانية"
  void _setFavorite(String id) => setState(() {
        _picked.remove(id);
        _picked.insert(0, id);
      });

  Future<void> _editFavorite() async {
    final current = _picked.isEmpty ? null : _picked.first;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Directionality(
        textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(children: [
                const Icon(Icons.star_rounded, color: _gold, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(t('Choose your main sport', 'اختار رياضتك الأساسية'),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Align(alignment: AlignmentDirectional.centerStart, child: Text(
                t('Your other picks stay as they are.', 'باقي اختياراتك هتفضل زي ما هي.'),
                style: const TextStyle(color: muted, fontSize: 12))),
            ),
            Flexible(child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 12), children: [
              for (final s in kCompSports)
                ListTile(
                  dense: true,
                  onTap: () => Navigator.of(ctx).pop(s.id),
                  leading: Icon(s.icon, color: s.id == current ? _gold : Colors.white54, size: 20),
                  title: Text(_ar ? s.ar : s.en, style: TextStyle(
                    color: Colors.white, fontSize: 14,
                    fontWeight: s.id == current ? FontWeight.w900 : FontWeight.w600)),
                  trailing: s.id == current
                      ? const Icon(Icons.star_rounded, color: _gold, size: 20)
                      : (_picked.contains(s.id) ? const Icon(Icons.check_rounded, color: brandRed, size: 18) : null),
                ),
            ])),
          ])),
        ),
      ),
    );
    if (chosen != null && chosen != current && mounted) _setFavorite(chosen);
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  Widget _header() => Row(children: [
        Container(width: 40, height: 40, padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
          child: Image.asset(Brand.badger, fit: BoxFit.contain)),
        const SizedBox(width: 10),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          // ثابت بالإنجليزي زي FANTASY (جزء من اللوجو)
          Text('COMPETITIONS', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5, height: 1.1)),
          Text('B D G R', style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2)),
        ]),
        const Spacer(),
        FantasyLangToggle(isArabic: _ar, onTap: () => setState(() => _ar = !_ar)),
      ]);

  // الأونر (21 نوفمبر): "قريب جداً" + العنوان بس، وكارت أصغر عشان الصفحة تطلع لفوق
  Widget _hero() => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: brandRed.withOpacity(0.35)),
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd,
            colors: [brandRed.withOpacity(0.22), cardBg.withOpacity(0.9)],
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: brandRed, borderRadius: BorderRadius.circular(20)),
            child: Text(t('COMING SOON', 'قريب جداً'),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
          const SizedBox(height: 8),
          Text(t('Tournaments are coming 🏆', 'البطولات جاية قريب 🏆'),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1.2)),
          const SizedBox(height: 4),
          Text(t('Which tournament are you waiting for most? Pick ONE.', 'إيه أكتر بطولة مستنيها؟ اختار واحدة بس.'),
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3)),
        ]),
      );

  Widget _card(CompSport s) {
    final on = _picked.contains(s.id);
    final fav = on && _picked.first == s.id;
    return GestureDetector(
      onTap: () => _toggle(s.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? brandRed : line, width: on ? 2 : 1),
        ),
        child: Stack(fit: StackFit.expand, children: [
          Image.network(s.imageUrl, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Center(child: Icon(s.icon, color: Colors.white24, size: 34))),
          DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.25, 1],
            colors: [Colors.black.withOpacity(0.05), Colors.black.withOpacity(on ? 0.75 : 0.9)],
          ))),
          if (on) ColoredBox(color: brandRed.withOpacity(0.12)),
          // راعي الرياضة دي: "برعاية" + لوجو صغير
          PositionedDirectional(top: 8, start: 8, end: 36, child: Align(alignment: AlignmentDirectional.topStart,
            child: AdSlot('competitions_sport', sport: s.id, compact: true, prefixEn: 'by', prefixAr: 'برعاية'))),
          PositionedDirectional(top: 8, end: 8, child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 22, height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fav ? _gold : (on ? brandRed : Colors.black38),
              border: Border.all(color: fav ? _gold : (on ? brandRed : Colors.white38)),
            ),
            child: fav
                ? const Icon(Icons.star_rounded, color: Colors.black, size: 15)
                : (on ? const Icon(Icons.check_rounded, color: Colors.white, size: 15) : null),
          )),
          PositionedDirectional(start: 10, end: 10, bottom: 10, child: Text(
            _ar ? s.ar : s.en, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, height: 1.2),
          )),
        ]),
      ),
    );
  }

  /// شريط هادي فوق الكروت: المفضلة + زرار تعديل + الاهتمامات التانية
  Widget _favoriteStrip() {
    if (_picked.isEmpty) return const SizedBox.shrink();
    final fav = _sport(_picked.first);
    final others = _picked.skip(1).map(_sport).whereType<CompSport>().map((s) => _ar ? s.ar : s.en).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: cardBg.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withOpacity(0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: _gold.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.star_rounded, color: _gold, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(t('Your main sport', 'رياضتك الأساسية'),
                style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(fav == null ? '' : (_ar ? fav.ar : fav.en), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
            if (fav != null)
              AdSlot('competitions_sport', sport: fav.id, slotKey: 'fav', padding: const EdgeInsets.only(top: 4),
                  prefixEn: 'Presented by', prefixAr: 'برعاية'),
          ])),
          TextButton(
            onPressed: _editFavorite,
            style: TextButton.styleFrom(foregroundColor: _gold, padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 34), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: Text(t('Edit', 'تعديل'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          ),
        ]),
        if (others.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            '${t('Other interests', 'اهتمامات تانية')}: ${others.join(' · ')}',
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
        ],
      ]),
    );
  }

  Widget _bottomBar() {
    final registered = _saved.isNotEmpty && !_dirty;
    final label = registered
        ? t("You're registered in ${_saved.length} ${_saved.length == 1 ? 'sport' : 'sports'} ✓",
            'إنت متسجل في ${_saved.length} ${_saved.length == 1 ? 'لعبة' : 'ألعاب'} ✓')
        : _picked.isEmpty
            ? (_saved.isEmpty ? t('Pick at least one sport', 'اختار لعبة واحدة على الأقل') : t('Remove my registration', 'إلغي تسجيلي'))
            : _saved.isEmpty
                ? t('Register me (${_picked.length})', 'سجّلني (${_picked.length})')
                : t('Save changes (${_picked.length})', 'احفظ التعديل (${_picked.length})');
    final enabled = _dirty && !_saving && !(_picked.isEmpty && _saved.isEmpty);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SizedBox(
        width: double.infinity, height: 50,
        child: ElevatedButton(
          onPressed: enabled ? _save : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: brandRed, foregroundColor: Colors.white, elevation: 0,
            disabledBackgroundColor: registered ? Brand.green.withOpacity(0.14) : surface2,
            disabledForegroundColor: registered ? Brand.green : muted,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final narrow = MediaQuery.of(context).size.width <= 360;
    return Directionality(
      textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Brand.background,
        body: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(
            colors: [Brand.background, Color(0xFF0D0D12)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          child: Stack(children: [
            // البادجر باهت في الخلفية (نفس الفانتازي)
            Positioned.fill(child: IgnorePointer(child: Center(child: FractionallySizedBox(widthFactor: 0.9,
              child: Opacity(opacity: 0.06, child: Image.asset(Brand.badger, fit: BoxFit.contain)))))),
            Column(children: [
              SizedBox(height: top),
              Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 10), child: _header()),
              Expanded(child: _loading
                  ? const Center(child: CircularProgressIndicator(color: brandRed, strokeWidth: 2))
                  : CustomScrollView(slivers: [
                      SliverPadding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 14), sliver: SliverToBoxAdapter(child: _hero())),
                      // فريقي ⚽ (لو مسجّل في الكورة)
                      if (CompUi.teams && _saved.contains('football'))
                        const SliverPadding(padding: EdgeInsets.fromLTRB(16, 0, 16, 18), sliver: SliverToBoxAdapter(child: TeamHubCard())),
                      // بانر إعلان (لو فيه)
                      const SliverToBoxAdapter(child: AdSlot('competitions_top', compact: true, banner: true, padding: EdgeInsets.fromLTRB(16, 0, 16, 18))),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        sliver: SliverToBoxAdapter(child: Text(
                          _picked.isEmpty
                              ? t('Pick your main sport', 'اختار رياضتك الأساسية')
                              : t('Other sports you like (optional)', 'رياضات تانية بتحبها (اختياري)'),
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                        )),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(child: AnimatedSize(
                          duration: const Duration(milliseconds: 220), curve: Curves.easeOut,
                          alignment: Alignment.topCenter,
                          child: _favoriteStrip(),
                        )),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _gridCols(context), mainAxisSpacing: narrow ? 8 : 10, crossAxisSpacing: narrow ? 8 : 10,
                            childAspectRatio: 0.82,
                          ),
                          delegate: SliverChildBuilderDelegate((_, i) => _card(kCompSports[i]), childCount: kCompSports.length),
                        ),
                      ),
                    ])),
              if (!_loading) _bottomBar(),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// عدد الأعمدة: الموبايل 3 زي ما هو، والويب على شاشة واسعة أكتر
int _gridCols(BuildContext context) {
  if (!kIsWeb) return 3;   // الموبايل: زي ما هو بالظبط
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 1000) return 5;
  if (w >= 760) return 4;
  return 3;
}
