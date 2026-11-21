import 'package:flutter/material.dart';

import '../app_lang.dart';
import '../brand.dart';
import '../media_cache.dart';
import 'ugc_api.dart';
import 'ugc_composer.dart';
import 'ugc_viewer.dart';

/// بوستات اليوزر على بروفايله: شبكة 3 أعمدة بالأغلفة الصغيرة بس (مش الملفات نفسها) علشان الـ egress.
/// صاحب البروفايل بيشوف زرار "+ بوست" ومساحته.
class UgcProfileSection extends StatefulWidget {
  const UgcProfileSection({super.key, required this.ownerId, required this.isOwner, required this.ownerName});
  final int ownerId;
  final bool isOwner;
  final String ownerName;

  @override
  State<UgcProfileSection> createState() => _UgcProfileSectionState();
}

class _UgcProfileSectionState extends State<UgcProfileSection> {
  static const _page = 18;
  final List<UgcItem> _items = [];
  // تاب الريبوست (بيتحمّل لما يتفتح بس)
  final List<UgcItem> _reposts = [];
  int _tab = 0;
  bool _repostsLoaded = false, _repostsLoading = false, _repostsMore = false;
  UgcLimits? _lim;
  bool _loading = true, _failed = false, _more = false, _loadingMore = false;

  Future<void> _loadReposts({bool more = false}) async {
    if (_repostsLoading) return;
    setState(() => _repostsLoading = true);
    try {
      final list = await UgcApi.userReposts(widget.ownerId,
          before: more && _reposts.isNotEmpty ? _reposts.last.sortAt : null, limit: _page);
      if (!mounted) return;
      setState(() {
        if (!more) _reposts.clear();
        final ids = _reposts.map((e) => e.id).toSet();
        _reposts.addAll(list.where((e) => !ids.contains(e.id)));
        _repostsMore = list.length >= _page;
        _repostsLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _repostsLoaded = true);
    } finally {
      if (mounted) setState(() => _repostsLoading = false);
    }
  }

  void _setTab(int t) {
    setState(() => _tab = t);
    if (t == 1 && !_repostsLoaded) _loadReposts();
  }

  Widget _tabBtn(int t, String label) {
    final on = _tab == t;
    return GestureDetector(
      onTap: () => _setTab(t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: on ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? Colors.white : Colors.white24),
        ),
        child: Text(label, style: TextStyle(color: on ? Colors.black : Colors.white70,
            fontSize: 12, fontWeight: FontWeight.w800)),
      ),
    );
  }

  String _t(String en, String ar) => AppLang.t(en, ar);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(UgcProfileSection old) {
    super.didUpdateWidget(old);
    if (old.ownerId != widget.ownerId) _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _failed = false; });
    try {
      final list = await UgcApi.userPosts(widget.ownerId, limit: _page);
      UgcLimits? lim;
      if (widget.isOwner) {
        try { lim = await UgcApi.limits(); } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _items..clear()..addAll(list);
        _more = list.length >= _page;
        _lim = lim;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _failed = true; });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _items.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final list = await UgcApi.userPosts(widget.ownerId, before: _items.last.createdAt, limit: _page);
      if (!mounted) return;
      setState(() {
        final ids = _items.map((e) => e.id).toSet();
        _items.addAll(list.where((e) => !ids.contains(e.id)));
        _more = list.length >= _page;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _new() async {
    final item = await openUgcComposer(context);
    if (item == null || !mounted) return;
    setState(() => _items.insert(0, item));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('Posted ✓', 'اتنشر ✓'))));
    try { final l = await UgcApi.limits(); if (mounted) setState(() => _lim = l); } catch (_) {}
  }

  void _open(int i) {
    openUgcViewer(context,
        items: _items, start: i, isOwner: widget.isOwner, ownerName: widget.ownerName,
        onDeleted: (it) async {
          if (!mounted) return;
          setState(() => _items.removeWhere((x) => x.id == it.id));
          try { final l = await UgcApi.limits(); if (mounted) setState(() => _lim = l); } catch (_) {}
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(28),
          child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Brand.navAccent, strokeWidth: 2))));
    }
    if (_failed) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white38),
          label: Text(_t('Tap to reload posts', 'دوس علشان تحمّل البوستات تاني'), style: const TextStyle(color: Colors.white38)),
        )),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
        child: Row(children: [
          _tabBtn(0, _t('Posts', 'البوستات')),
          const SizedBox(width: 6),
          _tabBtn(1, _t('Reposts', 'ريبوست')),
          const Spacer(),
          if (_tab == 0 && widget.isOwner && _lim != null)
            Text(_t('${UgcApi.mb(_lim!.usedBytes)} / ${UgcApi.mb(_lim!.quotaBytes)} MB',
                    '${UgcApi.mb(_lim!.usedBytes)} / ${UgcApi.mb(_lim!.quotaBytes)} ميجا'),
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          if (_tab == 0 && widget.isOwner) ...[
            const SizedBox(width: 10),
            InkWell(
              onTap: _new,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Brand.navAccent, borderRadius: BorderRadius.circular(18)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(_t('Post', 'بوست'), style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ],
        ]),
      ),
      if (_tab == 1)
        _repostsGrid()
      else if (_items.isEmpty)
        widget.isOwner ? _empty() : _hint(_t('No posts yet', 'لسه مفيش بوستات'))
      else
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: _items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 4 / 5),
            itemBuilder: (_, i) => _tile(i),
          ),
        ),
      if (_tab == 0 && _more)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Center(child: _loadingMore
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Brand.navAccent, strokeWidth: 2))
              : TextButton(onPressed: _loadMore,
                  child: Text(_t('Show more', 'اعرض أكتر'), style: const TextStyle(color: Colors.white70)))),
        ),
    ]);
  }

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Center(child: Text(text, style: const TextStyle(color: Colors.white38, fontSize: 13))),
      );

  Widget _repostsGrid() {
    if (!_repostsLoaded) {
      return const Padding(padding: EdgeInsets.all(24),
          child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Brand.navAccent, strokeWidth: 2))));
    }
    if (_reposts.isEmpty) {
      return _hint(widget.isOwner
          ? _t('Posts you repost show up here', 'البوستات اللي بتعملها ريبوست هتظهر هنا')
          : _t('No reposts yet', 'لسه مفيش ريبوست'));
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _reposts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 4 / 5),
          itemBuilder: (_, i) => _cover(_reposts[i], () => openUgcViewer(context,
              items: _reposts, start: i, isOwner: false, ownerName: '')
              .then((_) { if (mounted) setState(() {}); }), repost: true),
        ),
      ),
      if (_repostsMore)
        TextButton(onPressed: _repostsLoading ? null : () => _loadReposts(more: true),
            child: Text(_t('Show more', 'اعرض أكتر'), style: const TextStyle(color: Colors.white70))),
    ]);
  }

  Widget _empty() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
        decoration: BoxDecoration(color: const Color(0xFF16171C), borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white10)),
        child: Column(children: [
          const Icon(Icons.add_photo_alternate_outlined, color: Colors.white38, size: 34),
          const SizedBox(height: 10),
          Text(_t('Share your first post', 'نزّل أول بوست ليك'),
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(_t('A video and a photo, or two photos. Your followers will see it.',
                  'فيديو وصورة، أو صورتين. متابعينك هيشوفوه.'),
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12.5, height: 1.5)),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _new,
            style: FilledButton.styleFrom(backgroundColor: Brand.navAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: Text(_t('New post', 'بوست جديد'), style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ]),
      );

  Widget _tile(int i) => _cover(_items[i], () => _open(i));

  Widget _cover(UgcItem it, VoidCallback onTap, {bool repost = false}) {
    final m = it.first;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(fit: StackFit.expand, children: [
          const ColoredBox(color: Color(0xFF1E2027)),
          if (m != null)
            Image(
              image: MediaCache.image(m.coverUrl, headers: UgcApi.headers, cacheKey: m.coverCacheKey),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          if (m?.isVideo == true)
            const PositionedDirectional(top: 6, end: 6,
                child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 18,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black54)])),
          if (it.media.length > 1)
            const PositionedDirectional(top: 6, start: 6,
                child: Icon(Icons.collections_rounded, color: Colors.white, size: 16,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black54)])),
          if (repost)
            const PositionedDirectional(bottom: 6, start: 6,
                child: Icon(Icons.repeat_rounded, color: Colors.white, size: 16,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black54)])),
          if (it.underReview && widget.isOwner && !repost)
            Positioned(left: 0, right: 0, bottom: 0, child: Container(
              color: Colors.black.withValues(alpha: 0.65),
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(_t('Under review', 'قيد المراجعة'), textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFFC857), fontSize: 10, fontWeight: FontWeight.w700)),
            )),
        ]),
      ),
    );
  }
}
