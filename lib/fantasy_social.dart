part of 'fantasy.dart';

/// ريأكشن + كومنتات على تشكيلة (نورمال أو درافت)، بعد الديدلاين بس.
/// السيرفر: squad_social_get / squad_react + نظام الكومنتات (post_type squad | draft_squad).
const List<(String, String)> kSquadReactions = [
  ('fire', '🔥'), ('laugh', '😂'), ('clown', '🤡'), ('clap', '👏'), ('shock', '😱'),
];

class SquadSocialBar extends StatefulWidget {
  const SquadSocialBar({super.key, required this.eventId, required this.userId, required this.draft, required this.isArabic});
  final String eventId, userId;
  final bool draft, isArabic;
  @override
  State<SquadSocialBar> createState() => _SquadSocialBarState();
}

class _SquadSocialBarState extends State<SquadSocialBar> {
  Map<String, dynamic>? _d;
  bool _busy = false;
  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await _sb.rpc('squad_social_get', params: {
        'p_mode': widget.draft ? 'draft' : 'normal', 'p_event': widget.eventId, 'p_user': widget.userId});
      if (!mounted) return;
      setState(() => _d = r == null ? null : Map<String, dynamic>.from(r as Map));
    } catch (_) {
      // قبل الديدلاين أو مفيش تشكيلة: مانعرضش حاجة
    }
  }

  bool get _owner => _d?['is_owner'] == true;
  Map get _counts => (_d?['counts'] as Map?) ?? const {};
  int _n(String k) => (_counts[k] as num?)?.toInt() ?? 0;

  Future<void> _react(String key) async {
    if (_busy || _d == null) return;
    if (_owner) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t("That's your squad 😄 others react to it.", 'دي تشكيلتك 😄 الريأكشن للناس التانية.'))));
      return;
    }
    final mine = _d!['mine'] as String?;
    final next = mine == key ? '' : key;
    // نحدّث الشاشة على طول، وبعدين نصدّق على رد السيرفر
    final old = Map<String, dynamic>.from(_d!);
    final c = Map<String, dynamic>.from(_counts);
    if (mine != null) c[mine] = ((c[mine] as num? ?? 1) - 1).clamp(0, 1 << 30).toInt();
    if (next.isNotEmpty) c[next] = ((c[next] as num? ?? 0) + 1).toInt();
    HapticFeedback.selectionClick();
    setState(() { _busy = true; _d = {..._d!, 'counts': c, 'mine': next.isEmpty ? null : next}; });
    try {
      final r = Map<String, dynamic>.from(await _sb.rpc('squad_react', params: {
        'p_type': _d!['type'], 'p_squad': _d!['id'], 'p_emoji': next}) as Map);
      if (!mounted) return;
      setState(() => _d = {..._d!, 'counts': r['counts'] ?? const {}, 'mine': r['mine']});
    } catch (e) {
      if (!mounted) return;
      setState(() => _d = old);
      final s = e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        s.contains('too_many') ? t('Too many reactions, try later.', 'ريأكشن كتير، جرّب بعد شوية.')
        : s.contains('ugc_banned') ? t('You can\'t react right now.', 'مش متاح ليك دلوقتي.')
        : t('Something went wrong.', 'حصل مشكلة، جرّب تاني.'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _comments() {
    if (_d == null) return;
    showCommentsSheet(context, postType: _d!['type'] as String, postId: _d!['id'] as String,
      onCount: (n) { if (mounted) setState(() => _d = {..._d!, 'comments': n}); });
  }

  @override
  Widget build(BuildContext context) {
    if (_d == null || _d!['open'] != true) return const SizedBox.shrink();
    final mine = _d!['mine'] as String?;
    final comments = (_d!['comments'] as num?)?.toInt() ?? 0;
    Widget pill({required Widget child, required bool on, required VoidCallback onTap}) => InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: on ? brandRed.withOpacity(0.16) : cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: on ? brandRed : line, width: on ? 1.3 : 1)),
        child: child));
    return SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal, children: [
      for (final (k, e) in kSquadReactions) ...[
        pill(on: mine == k, onTap: () => _react(k), child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedScale(scale: mine == k ? 1.18 : 1, duration: const Duration(milliseconds: 160),
            child: Text(e, style: const TextStyle(fontSize: 16))),
          if (_n(k) > 0) ...[const SizedBox(width: 4),
            Text('${_n(k)}', style: TextStyle(color: mine == k ? Colors.white : muted, fontSize: 12, fontWeight: FontWeight.w800))],
        ])),
        const SizedBox(width: 6),
      ],
      pill(on: false, onTap: _comments, child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.mode_comment_outlined, color: Colors.white, size: 16),
        const SizedBox(width: 5),
        Text(comments > 0 ? '$comments' : t('Comment', 'كومنت'),
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
      ])),
    ]));
  }
}
