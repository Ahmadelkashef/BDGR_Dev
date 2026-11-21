import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_lang.dart';
import '../brand.dart';
import '../feed/feed_api.dart' show FeedApi;
import '../feed/feed_page.dart' show HypeButton;
import '../media_cache.dart';
import '../profile/visitor_profile_sheet.dart';
import '../social/comments_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'ugc_api.dart';
import 'ugc_viewer.dart';

/// صورة صغيرة لليوزر (أول حرف لو مفيش صورة)
class UgcAvatar extends StatelessWidget {
  const UgcAvatar({super.key, required this.person, this.size = 32});
  final UgcPerson? person;
  final double size;
  @override
  Widget build(BuildContext context) {
    final a = person?.avatar;
    final letter = (person?.label.isNotEmpty ?? false) ? person!.label.characters.first.toUpperCase() : '?';
    return ClipOval(
      child: SizedBox(
        width: size, height: size,
        child: a != null && a.startsWith('http')
            ? Image(image: MediaCache.image(a), fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _letter(letter))
            : _letter(letter),
      ),
    );
  }

  Widget _letter(String l) => ColoredBox(
        color: const Color(0xFF2A2C34),
        child: Center(child: Text(l, style: TextStyle(color: Colors.white70, fontSize: size * 0.42, fontWeight: FontWeight.w800))),
      );
}

void openUgcPerson(BuildContext context, UgcPerson? p) {
  if (p == null) return;
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => VisitorProfileSheet(userId: p.userId)));
}

/// زرار الريبوست 🔁 — مش بيرفع حاجة، بس بيسجّل إنك نشرت البوست ده لمتابعينك
class RepostButton extends StatefulWidget {
  const RepostButton({super.key, required this.item, this.vertical = false, this.onChanged});
  final UgcItem item;
  final bool vertical;
  final VoidCallback? onChanged;
  @override
  State<RepostButton> createState() => _RepostButtonState();
}

class _RepostButtonState extends State<RepostButton> {
  bool _busy = false;

  Future<void> _tap() async {
    final it = widget.item;
    if (_busy) return;
    if (!it.myRepost && !it.canRepost) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(UgcError('private_account').message)));
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    final wasOn = it.myRepost;
    final f = UgcApi.toggleRepost(it);
    setState(() {}); // الحالة اتقلبت فورًا
    try {
      await f;
      if (mounted && !wasOn) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLang.t('Reposted to your followers', 'اتعمل ريبوست لمتابعينك')),
            duration: const Duration(seconds: 2)));
      }
    } on UgcError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final on = it.myRepost;
    final c = on ? Brand.navAccent : const Color(0xFFC5C9D2);
    final v = widget.vertical;
    final icon = Icon(Icons.repeat_rounded, color: c, size: v ? 30 : 22);
    final label = Text(it.reposts > 0 ? FeedApi.count(it.reposts) : AppLang.t('Repost', 'ريبوست'),
        style: TextStyle(color: c, fontSize: v ? 12 : 13, fontWeight: FontWeight.w700,
            shadows: v ? const [Shadow(blurRadius: 6, color: Colors.black54)] : null));
    return InkWell(
      onTap: _tap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: v
            ? Column(mainAxisSize: MainAxisSize.min, children: [icon, const SizedBox(height: 4), label])
            : Row(mainAxisSize: MainAxisSize.min, children: [icon, const SizedBox(width: 6), label]),
      ),
    );
  }
}

/// كارت بوست يوزر في الفيد (نفس روح كارت BDGR، باسم صاحبه، و"🔁 فلان عمل ريبوست" لو جاي من ريبوست)
class UgcFeedCard extends StatefulWidget {
  const UgcFeedCard({super.key, required this.item, required this.onOpen, this.onRemoved});
  final UgcItem item;
  final VoidCallback onOpen;
  final VoidCallback? onRemoved;
  @override
  State<UgcFeedCard> createState() => _UgcFeedCardState();
}

class _UgcFeedCardState extends State<UgcFeedCard> {
  bool _expanded = false, _following = false;
  String _t(String en, String ar) => AppLang.t(en, ar);

  Future<void> _follow() async {
    final o = widget.item.owner;
    if (o == null || _following) return;
    HapticFeedback.lightImpact();
    setState(() => _following = true);
    try {
      await UgcApi.follow(o.userId);
      widget.item.iFollow = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_t('You follow ${o.label} now', 'بقيت متابع ${o.label}')), duration: const Duration(seconds: 2)));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(UgcError('unknown').message)));
    }
    if (mounted) setState(() => _following = false);
  }

  Future<void> _hype() async {
    HapticFeedback.lightImpact();
    final f = UgcApi.toggleHype(widget.item);
    setState(() {});
    try { await f; } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _delete() async {
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
      await UgcApi.delete(widget.item);
      widget.onRemoved?.call();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(UgcError('unknown').message)));
    }
  }

  void _menu() {
    final mine = widget.item.mine;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF16171C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.person_outline_rounded, color: Colors.white),
          title: Text(mine ? _t('My profile', 'البروفايل بتاعي') : _t('View profile', 'شوف البروفايل'),
              style: const TextStyle(color: Colors.white)),
          onTap: () { Navigator.pop(c); openUgcPerson(context, widget.item.owner); },
        ),
        if (mine)
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: Brand.navAccent),
            title: Text(_t('Delete post', 'امسح البوست'), style: const TextStyle(color: Brand.navAccent)),
            onTap: () { Navigator.pop(c); _delete(); },
          )
        else
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: Colors.white),
            title: Text(_t('Report', 'ابلّغ'), style: const TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(c); showUgcReportSheet(context, widget.item); },
          ),
        const SizedBox(height: 8),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final m = it.first;
    final rb = it.repostedBy;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF15161B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF26282F)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (rb != null)
          InkWell(
            onTap: () => openUgcPerson(context, rb),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(children: [
                const Icon(Icons.repeat_rounded, color: Colors.white38, size: 15),
                const SizedBox(width: 6),
                Flexible(child: Text(_t('${rb.label} reposted', '${rb.label} عمل ريبوست'),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600))),
              ]),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(children: [
            GestureDetector(onTap: () => openUgcPerson(context, it.owner), child: UgcAvatar(person: it.owner, size: 32)),
            const SizedBox(width: 9),
            Expanded(child: GestureDetector(
              onTap: () => openUgcPerson(context, it.owner),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it.owner?.label ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                Text(FeedApi.ago(it.createdAt), style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ]),
            )),
            if (it.iFollow == false && !it.mine && it.owner != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 2),
                child: _following
                    ? const Padding(padding: EdgeInsets.all(8),
                        child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)))
                    : InkWell(
                        onTap: _follow,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white38)),
                          child: Text(_t('Follow', 'تابع'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                        ),
                      ),
              ),
            IconButton(onPressed: _menu, icon: const Icon(Icons.more_horiz_rounded, color: Colors.white54)),
          ]),
        ),
        GestureDetector(
          onTap: widget.onOpen,
          onDoubleTap: it.myHype ? null : _hype,
          child: AspectRatio(
            aspectRatio: m?.isVideo == true ? 4 / 5 : 1,
            child: Stack(fit: StackFit.expand, children: [
              const ColoredBox(color: Color(0xFF1E2027)),
              if (m != null)
                Image(
                  image: MediaCache.image(m.coverUrl, headers: UgcApi.headers, cacheKey: m.coverCacheKey),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              if (m?.isVideo == true)
                Center(child: Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24)),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
                )),
              if (it.media.length > 1)
                PositionedDirectional(top: 10, end: 10, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.collections_rounded, color: Colors.white, size: 13),
                    const SizedBox(width: 4),
                    Text('${it.media.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                )),
            ]),
          ),
        ),
        if (it.caption != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 10, 13, 0),
            child: GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(it.caption!, maxLines: _expanded ? null : 2,
                  overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFD5D8DF), fontSize: 13, height: 1.55)),
            ),
          ),
        // Hype · كومنت · ريبوست · شير — بالتساوي
        PostActionBar(children: [
          HypeButton(active: it.myHype, count: it.hypes, onTap: _hype),
          CommentButton(count: it.comments, onTap: () => showCommentsSheet(context,
              postType: 'ugc', postId: it.id,
              onCount: (n) { if (mounted) setState(() => it.comments = n); })),
          if (!it.mine) RepostButton(item: it, onChanged: () { if (mounted) setState(() {}); }),
          ShareButton(onTap: () => Share.share(UgcApi.shareText(it))),
        ]),
      ]),
    );
  }
}
