import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_lang.dart';
import '../brand.dart';
import '../feed/feed_api.dart' show FeedApi;
import '../media_cache.dart';
import '../profile/visitor_profile_sheet.dart';

/// الكومنتات (لبوستات BDGR `official` وبوستات اليوزرز `ugc`).
/// صاحب الكومنت أو صاحب البوست يقدر يمسح؛ أي حد تاني يقدر يبلّغ.
Future<void> showCommentsSheet(
  BuildContext context, {
  required String postType, // official | ugc
  required String postId,
  void Function(int count)? onCount,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: const Color(0xFF121317),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _CommentsSheet(postType: postType, postId: postId, onCount: onCount),
  );
}

class _Comment {
  _Comment(this.j);
  final Map<String, dynamic> j;
  String get id => j['id'] as String;
  String get body => j['body'] as String? ?? '';
  DateTime get at => DateTime.tryParse('${j['created_at']}')?.toLocal() ?? DateTime.now();
  Map get user => (j['user'] as Map?) ?? const {};
  int? get userId => (user['user_id'] as num?)?.toInt();
  String get name {
    final n = (user['display_name'] as String?)?.trim();
    return (n?.isNotEmpty ?? false) ? n! : (user['username'] as String? ?? '');
  }
  String? get avatar => user['avatar'] as String?;
  bool get mine => j['mine'] == true;
  bool get canDelete => j['can_delete'] == true;
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.postType, required this.postId, this.onCount});
  final String postType, postId;
  final void Function(int count)? onCount;
  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _sb = Supabase.instance.client;
  final _input = TextEditingController();
  final List<_Comment> _items = [];
  bool _loading = true, _failed = false, _sending = false, _more = false;
  bool get _ar => AppLang.isArabic;
  String _t(String en, String ar) => AppLang.t(en, ar);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (!more) setState(() { _loading = true; _failed = false; });
    try {
      final r = await _sb.rpc('comments_list', params: {
        'p_type': widget.postType,
        'p_post': widget.postId,
        'p_before': more && _items.isNotEmpty ? _items.last.at.toUtc().toIso8601String() : null,
        'p_limit': 30,
      });
      final list = ((r as List?) ?? const []).map((e) => _Comment(Map<String, dynamic>.from(e as Map))).toList();
      if (!mounted) return;
      setState(() {
        if (!more) _items.clear();
        _items.addAll(list);
        _more = list.length >= 30;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _failed = true; });
    }
  }

  String _err(Object e) {
    final s = e.toString();
    if (s.contains('too_many_comments')) return _t('Too many comments. Try again later.', 'كومنتات كتير. جرّب كمان شوية.');
    if (s.contains('too_long')) return _t('Max 500 characters.', 'أقصى حاجة 500 حرف.');
    if (s.contains('ugc_banned')) return _t('Commenting is turned off for your account.', 'الكومنتات متوقفة لحسابك.');
    if (s.contains('not_found')) return _t('This post is no longer available.', 'البوست ده مبقاش موجود.');
    return _t('Something went wrong. Try again.', 'حصلت مشكلة. جرّب تاني.');
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    HapticFeedback.lightImpact();
    setState(() => _sending = true);
    try {
      final r = await _sb.rpc('comment_add', params: {'p_type': widget.postType, 'p_post': widget.postId, 'p_body': body});
      _input.clear();
      widget.onCount?.call(((r as Map?)?['count'] as num?)?.toInt() ?? _items.length + 1);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_err(e))));
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _delete(_Comment c) async {
    try {
      final r = await _sb.rpc('comment_delete', params: {'p_id': c.id});
      setState(() => _items.removeWhere((x) => x.id == c.id));
      widget.onCount?.call(((r as Map?)?['count'] as num?)?.toInt() ?? _items.length);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_err(e))));
    }
  }

  Future<void> _report(_Comment c) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF16171C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (s) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Text(_t('Why are you reporting this comment?', 'بتبلّغ عن الكومنت ده ليه؟'),
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        for (final r in const [
          ('harassment', '💬', 'Harassment or bullying', 'تحرش أو تنمّر'),
          ('spam', '🚫', 'Spam', 'سبام'),
          ('nudity', '🔞', 'Sexual content', 'محتوى جنسي'),
          ('violence', '⚠️', 'Violence or threats', 'عنف أو تهديد'),
          ('child_safety', '👶', 'Child safety', 'سلامة الأطفال'),
          ('other', '📋', 'Something else', 'حاجة تانية'),
        ])
          ListTile(
            leading: Text(r.$2, style: const TextStyle(fontSize: 18)),
            title: Text(_ar ? r.$4 : r.$3, style: const TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(s, r.$1),
          ),
        const SizedBox(height: 8),
      ])),
    );
    if (reason == null) return;
    try {
      await _sb.rpc('report_content', params: {'p_content_id': c.id, 'p_content_type': 'comment', 'p_reason': reason});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('Thanks. We will review it.', 'شكرًا. هنراجعه.'))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_err(e))));
    }
  }

  void _menu(_Comment c) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF16171C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (s) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        if (c.canDelete)
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: Brand.navAccent),
            title: Text(_t('Delete comment', 'امسح الكومنت'), style: const TextStyle(color: Brand.navAccent)),
            onTap: () { Navigator.pop(s); _delete(c); },
          ),
        if (!c.mine)
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: Colors.white),
            title: Text(_t('Report', 'ابلّغ'), style: const TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(s); _report(c); },
          ),
        const SizedBox(height: 8),
      ])),
    );
  }

  Widget _avatar(_Comment c) {
    final a = c.avatar;
    final letter = c.name.isNotEmpty ? c.name.characters.first.toUpperCase() : '?';
    return ClipOval(child: SizedBox(width: 34, height: 34,
      child: a != null && a.startsWith('http')
          ? Image(image: MediaCache.image(a), fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _letter(letter))
          : _letter(letter)));
  }

  Widget _letter(String l) => ColoredBox(color: const Color(0xFF2A2C34),
      child: Center(child: Text(l, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800))));

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Directionality(
      textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: h * 0.72,
          child: Column(children: [
            const SizedBox(height: 10),
            Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: Text(_t('Comments', 'الكومنتات'),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            const Divider(height: 1, color: Colors.white10),
            Expanded(
              child: _loading
                  ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Brand.navAccent, strokeWidth: 2)))
                  : _failed
                      ? Center(child: TextButton(onPressed: _load,
                          child: Text(_t('Tap to retry', 'دوس وجرّب تاني'), style: const TextStyle(color: Colors.white54))))
                      : _items.isEmpty
                          ? Center(child: Text(_t('Be the first to comment', 'كن أول واحد يكتب كومنت'),
                              style: const TextStyle(color: Colors.white38, fontSize: 13)))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemCount: _items.length + (_more ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (i == _items.length) {
                                  return TextButton(onPressed: () => _load(more: true),
                                      child: Text(_t('Show more', 'اعرض أكتر'), style: const TextStyle(color: Colors.white54)));
                                }
                                final c = _items[i];
                                return InkWell(
                                  onLongPress: () => _menu(c),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 9, 6, 9),
                                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      GestureDetector(
                                        onTap: c.userId == null ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(
                                            builder: (_) => VisitorProfileSheet(userId: c.userId!))),
                                        child: _avatar(c),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Row(children: [
                                          Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800))),
                                          const SizedBox(width: 6),
                                          Text(FeedApi.ago(c.at), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                        ]),
                                        const SizedBox(height: 2),
                                        Text(c.body, style: const TextStyle(color: Color(0xFFD5D8DF), fontSize: 13.5, height: 1.45)),
                                      ])),
                                      IconButton(
                                        onPressed: () => _menu(c),
                                        icon: const Icon(Icons.more_horiz_rounded, color: Colors.white30, size: 18),
                                      ),
                                    ]),
                                  ),
                                );
                              },
                            ),
            ),
            const Divider(height: 1, color: Colors.white10),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      maxLength: 500,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: _t('Add a comment…', 'اكتب كومنت…'),
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF1C1D23),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _sending
                      ? const Padding(padding: EdgeInsets.all(12),
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Brand.navAccent, strokeWidth: 2)))
                      : IconButton(
                          onPressed: _send,
                          icon: const Icon(Icons.send_rounded, color: Brand.navAccent),
                        ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// زرار الكومنت (فقاعة + العدد)
class CommentButton extends StatelessWidget {
  const CommentButton({super.key, required this.count, required this.onTap, this.vertical = false});
  final int count;
  final VoidCallback onTap;
  final bool vertical;
  @override
  Widget build(BuildContext context) {
    const c = Color(0xFFC5C9D2);
    final icon = Icon(Icons.mode_comment_outlined, color: vertical ? Colors.white : c, size: vertical ? 28 : 21);
    final label = Text(count > 0 ? FeedApi.count(count) : AppLang.t('Comment', 'كومنت'),
        style: TextStyle(color: vertical ? Colors.white : c, fontSize: vertical ? 12 : 13, fontWeight: FontWeight.w700,
            shadows: vertical ? const [Shadow(blurRadius: 6, color: Colors.black54)] : null));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: vertical
            ? Column(mainAxisSize: MainAxisSize.min, children: [icon, const SizedBox(height: 4), label])
            : Row(mainAxisSize: MainAxisSize.min, children: [icon, const SizedBox(width: 6), label]),
      ),
    );
  }
}

/// زرار الشير
class ShareButton extends StatelessWidget {
  const ShareButton({super.key, required this.onTap, this.vertical = false});
  final VoidCallback onTap;
  final bool vertical;
  @override
  Widget build(BuildContext context) {
    const c = Color(0xFFC5C9D2);
    final icon = Icon(Icons.send_outlined, color: vertical ? Colors.white : c, size: vertical ? 27 : 20);
    final label = Text(AppLang.t('Share', 'شير'),
        style: TextStyle(color: vertical ? Colors.white : c, fontSize: vertical ? 12 : 13, fontWeight: FontWeight.w700,
            shadows: vertical ? const [Shadow(blurRadius: 6, color: Colors.black54)] : null));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: vertical
            ? Column(mainAxisSize: MainAxisSize.min, children: [icon, const SizedBox(height: 4), label])
            : Row(mainAxisSize: MainAxisSize.min, children: [icon, const SizedBox(width: 6), label]),
      ),
    );
  }
}

/// شريط الأزرار تحت الكارت: كل زرار واخد نفس المساحة بالظبط
class PostActionBar extends StatelessWidget {
  const PostActionBar({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
        child: Row(children: [
          for (final c in children) Expanded(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: c))),
        ]),
      );
}
