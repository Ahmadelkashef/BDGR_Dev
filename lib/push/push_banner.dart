import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_lang.dart';

/// بانر الإشعار لما التطبيق مفتوح: كارت هادي بينزل من فوق، بإطار ذهبي ولوجو البادجر.
/// بيختفي لوحده بعد 5 ثواني، أو بالسحب لفوق. الدوسة عليه بتفتح المكان المناسب.
class PushBanner {
  PushBanner._();

  static OverlayEntry? _entry;
  static GlobalKey<_BannerState>? _key;

  static void show(BuildContext context, {required String title, required String body, VoidCallback? onOpen}) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _remove();
    HapticFeedback.lightImpact();
    final key = GlobalKey<_BannerState>();
    _key = key;
    late final OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _Banner(
      key: key,
      title: title,
      body: body,
      onOpen: onOpen,
      onGone: () { if (_entry == entry) _remove(); },
    ));
    _entry = entry;
    overlay.insert(entry);
  }

  static void _remove() {
    _entry?.remove();
    _entry = null;
    _key = null;
  }

  /// يقفل البانر الحالي بأنيميشن (لو موجود).
  static void dismiss() => _key?.currentState?.hide();
}

class _Banner extends StatefulWidget {
  const _Banner({super.key, required this.title, required this.body, required this.onGone, this.onOpen});
  final String title;
  final String body;
  final VoidCallback? onOpen;
  final VoidCallback onGone;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  static const _red = Color(0xFFFF0000); // BDGR red (Brand.navAccent)
  late final AnimationController _c = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 380), reverseDuration: const Duration(milliseconds: 240));
  late final Animation<Offset> _slide = Tween(begin: const Offset(0, -1.3), end: Offset.zero)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic));
  Timer? _timer;
  double _drag = 0;
  bool _hiding = false;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(const Duration(seconds: 5), hide);
  }

  Future<void> hide() async {
    if (_hiding || !mounted) return;
    _hiding = true;
    _timer?.cancel();
    await _c.reverse();
    widget.onGone();
  }

  void _open() {
    final cb = widget.onOpen;
    hide();
    cb?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = AppLang.isArabic;
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        bottom: false,
        child: SlideTransition(
          position: _slide,
          child: Transform.translate(
            offset: Offset(0, _drag.clamp(-200.0, 0.0).toDouble()),
            child: GestureDetector(
              onTap: widget.onOpen != null ? _open : hide,
              onVerticalDragUpdate: (d) => setState(() => _drag += d.delta.dy),
              onVerticalDragEnd: (d) {
                if (_drag < -24 || (d.primaryVelocity ?? 0) < -300) {
                  hide();
                } else {
                  setState(() => _drag = 0);
                }
              },
              child: Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0xFF1C1D23), Color(0xFF121317)],
                      ),
                      border: Border.all(color: _red.withValues(alpha: 0.45)),
                      boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 10))],
                    ),
                    child: Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        padding: const EdgeInsets.all(7),
                        child: Image.asset('assets/badger_white.png', color: Colors.white, fit: BoxFit.contain),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Text('BDGR', style: TextStyle(color: _red, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.6)),
                          const SizedBox(width: 6),
                          Text(AppLang.t('now', 'دلوقتي'), style: const TextStyle(color: Color(0xFF7D818C), fontSize: 10.5)),
                        ]),
                        if (widget.title.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                        ],
                        if (widget.body.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(widget.body, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFFC5C9D2), fontSize: 12.5, height: 1.45)),
                        ],
                      ])),
                      if (widget.onOpen != null) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: _red.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(AppLang.t('Open', 'افتح'),
                              style: const TextStyle(color: _red, fontSize: 12, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
