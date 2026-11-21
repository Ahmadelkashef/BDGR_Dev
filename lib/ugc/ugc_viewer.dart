import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../app_lang.dart';
import '../brand.dart';
import '../media_cache.dart';
import '../feed/feed_page.dart' show HypeButton;
import 'ugc_api.dart';
import 'ugc_widgets.dart';
import '../social/comments_sheet.dart';
import 'package:share_plus/share_plus.dart';
import '../web/web_layout.dart' show WebStage;

/// بوستات اليوزر full-screen: سحبة لفوق للبوست اللي بعده، ويمين/شمال بين ملفات نفس البوست.
/// الفيديو بيتكاش على الموبايل (MediaCache) — بيتحمّل مرة واحدة بس.
Future<void> openUgcViewer(
  BuildContext context, {
  required List<UgcItem> items,
  required int start,
  required bool isOwner,
  required String ownerName,
  void Function(UgcItem)? onDeleted,
}) {
  if (items.isEmpty) return Future.value();
  return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
    pageBuilder: (_, __, ___) => WebStage(child: _UgcViewer(
        items: items, start: start.clamp(0, items.length - 1).toInt(),
        isOwner: isOwner, ownerName: ownerName, onDeleted: onDeleted)),
    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
  ));
}

class _UgcViewer extends StatefulWidget {
  const _UgcViewer({required this.items, required this.start, required this.isOwner,
      required this.ownerName, this.onDeleted});
  final List<UgcItem> items;
  final int start;
  final bool isOwner;
  final String ownerName;
  final void Function(UgcItem)? onDeleted;
  @override
  State<_UgcViewer> createState() => _UgcViewerState();
}

class _UgcViewerState extends State<_UgcViewer> {
  late final PageController _pc = PageController(initialPage: widget.start);
  late final List<UgcItem> _items = List.of(widget.items);
  late int _i = widget.start;

  bool get _ar => AppLang.isArabic;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Directionality(
        textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(children: [
            PageView.builder(
              controller: _pc,
              scrollDirection: Axis.vertical,
              itemCount: _items.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) => UgcReelPage(
                key: ValueKey(_items[i].id),
                item: _items[i], active: i == _i, isOwner: widget.isOwner, ownerName: widget.ownerName,
                onDeleted: (d) {
                  widget.onDeleted?.call(d);
                  setState(() => _items.remove(d));
                  if (_items.isEmpty) Navigator.of(context).pop();
                },
              ),
            ),
            SafeArea(child: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28)),
            )),
          ]),
        ),
      ),
    );
  }
}

/// صفحة بوست يوزر واحد full-screen (ملفاته يمين/شمال + Hype + كومنت + ريبوست + شير + ⋮).
/// بتتستخدم في عارض بوستات اليوزر وفي الستريم الموحّد بتاع الفيد.
class UgcReelPage extends StatefulWidget {
  const UgcReelPage({super.key, required this.item, required this.active,
      this.isOwner = false, this.ownerName = '', this.onDeleted});
  final UgcItem item;
  final bool active;
  final bool isOwner;
  final String ownerName;
  final void Function(UgcItem)? onDeleted;
  @override
  State<UgcReelPage> createState() => _UgcReelPageState();
}

class _UgcReelPageState extends State<UgcReelPage> {
  int _sub = 0; // الملف الظاهر جوه البوست
  bool get _ar => AppLang.isArabic;
  String _t(String en, String ar) => _ar ? ar : en;

  // بوستي أنا: امسح بدل ابلّغ، ومفيش ريبوست
  bool _own(UgcItem it) => widget.isOwner || it.mine;

  Future<void> _delete(UgcItem it) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1B20),
        title: Text(_t('Delete this post?', 'تمسح البوست ده؟'), style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(_t("It's removed for everyone and its space comes back to you.", 'هيتشال عند الكل، ومساحته هترجعلك.'),
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(_t('Cancel', 'لأ'), style: const TextStyle(color: Colors.white70))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(_t('Delete', 'امسح'), style: const TextStyle(color: Brand.navAccent))),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    try {
      await UgcApi.delete(it);
      widget.onDeleted?.call(it);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(UgcError('unknown').message)));
    }
  }

  void _menu(UgcItem it) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF16171C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          if (_own(it))
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Brand.navAccent),
              title: Text(_t('Delete post', 'امسح البوست'), style: const TextStyle(color: Brand.navAccent)),
              onTap: () { Navigator.pop(c); _delete(it); },
            )
          else
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.white),
              title: Text(_t('Report', 'ابلّغ'), style: const TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(c); showUgcReportSheet(context, it); },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _hype(UgcItem it) async {
    HapticFeedback.lightImpact();
    final f = UgcApi.toggleHype(it);
    setState(() {});
    try { await f; } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final sub = _sub;
    return Stack(fit: StackFit.expand, children: [
      GestureDetector(
        onDoubleTap: it.myHype || it.underReview ? null : () => _hype(it),
        child: PageView.builder(
        itemCount: it.media.length,
        onPageChanged: (k) => setState(() => _sub = k),
        itemBuilder: (_, k) {
          final m = it.media[k];
          final active = widget.active && k == sub;
          return m.isVideo ? _UgcVideo(media: m, active: active) : _UgcImage(media: m);
        },
      )),
      // Hype + ريبوست على الجنب
      if (!it.underReview)
        PositionedDirectional(
          end: 6, bottom: 0,
          child: SafeArea(top: false, child: Padding(
            padding: const EdgeInsets.only(bottom: 34),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              HypeButton(active: it.myHype, count: it.hypes, onTap: () => _hype(it), vertical: true),
              const SizedBox(height: 4),
              CommentButton(count: it.comments, vertical: true, onTap: () => showCommentsSheet(context,
                  postType: 'ugc', postId: it.id,
                  onCount: (n) { if (mounted) setState(() => it.comments = n); })),
              const SizedBox(height: 4),
              if (!_own(it)) ...[
                RepostButton(item: it, vertical: true, onChanged: () { if (mounted) setState(() {}); }),
                const SizedBox(height: 4),
              ],
              ShareButton(vertical: true, onTap: () => Share.share(UgcApi.shareText(it))),
            ]),
          )),
        ),
      const IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.transparent, Color(0xCC000000)], stops: [0, 0.65, 1])))),
      PositionedDirectional(
        start: 16, end: 84, bottom: 0,
        child: SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (it.media.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var k = 0; k < it.media.length; k++)
                    Container(
                      width: k == sub ? 16 : 6, height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(color: k == sub ? Colors.white : Colors.white38,
                          borderRadius: BorderRadius.circular(3)),
                    ),
                ]),
              ),
            if (it.underReview && _own(it))
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                child: Text(_t('Under review — hidden from others for now', 'قيد المراجعة — مستخبي عن الناس دلوقتي'),
                    style: const TextStyle(color: Color(0xFFFFC857), fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
            if (it.repostedBy != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(_t('🔁 ${it.repostedBy!.label} reposted', '🔁 ${it.repostedBy!.label} عمل ريبوست'),
                    style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            GestureDetector(
              onTap: () => openUgcPerson(context, it.owner),
              child: Row(children: [
                if (it.owner != null) ...[UgcAvatar(person: it.owner, size: 28), const SizedBox(width: 8)],
                Flexible(child: Text(it.owner?.label ?? widget.ownerName, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800))),
              ]),
            ),
            if (it.caption != null) ...[
              const SizedBox(height: 4),
              Text(it.caption!, maxLines: 4, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFD5D8DF), fontSize: 13, height: 1.5)),
            ],
          ]),
        )),
      ),
          // ⋮ = امسح (بوستي) / ابلّغ
      PositionedDirectional(top: 0, end: 0, child: SafeArea(child: Padding(
        padding: const EdgeInsets.all(8),
        child: IconButton(onPressed: () => _menu(it),
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 26)),
      ))),
    ]);
  }
}

class _UgcImage extends StatelessWidget {
  const _UgcImage({required this.media});
  final UgcMedia media;
  @override
  Widget build(BuildContext context) => Image(
        image: MediaCache.image(media.url, headers: media.headers, cacheKey: media.cacheKey),
        fit: BoxFit.contain,
        loadingBuilder: (_, child, p) => p == null ? child : const Center(child: SizedBox(width: 28, height: 28,
            child: CircularProgressIndicator(color: Brand.navAccent, strokeWidth: 2))),
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 46)),
      );
}

class _UgcVideo extends StatefulWidget {
  const _UgcVideo({required this.media, required this.active});
  final UgcMedia media;
  final bool active;
  @override
  State<_UgcVideo> createState() => _UgcVideoState();
}

class _UgcVideoState extends State<_UgcVideo> {
  VideoPlayerController? _c;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(_UgcVideo old) {
    super.didUpdateWidget(old);
    if (widget.active && _c == null) _load();
    if (!widget.active) _c?.pause();
    if (widget.active && _c != null && !_paused) _c!.play();
  }

  Future<void> _load() async {
    final c = await MediaCache.video(widget.media.url, headers: widget.media.headers);
    try {
      await c.initialize();
      await c.setLooping(true);
    } catch (e) {
      debugPrint('ugc video error: $e');
    }
    if (!mounted) { c.dispose(); return; }
    setState(() => _c = c);
    if (widget.active) c.play();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!ready) return;
        setState(() => _paused = !_paused);
        _paused ? c.pause() : c.play();
      },
      child: Stack(fit: StackFit.expand, children: [
        if (!ready && widget.media.posterKey != null)
          Image(image: MediaCache.image(widget.media.coverUrl, headers: widget.media.headers, cacheKey: widget.media.coverCacheKey),
              fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        if (ready) Center(child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))),
        if (!ready)
          const Center(child: SizedBox(width: 28, height: 28,
              child: CircularProgressIndicator(color: Brand.navAccent, strokeWidth: 2))),
        if (ready && _paused) const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 76)),
        if (ready)
          Positioned(left: 0, right: 0, bottom: 0, child: SafeArea(top: false,
              child: VideoProgressIndicator(c, allowScrubbing: true, padding: EdgeInsets.zero,
                  colors: const VideoProgressColors(playedColor: Brand.navAccent,
                      bufferedColor: Colors.white24, backgroundColor: Colors.white10)))),
      ]),
    );
  }
}

/// البلاغ: سبب واحد، وبيوصل للداشبورد (🚩 البلاغات).
Future<void> showUgcReportSheet(BuildContext context, UgcItem item) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF16171C),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _ReportSheet(item: item),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.item});
  final UgcItem item;
  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _sel;
  bool _sending = false, _done = false;

  static const _reasons = [
    ('nudity', '🔞', 'Nudity or sexual content', 'عري أو محتوى جنسي'),
    ('violence', '⚠️', 'Violence or harmful content', 'عنف أو محتوى مؤذي'),
    ('harassment', '💬', 'Harassment or bullying', 'تحرش أو تنمّر'),
    ('spam', '🚫', 'Spam or misleading', 'سبام أو محتوى مضلل'),
    ('child_safety', '👶', 'Child safety', 'سلامة الأطفال'),
    ('other', '📋', 'Something else', 'حاجة تانية'),
  ];

  Future<void> _send() async {
    if (_sel == null || _sending) return;
    setState(() => _sending = true);
    try {
      await UgcApi.report(widget.item, _sel!);
      if (!mounted) return;
      setState(() => _done = true);
      await Future.delayed(const Duration(milliseconds: 1600));
      if (mounted) Navigator.pop(context);
    } on UgcError catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = AppLang.isArabic;
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: _done
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 40),
                  const SizedBox(height: 10),
                  Text(AppLang.t('Thanks. We will review it.', 'شكرًا. هنراجعه.'),
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                ])
              : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(AppLang.t('Why are you reporting this?', 'بتبلّغ عن ده ليه؟'),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(AppLang.t("The owner won't know who reported.", 'صاحب البوست مش هيعرف مين بلّغ.'),
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 10),
                  for (final r in _reasons)
                    InkWell(
                      onTap: () => setState(() => _sel = r.$1),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
                        child: Row(children: [
                          Text(r.$2, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(ar ? r.$4 : r.$3,
                              style: const TextStyle(color: Colors.white, fontSize: 14))),
                          Icon(_sel == r.$1 ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                              color: _sel == r.$1 ? Brand.navAccent : Colors.white30, size: 20),
                        ]),
                      ),
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: FilledButton(
                      onPressed: _sel == null || _sending ? null : _send,
                      style: FilledButton.styleFrom(backgroundColor: Brand.navAccent,
                          disabledBackgroundColor: Colors.white10,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: _sending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(AppLang.t('Send report', 'ابعت البلاغ'),
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ]),
        ),
      ),
    );
  }
}
