import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_svg/flutter_svg.dart';

import '../app_lang.dart';
import '../brand.dart';
import '../widgets/bottom_nav.dart' show NavItem, navSvg;

/// شكل الموقع على الشاشات الكبيرة (لابتوب / بي سي / ماك).
/// على الموبايل (أو أي شاشة أضيق من [desktopMin]) كل حاجة زي التطبيق بالظبط.
class WebLayout {
  WebLayout._();

  /// من العرض ده وطالع = شكل الكمبيوتر
  static const double desktopMin = 1000;

  /// القايمة الجانبية: كاملة (لوجو + أسماء) من العرض ده، وأقل منه أيقونات بس
  static const double fullSidebarMin = 1280;

  static bool isDesktop(BuildContext context) =>
      kIsWeb && MediaQuery.sizeOf(context).width >= desktopMin;

  static bool isDesktopWidth(double w) => kIsWeb && w >= desktopMin;
}

/// عرض أقصى لكل صفحة على الكمبيوتر. الصفحة جواه بتفتكر إن "الشاشة" بالعرض ده
/// (MediaQuery) علشان الكروت والمسافات تفضل بنفس النسب المظبوطة.
class WebPageFrame extends StatelessWidget {
  const WebPageFrame({super.key, required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth.isFinite && c.maxWidth < maxWidth ? c.maxWidth : maxWidth;
      final mq = MediaQuery.of(context);
      return Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: w,
          height: c.maxHeight,
          child: MediaQuery(
            data: mq.copyWith(size: Size(w, c.maxHeight)),
            child: child,
          ),
        ),
      );
    });
  }
}

/// خلفية المنطقة اللي حوالين الصفحة على الكمبيوتر: أسود + بادجر خفيف + توهج.
class WebBackdrop extends StatelessWidget {
  const WebBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: Color(0xFF050507)),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.1,
            colors: [Color(0x10FFFFFF), Color(0x00000000)],
          ),
        ),
      ),
      Align(
        alignment: const Alignment(0, 0.15),
        child: FractionallySizedBox(
          heightFactor: 0.7,
          child: Opacity(opacity: 0.035, child: Image.asset(Brand.badger, fit: BoxFit.contain)),
        ),
      ),
    ]);
  }
}

/// القايمة الجانبية (بدل الشريط اللي تحت في الموبايل)
class WebSidebar extends StatelessWidget {
  const WebSidebar({
    super.key,
    required this.items,
    required this.labelsAr,
    required this.selectedIndex,
    required this.onTap,
    required this.compact,
    this.onSearch,
    this.onToggleLang,
    this.settingsButton,
  });

  final List<NavItem> items;
  final List<String> labelsAr;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool compact;
  final VoidCallback? onSearch;
  final VoidCallback? onToggleLang;
  /// زرار الإعدادات (نفس قايمة الترس اللي في الهوم)
  final Widget Function(Widget child)? settingsButton;

  static const double fullWidth = 244;
  static const double compactWidth = 84;

  @override
  Widget build(BuildContext context) {
    final ar = AppLang.isArabic;
    return Container(
      width: compact ? compactWidth : fullWidth,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D11),
        border: BorderDirectional(end: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16, vertical: 22),
          child: Column(
            crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              _brand(compact),
              const SizedBox(height: 34),
              for (var i = 0; i < items.length; i++)
                _SideItem(
                  svgInner: items[i].svgInner,
                  label: ar ? labelsAr[i] : items[i].label,
                  active: i == selectedIndex,
                  compact: compact,
                  onTap: () => onTap(i),
                ),
              const Spacer(),
              if (onSearch != null)
                _SideItem(
                  svgInner: '<circle cx="11" cy="11" r="7"/><path d="m16 16 4 4"/>',
                  label: AppLang.t('Search', 'بحث'),
                  active: false,
                  compact: compact,
                  onTap: onSearch!,
                ),
              if (onToggleLang != null)
                _SideItem(
                  svgInner: '<circle cx="12" cy="12" r="10"/><path d="M2 12h20"/>'
                      '<path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/>',
                  label: ar ? 'English' : 'عربي',
                  active: false,
                  compact: compact,
                  onTap: onToggleLang!,
                ),
              if (settingsButton != null)
                settingsButton!(_SideItem(
                  svgInner: '<circle cx="12" cy="12" r="3"/>'
                      '<path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>',
                  label: AppLang.t('Settings', 'الإعدادات'),
                  active: false,
                  compact: compact,
                  onTap: null,
                )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _brand(bool compact) {
    final box = Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF2C2C2C)),
      ),
      child: Image.asset(Brand.badger, fit: BoxFit.contain),
    );
    if (compact) return box;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6),
      child: Row(children: [
        box,
        const SizedBox(width: 12),
        const Text('B D G R',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 2.2)),
      ]),
    );
  }
}

class _SideItem extends StatefulWidget {
  const _SideItem({
    required this.svgInner,
    required this.label,
    required this.active,
    required this.compact,
    required this.onTap,
  });

  final String svgInner;
  final String label;
  final bool active;
  final bool compact;
  final VoidCallback? onTap;

  @override
  State<_SideItem> createState() => _SideItemState();
}

class _SideItemState extends State<_SideItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final color = active ? Colors.white : Colors.white.withOpacity(_hover ? 0.92 : 0.62);
    final icon = SvgPicture.string(
      navSvg(widget.svgInner, stroke: active ? '#FF0000' : '#FFFFFF', opacity: active ? 1 : (_hover ? 0.9 : 0.6)),
      width: 21,
      height: 21,
    );
    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.symmetric(vertical: 3),
      height: 48,
      width: widget.compact ? 52 : double.infinity,
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 0 : 14),
      decoration: BoxDecoration(
        color: active
            ? Brand.navAccent.withOpacity(0.11)
            : (_hover ? Colors.white.withOpacity(0.05) : Colors.transparent),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? Brand.navAccent.withOpacity(0.28) : Colors.transparent),
      ),
      child: widget.compact
          ? Center(child: icon)
          : Row(children: [
              icon,
              const SizedBox(width: 14),
              Expanded(
                child: Text(widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontSize: 14.5, fontWeight: active ? FontWeight.w800 : FontWeight.w600)),
              ),
              if (active)
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: Brand.navAccent, shape: BoxShape.circle)),
            ]),
    );
    final tip = widget.compact ? Tooltip(message: widget.label, waitDuration: const Duration(milliseconds: 300), child: body) : body;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: widget.onTap == null
          ? tip
          : GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: tip),
    );
  }
}

/// الويب على شاشة كبيرة: صفحات العرض الطولي (ريلز / ستوري / بوست يوزر)
/// بتتعرض في النص بعرض مناسب (زي تيك توك على الكمبيوتر)، والجناب سودا.
/// على الموبايل بترجّع الصفحة زي ما هي.
class WebStage extends StatelessWidget {
  const WebStage({super.key, required this.child, this.maxWidth = 540, this.background = Colors.black, this.showClose = false});
  final Widget child;
  final double maxWidth;
  final Color background;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    if (!WebLayout.isDesktop(context)) return child;
    // Esc = قفل (زي أي موقع)
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop(),
      },
      child: Focus(autofocus: true, child: _stage()),
    );
  }

  Widget _stage() {
    return ColoredBox(
      color: background,
      child: Stack(fit: StackFit.expand, children: [
        WebPageFrame(maxWidth: maxWidth, child: child),
        // زرار قفل واضح بره الإطار (الماوس مش بيعمل swipe)
        if (showClose)
          PositionedDirectional(
            top: 18,
            end: 22,
            child: _StageClose(),
          ),
      ]),
    );
  }
}

class _StageClose extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.16)),
            ),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
          ),
        ),
      );
}
