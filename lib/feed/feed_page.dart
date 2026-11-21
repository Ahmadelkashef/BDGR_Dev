import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../ads/ad_widgets.dart';
import '../app_lang.dart';
import '../brand.dart';
import '../deep_links.dart';
import '../fantasy.dart' show FantasyHighlightsStrip;
import '../media_cache.dart';
import '../official_account.dart';
import 'external_media.dart';
import 'feed_api.dart';
import 'feed_stories.dart';
import 'feed_viewer.dart';
import '../social/comments_sheet.dart';
import '../ugc/ugc_api.dart';
import '../ugc/ugc_viewer.dart';
import '../ugc/ugc_widgets.dart';

/// الفيد: ستوريز فوق (BDGR + كسبانين الفانتازي)، وتحتها كروت البوستات (فيديو أو صورة).
/// الكارت بيعرض غلاف صغير بس؛ الفيديو مش بيتحمّل غير لما اليوزر يدوس عليه (علشان الـ egress).
class FeedPage extends StatefulWidget {
  const FeedPage({super.key, required this.isActive});

  /// التاب مفتوح دلوقتي؟ (الفيد مش بيشغّل حاجة لوحده، بس بنحدّث لما يتفتح)
  final bool isActive;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  static const _gold = Brand.navAccent;   // أحمر BDGR (الدهبي للتوثيق بس)

  final _scroll = ScrollController();
  final List<FeedPost> _posts = [];
  // بوستات كل اليوزرز (الحسابات العامة + اللي متابعهم + ريبوستات اللي متابعهم) — بتتخلط مع بوستات BDGR بالوقت
  final List<UgcItem> _ugc = [];
  bool _ugcEnd = false;

  DateTime _at(Object o) => o is FeedPost ? o.createdAt : (o as UgcItem).sortAt;

  /// المثبّت فوق، وبعدين كل حاجة بالأحدث
  List<Object> get _entries {
    final rest = <Object>[..._posts.where((p) => !p.isPinned), ..._ugc]
      ..sort((a, b) => _at(b).compareTo(_at(a)));
    return [..._posts.where((p) => p.isPinned), ...rest];
  }
  List<FeedStory> _stories = [];
  bool _loading = true, _loadingMore = false, _end = false, _failed = false;
  DateTime? _lastLoad;

  bool get _ar => AppLang.isArabic;
  String _t(String en, String ar) => AppLang.t(en, ar);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    DeepLinks.pendingPostId.addListener(_openPendingPost);
    DeepLinks.pendingUgcId.addListener(_openPendingPost);
    _refresh();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingPost());
  }

  @override
  void didUpdateWidget(covariant FeedPage old) {
    super.didUpdateWidget(old);
    // فتح التاب بعد أكتر من 5 دقايق: نجيب الجديد
    if (widget.isActive && !old.isActive && _lastLoad != null &&
        DateTime.now().difference(_lastLoad!) > const Duration(minutes: 5)) {
      _refresh();
    }
    if (widget.isActive && !old.isActive) _openPendingPost();
  }

  @override
  void dispose() {
    DeepLinks.pendingPostId.removeListener(_openPendingPost);
    DeepLinks.pendingUgcId.removeListener(_openPendingPost);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() { _failed = false; if (_posts.isEmpty) _loading = true; });
    try {
      final results = await Future.wait<Object>([
        FeedApi.page(),
        FeedApi.stories(),
        UgcApi.feed().catchError((Object e) { debugPrint('ugc feed error: $e'); return <UgcItem>[]; }),
      ]);
      if (!mounted) return;
      setState(() {
        _posts..clear()..addAll(results[0] as List<FeedPost>);
        _stories = results[1] as List<FeedStory>;
        _end = (results[0] as List).length < 10;
        _ugc..clear()..addAll(results[2] as List<UgcItem>);
        _ugcEnd = (results[2] as List).length < 10;
        _loading = false;
        _lastLoad = DateTime.now();
      });
    } catch (e) {
      debugPrint('feed load error: $e');
      if (mounted) setState(() { _loading = false; _failed = _posts.isEmpty && _ugc.isEmpty; });
    }
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || (_end && _ugcEnd) || (_posts.isEmpty && _ugc.isEmpty)) return;
    setState(() => _loadingMore = true);
    try {
      final lastOfficial = _posts.where((p) => !p.isPinned).lastOrNull;
      final res = await Future.wait<List<Object>>([
        !_end && _posts.isNotEmpty
            ? FeedApi.page(before: (lastOfficial ?? _posts.last).createdAt)
            : Future.value(<FeedPost>[]),
        !_ugcEnd && _ugc.isNotEmpty
            ? UgcApi.feed(before: _ugc.last.sortAt).catchError((Object _) => <UgcItem>[])
            : Future.value(<UgcItem>[]),
      ]);
      if (!mounted) return;
      setState(() {
        final more = res[0].cast<FeedPost>();
        final ids = _posts.map((p) => p.id).toSet();
        _posts.addAll(more.where((p) => !ids.contains(p.id)));
        if (!_end) _end = more.length < 10;
        final um = res[1].cast<UgcItem>();
        final uids = _ugc.map((p) => p.id).toSet();
        _ugc.addAll(um.where((p) => !uids.contains(p.id)));
        if (!_ugcEnd) _ugcEnd = um.length < 10;
      });
    } catch (e) {
      debugPrint('feed more error: $e');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // لينك شير لبوست: نجيبه ونفتحه
  Future<void> _openPendingPost() async {
    final uid = DeepLinks.pendingUgcId.value;
    if (uid != null && widget.isActive && mounted) {
      DeepLinks.consumeUgc();
      final it = _ugc.where((x) => x.id == uid).firstOrNull ?? await UgcApi.get(uid).catchError((_) => null);
      if (!mounted) return;
      if (it == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_t('This post is no longer available', 'البوست ده مبقاش موجود'))));
        return;
      }
      await openUgcViewer(context, items: [it], start: 0, isOwner: false, ownerName: '');
      if (mounted) setState(() {});
      return;
    }
    final id = DeepLinks.pendingPostId.value;
    if (id == null || !widget.isActive || !mounted) return;
    DeepLinks.consumePost();
    final p = _posts.where((x) => x.id == id).firstOrNull ?? await FeedApi.post(id).catchError((_) => null);
    if (!mounted) return;
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('This post is no longer available', 'البوست ده مبقاش موجود'))));
      return;
    }
    _open(p, list: [p]);
  }

  // أي بوست (صورة / فيديو / لينك) بيفتح في نفس السكرول full-screen ويقدر يقلّب للي بعده
  // ستريم واحد زي الريلز: نفس ترتيب الفيد (BDGR + اليوزرز)، والإعلانات بتظهر كل كام سوايب جوه العارض
  Future<void> _open(FeedPost p, {List<FeedPost>? list}) async {
    if (list != null) {
      await openFeedViewer(context, list, list.indexOf(p));
    } else {
      final all = _entries;
      await openMixedFeedViewer(context, all, all.indexOf(p), onUgcDeleted: (d) => _ugc.remove(d));
    }
    if (mounted) setState(() {});   // عدد الـ Hype ممكن يكون اتغير جوه
  }

  // بوست يوزر: نفس الستريم الموحّد
  Future<void> _openUgc(UgcItem it) async {
    final all = _entries;
    await openMixedFeedViewer(context, all, all.indexOf(it), onUgcDeleted: (d) => _ugc.remove(d));
    if (mounted) setState(() {});
  }

  Future<void> _toggleHype(FeedPost p) async {
    HapticFeedback.lightImpact();
    final was = p.myHype;
    setState(() { p.myHype = !was; p.hypes += was ? -1 : 1; });
    try {
      await FeedApi.hype(p, !was);
    } catch (_) {
      p.myHype = was; p.hypes += was ? 1 : -1;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Directionality(
        textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: Brand.background,
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: _gold,
              backgroundColor: const Color(0xFF16171C),
              onRefresh: _refresh,
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _header()),
                  SliverToBoxAdapter(child: _storiesRow()),
                  if (_loading)
                    const SliverFillRemaining(hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator(color: _gold, strokeWidth: 2)))
                  else if (_failed)
                    SliverFillRemaining(hasScrollBody: false, child: _message(
                        Icons.wifi_off_rounded,
                        _t("Couldn't load the feed", 'مقدرناش نحمّل الفيد'),
                        action: TextButton(onPressed: _refresh,
                            child: Text(_t('Try again', 'جرّب تاني'), style: const TextStyle(color: _gold)))))
                  else if (_posts.isEmpty && _ugc.isEmpty)
                    SliverFillRemaining(hasScrollBody: false, child: _message(
                        Icons.dynamic_feed_outlined,
                        _t('Posts from BDGR and the BDGR community show up here', 'بوستات BDGR وكل الناس على BDGR هتظهر هنا')))
                  else ...[
                    ValueListenableBuilder<int>(valueListenable: Ads.version, builder: (_, __, ___) {
                      final entries = _withAds(_entries);
                      return SliverList.builder(
                        itemCount: entries.length,
                        itemBuilder: (_, i) {
                          final e = entries[i];
                          if (e is _FeedAd) {
                            // إعلان وسط البوستات: كارت شبه البوست وعليه "إعلان" وبيتقفل بـ ×
                            return Padding(
                              key: ValueKey('ad-${e.n}-${e.ad.id}'),
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                              child: AdView(e.ad),
                            );
                          }
                          if (e is UgcItem) {
                            return UgcFeedCard(
                              key: ValueKey('u-${e.id}'),
                              item: e,
                              onOpen: () => _openUgc(e),
                              onRemoved: () { if (mounted) setState(() => _ugc.remove(e)); },
                            );
                          }
                          final p = e as FeedPost;
                          return _PostCard(
                            key: ValueKey('o-${p.id}'),
                            post: p,
                            onOpen: () => _open(p),
                            onHype: () => _toggleHype(p),
                            onShare: () => Share.share(FeedApi.shareText(p)),
                          );
                        },
                      );
                    }),
                    SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
                      child: Center(child: _loadingMore
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: _gold, strokeWidth: 2))
                          : _end && _ugcEnd && (_posts.length + _ugc.length) > 3
                              ? Text(_t("You're all caught up", 'كده شفت كل حاجة'),
                                  style: const TextStyle(color: Colors.white38, fontSize: 12))
                              : const SizedBox.shrink()),
                    )),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
        child: Row(children: [
          Text(_t('Feed', 'الفيد'),
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const Spacer(),
          const Text('B D G R', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
        ]),
      );

  /// إعلانات وسط الفيد: أول واحد بعد البوست رقم first_after، وبعدها كل every_n (الأرقام من السيرفر)
  List<Object> _withAds(List<Object> entries) {
    if (Ads.candidates('feed_inline').isEmpty) return entries;
    final cfg = Ads.cfg('feed_inline');
    final first = (cfg.firstAfter ?? 4).clamp(1, 1000).toInt();
    final every = (cfg.everyN ?? 8).clamp(2, 1000).toInt();
    final out = <Object>[];
    var k = 0;
    for (var i = 0; i < entries.length; i++) {
      out.add(entries[i]);
      final c = i + 1;
      if (c == first || (c > first && (c - first) % every == 0)) {
        if (cfg.maxPerSession != null && k >= cfg.maxPerSession!) continue;
        final ad = Ads.rotate('feed_inline', k);
        if (ad != null) out.add(_FeedAd(ad, k++));
      }
    }
    return out;
  }

  Widget _storiesRow() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 0, 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_stories.isNotEmpty) ...[
            OfficialStoriesCircle(stories: _stories),
            const SizedBox(width: 12),
          ],
          // ستوري إعلان (حلقة رمادي، مكتوب تحتها "إعلان")
          ValueListenableBuilder<int>(valueListenable: Ads.version, builder: (_, __, ___) {
            final ad = Ads.pick('feed_story');
            if (ad == null) return const SizedBox.shrink();
            return Padding(padding: const EdgeInsetsDirectional.only(end: 10), child: AdStoryCircle(ad, size: 58));
          }),
          Expanded(child: FantasyHighlightsStrip(isArabic: _ar)),
        ]),
      );

  Widget _message(IconData icon, String text, {Widget? action}) => Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 40, 32, 120),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white24, size: 44),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14, height: 1.6)),
            if (action != null) ...[const SizedBox(height: 8), action],
          ]),
        ),
      );
}

/// كارت البوست: الحساب + الوقت، الغلاف، العنوان والوصف، Hype وشير والمشاهدات.
/// مكان إعلان جوه لستة الفيد
class _FeedAd {
  const _FeedAd(this.ad, this.n);
  final AdItem ad;
  final int n;
}

class _PostCard extends StatefulWidget {
  const _PostCard({super.key, required this.post, required this.onOpen, required this.onHype, required this.onShare});
  final FeedPost post;
  final VoidCallback onOpen, onHype, onShare;

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  static const _gold = Brand.navAccent;   // أحمر BDGR (الدهبي للتوثيق بس)
  bool _expanded = false;

  String _t(String en, String ar) => AppLang.t(en, ar);

  String _dur(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final cover = p.coverPath;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF15161B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF26282F)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // الحساب
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
          child: Row(children: [
            const OfficialMark(size: 32),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Text('BDGR', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                SizedBox(width: 4),
                OfficialBadge(size: 15),
              ]),
              Text(p.views > 0 ? '${FeedApi.ago(p.createdAt)} · ${FeedApi.count(p.views)} ${_t('views', 'مشاهدة')}' : FeedApi.ago(p.createdAt),
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ])),
            if (p.isPinned)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: const Color(0x26FF0000), borderRadius: BorderRadius.circular(20)),
                child: Text(_t('📌 Pinned', '📌 مثبّت'),
                    style: const TextStyle(color: Color(0xFFFF5A5A), fontSize: 11, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
        // الغلاف (صورة صغيرة متكاشة)، والدوسة بتفتح الفيديو أو الصورة
        GestureDetector(
          onTap: widget.onOpen,
          onDoubleTap: p.myHype ? null : widget.onHype,
          child: AspectRatio(
            aspectRatio: p.isVideo ? 4 / 5 : 1,
            child: Stack(fit: StackFit.expand, children: [
              if (p.isExternal)
                ExternalThumb(post: p)
              else if (cover != null)
                Image(
                  image: MediaCache.image(FeedApi.mediaUrl(cover), headers: FeedApi.headers, cacheKey: 'reels/$cover'),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _CoverPlaceholder(),
                  frameBuilder: (_, child, frame, sync) =>
                      sync || frame != null ? child : const _CoverPlaceholder(),
                )
              else
                const _CoverPlaceholder(),
              if (p.isVideo) ...[
                Center(child: Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
                )),
                if (p.isExternal)
                  PositionedDirectional(top: 10, start: 10, child: ExternalBadge(post: p)),
                if (p.durationS != null && p.durationS! > 0)
                  PositionedDirectional(
                    bottom: 10, end: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8)),
                      child: Text(_dur(p.durationS!), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ]),
          ),
        ),
        // العنوان والوصف
        if (p.title.isNotEmpty || p.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (p.title.isNotEmpty)
                Text(p.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              if (p.description.isNotEmpty) ...[
                const SizedBox(height: 3),
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Text(p.description,
                      maxLines: _expanded ? null : 2,
                      overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFFA6AAB5), fontSize: 13, height: 1.55)),
                ),
              ],
            ]),
          ),
        // Hype · كومنت · شير — كل واحد واخد نفس المساحة
        PostActionBar(children: [
          HypeButton(active: p.myHype, count: p.hypes, onTap: widget.onHype),
          CommentButton(count: p.comments, onTap: () => showCommentsSheet(context,
              postType: 'official', postId: p.id,
              onCount: (n) { if (mounted) setState(() => p.comments = n); })),
          ShareButton(onTap: widget.onShare),
        ]),
      ]),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();
  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFF1E2027),
        child: Center(child: OfficialMark(size: 56)),
      );
}

/// علامة الـ Hype: وش البادجر (لوجو BDGR نفسه). رمادي فاتح عادي، أحمر BDGR لما يتفعّل.
class HypeMark extends StatelessWidget {
  const HypeMark({super.key, required this.active, required this.size, this.glow = false});
  final bool active;
  final double size;   // العرض؛ اللوجو عريض (591×334)
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final mark = Image.asset('assets/badger_white.png',
        width: size, height: size * 0.565, fit: BoxFit.contain,
        color: active ? Brand.navAccent : const Color(0xFFC5C9D2), filterQuality: FilterQuality.medium);
    if (!glow || !active) return mark;
    return DecoratedBox(
      decoration: BoxDecoration(boxShadow: [BoxShadow(color: Brand.navAccent.withValues(alpha: 0.45), blurRadius: size * 0.5)]),
      child: mark,
    );
  }
}

/// زرار Hype: وش البادجر. لما يتفعّل بيعمل "نطّة" صغيرة + توهّج أحمر لحظة.
class HypeButton extends StatefulWidget {
  const HypeButton({super.key, required this.active, required this.count, required this.onTap, this.vertical = false});
  final bool active;
  final int count;
  final VoidCallback onTap;
  final bool vertical;

  @override
  State<HypeButton> createState() => _HypeButtonState();
}

class _HypeButtonState extends State<HypeButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.38).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 1.38, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 65),
  ]).animate(_pop);

  @override
  void didUpdateWidget(HypeButton old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _pop.forward(from: 0);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vertical;
    final color = widget.active ? Brand.navAccent : const Color(0xFFC5C9D2);
    final icon = AnimatedBuilder(
      animation: _pop,
      builder: (_, __) => Transform.scale(scale: _scale.value,
          child: HypeMark(active: widget.active, size: v ? 36 : 27, glow: _pop.isAnimating && _pop.value < 0.85)),
    );
    final label = Text(widget.count > 0 ? 'Hype ${FeedApi.count(widget.count)}' : 'Hype',
        style: TextStyle(color: color, fontSize: v ? 12 : 13, fontWeight: FontWeight.w700,
            shadows: v ? const [Shadow(blurRadius: 6, color: Colors.black54)] : null));
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: v
            ? Column(mainAxisSize: MainAxisSize.min, children: [icon, const SizedBox(height: 6), label])
            : Row(mainAxisSize: MainAxisSize.min, children: [icon, const SizedBox(width: 7), label]),
      ),
    );
  }
}
