import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_lang.dart';
import 'ad_widgets.dart';

String _t(String en, String ar) => AppLang.t(en, ar);

/// Home Takeover: أول ما الهوم تفتح، كارت كبير في النص (مرة في اليوم).
/// شريط زي الستوري فوق، ✕ و"اعرف أكتر". لما يتقفل (أو الوقت يخلص) بينزل مكانه في الهوم كبانر.
/// مفيش حملة على home_takeover = مفيش حاجة خالص.
Future<void> showHomeTakeover(BuildContext context) async {
  // لو فيه نافذة مفتوحة (الشروط، الإشعارات، الترحيب…) نستنى لحد ما تتقفل
  await AdsRouteGuard.waitClear();
  await Future<void>.delayed(const Duration(milliseconds: 500));
  if (!context.mounted || !AdsRouteGuard.clear) return showHomeTakeover(context);
  // لازم الهوم تكون هي اللي قدام اليوزر
  if (!TickerMode.valuesOf(context).enabled || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
  final ad = await Ads.takeoverToShow();
  if (ad == null || !context.mounted) return;
  await Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: false,
    barrierColor: Colors.black.withOpacity(0.72),
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (_, __, ___) => _TakeoverPage(ad: ad),
    transitionsBuilder: (_, a, __, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
    ),
  ));
}

String takeoverHeroTag(AdItem ad) => 'ad-dock-${ad.id}';

/// شكل الإعلان وهو بيطير من الكارت الكبير لمكان البانر
Widget takeoverShuttle(BuildContext _, Animation<double> anim, HeroFlightDirection __, BuildContext from, BuildContext to) {
  final hero = (to.widget is Hero ? to.widget : from.widget) as Hero;
  return AnimatedBuilder(
    animation: anim,
    builder: (_, child) => ClipRRect(borderRadius: BorderRadius.circular(14 + 10 * (1 - anim.value)), child: child),
    child: hero.child is AdMedia ? hero.child : const ColoredBox(color: Color(0xFF15151B)),
  );
}

/// نفس كارت الـ Takeover (كام ثانية وبيتقفل لوحده) بس من دوسة على بانر في أي مكان.
/// مش بينزل في الهوم (مفيش dock) — بيتقفل ويرجع اليوزر مكانه والبانر زي ما هو.
Future<void> showAdModal(BuildContext context, AdItem ad) {
  Ads.click(ad);
  return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
    opaque: false,
    barrierColor: Colors.black.withOpacity(0.72),
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, __, ___) => _TakeoverPage(ad: ad, dock: false),
    transitionsBuilder: (_, a, __, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
    ),
  ));
}

/// دوسة على بانر: لينك برّه (موقع / تطبيق) → يفتحه على طول؛ غير كده (مفيش لينك، أو صفحة جوه التطبيق) → الكارت الكبير
void onAdBannerTap(BuildContext context, AdItem ad) {
  if (ad.hasLink && ad.linkType != 'deeplink' && ad.details == null) {
    Ads.open(ad);
  } else {
    showAdModal(context, ad);
  }
}

/// البانر اللي بيفضل في الهوم بعد ما الـ Takeover يتقفل
class DockedTakeoverBanner extends StatelessWidget {
  const DockedTakeoverBanner(this.ad, {super.key, this.height});
  final AdItem ad;
  /// ارتفاع ثابت (الهوم بيحسبه عشان كله يبان من غير سكرول)؛ null = نسبة 3.2
  final double? height;
  @override
  Widget build(BuildContext context) => AdImpression(
        ad: ad,
        child: GestureDetector(
          onTap: () => openTakeoverDetails(context, ad),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _box(
              Stack(fit: StackFit.expand, children: [
                Hero(tag: takeoverHeroTag(ad), flightShuttleBuilder: takeoverShuttle, child: AdMedia(ad)),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xAA000000)]))),
                PositionedDirectional(top: 8, end: 8, child: AdLabel(demo: ad.demo)),
                if (ad.title != null)
                  PositionedDirectional(start: 12, end: 12, bottom: 9, child: Text(ad.title!, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: ad.fg ?? Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800))),
              ]),
            ),
          ),
        ),
      );

  Widget _box(Widget child) =>
      height == null ? AspectRatio(aspectRatio: 3.2, child: child) : SizedBox(height: height, child: child);
}

/// "اعرف أكتر": لو فيه تفاصيل (بريميوم) → صفحة جوه التطبيق، وإلا → اللينك على طول
void openTakeoverDetails(BuildContext context, AdItem ad) {
  if (ad.details == null) {
    Ads.open(ad);
    return;
  }
  Ads.click(ad);
  Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => _TakeoverDetails(ad: ad)));
}

class _TakeoverPage extends StatefulWidget {
  const _TakeoverPage({required this.ad, this.dock = true});
  final AdItem ad;
  /// true = Takeover الهوم (بينزل مكانه كبانر)؛ false = من دوسة على بانر (بيتقفل وبس)
  final bool dock;
  @override
  State<_TakeoverPage> createState() => _TakeoverPageState();
}

class _TakeoverPageState extends State<_TakeoverPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _p;
  Timer? _closeTimer;
  bool _canClose = false, _closing = false, _counted = false;

  @override
  void initState() {
    super.initState();
    final secs = (widget.ad.durationS ?? 3).clamp(2, 15).toInt();
    _p = AnimationController(vsync: this, duration: Duration(seconds: secs))
      ..addStatusListener((s) { if (s == AnimationStatus.completed) _close(); })
      // المشاهدة بتتحسب بس بعد ثانية فعلية والإعلان ظاهر (مش وهو مستخبي تحت نافذة)
      ..addListener(() {
        if (!_counted && _p.value * secs >= 1) { _counted = true; Ads.impression(widget.ad); }
      })
      ..forward();
    // العدّاد بيقف لو نافذة طلعت فوق الإعلان أو التطبيق راح الخلفية، وبيكمّل لما ترجع
    AdsRouteGuard.popups.addListener(_sync);
    WidgetsBinding.instance.addObserver(this);
    final after = (widget.ad.closeAfterS ?? 0).clamp(0, 10).toInt();
    if (after == 0) {
      _canClose = true;
    } else {
      _closeTimer = Timer(Duration(seconds: after), () { if (mounted) setState(() => _canClose = true); });
    }
  }

  bool _foreground = true;
  void _sync() {
    if (_closing || !mounted) return;
    final run = AdsRouteGuard.clear && _foreground;
    if (run && !_p.isAnimating && !_p.isCompleted) {
      _p.forward();
    } else if (!run && _p.isAnimating) {
      _p.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    AdsRouteGuard.popups.removeListener(_sync);
    WidgetsBinding.instance.removeObserver(this);
    _p.dispose();
    _closeTimer?.cancel();
    super.dispose();
  }

  /// يقفل وينزل مكانه في الهوم (البانر لازم يبقى موجود قبل الـ pop عشان الـ Hero يطير له)
  Future<void> _close({bool thenDetails = false}) async {
    if (_closing || !mounted) return;
    _closing = true;
    _p.stop();
    if (widget.dock) {
      Ads.docked.value = widget.ad;
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    final nav = Navigator.of(context);
    final ctx = nav.context;
    nav.pop();
    if (thenDetails) {
      await Future<void>.delayed(const Duration(milliseconds: 480));
      if (ctx.mounted) openTakeoverDetails(ctx, widget.ad);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final size = MediaQuery.of(context).size;
    final w = math.min(size.width * 0.88, 420.0);
    final h = math.min(size.height * 0.68, 640.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () { if (_canClose) _close(); },   // دوسة برّه الكارت = قفل (لما الـ ✕ تبقى ظاهرة)
      child: Center(
        child: GestureDetector(
          onTap: () {},   // جوه الكارت مش بيقفل
          child: SizedBox(
            width: w, height: h,
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(fit: StackFit.expand, children: [
                  if (widget.dock)
                    Hero(tag: takeoverHeroTag(ad), flightShuttleBuilder: takeoverShuttle, child: AdMedia(ad))
                  else
                    AdMedia(ad),
                  const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0, 0.2, 0.55, 1],
                      colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0xDD000000)]))),
                  Positioned(left: 12, right: 12, top: 10, child: Column(children: [
                    AnimatedBuilder(animation: _p, builder: (_, __) => ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(value: _p.value, minHeight: 2.5,
                          backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(Colors.white)))),
                    const SizedBox(height: 8),
                    Row(children: [
                      AdLogo(ad, size: 28),
                      const SizedBox(width: 8),
                      Expanded(child: Text(ad.sponsorName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800))),
                      AdLabel(demo: ad.demo),
                      const SizedBox(width: 4),
                      AnimatedOpacity(
                        opacity: _canClose ? 1 : 0, duration: const Duration(milliseconds: 200),
                        child: IconButton(
                          tooltip: _t('Close', 'قفل'),
                          onPressed: _canClose ? () => _close() : null,
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                        ),
                      ),
                    ]),
                  ])),
                  Positioned(left: 16, right: 16, bottom: 16, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    if (ad.title != null)
                      Text(ad.title!, style: TextStyle(color: ad.fg ?? Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.25)),
                    if (ad.body != null) ...[
                      const SizedBox(height: 6),
                      Text(ad.body!, maxLines: 3, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45)),
                    ],
                    if (ad.hasLink || ad.details != null) ...[
                      const SizedBox(height: 14),
                      SizedBox(width: double.infinity, height: 46, child: ElevatedButton(
                        onPressed: () => _close(thenDetails: true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: Text(ad.cta ?? _t('Learn more', 'اعرف أكتر'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      )),
                    ],
                  ])),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// صفحة تفاصيل الراعي جوه التطبيق (الباقة البريميوم)
class _TakeoverDetails extends StatelessWidget {
  const _TakeoverDetails({required this.ad});
  final AdItem ad;
  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    return Directionality(
      textDirection: AppLang.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0B0F),
        body: ListView(padding: EdgeInsets.only(bottom: pad.bottom + 24), children: [
          Stack(children: [
            AspectRatio(aspectRatio: 4 / 3, child: AdMedia(ad)),
            Positioned(top: pad.top + 6, left: 8, right: 8, child: Row(children: [
              IconButton(onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white)),
              const Spacer(),
              Padding(padding: const EdgeInsets.all(8), child: AdLabel(demo: ad.demo)),
            ])),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                AdLogo(ad, size: 34),
                const SizedBox(width: 10),
                Expanded(child: Text(ad.sponsorName ?? '', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800))),
              ]),
              if (ad.title != null) ...[
                const SizedBox(height: 14),
                Text(ad.title!, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.3)),
              ],
              const SizedBox(height: 10),
              Text(ad.details ?? ad.body ?? '', style: const TextStyle(color: Colors.white70, fontSize: 14.5, height: 1.65)),
              if (ad.hasLink) ...[
                const SizedBox(height: 22),
                SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
                  onPressed: () {
                    // صفحة جوه التطبيق: نقفل التفاصيل الأول عشان التاب يبان
                    if (ad.linkType == 'deeplink') Navigator.of(context).maybePop();
                    Ads.open(ad);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(ad.cta ?? _t('Learn more', 'اعرف أكتر'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                )),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
