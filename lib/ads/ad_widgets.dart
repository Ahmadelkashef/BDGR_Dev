import 'dart:async';

import 'package:flutter/material.dart';

import 'ad_takeover.dart';
import 'package:video_player/video_player.dart';

import '../app_lang.dart';
import '../media_cache.dart';
import 'ads.dart';
import '../web/web_layout.dart' show WebStage;

export 'ads.dart';

String _t(String en, String ar) => AppLang.t(en, ar);

/// مكان إعلان (slot): مفيش إعلان = مفيش أي حاجة بتترسم (SizedBox.shrink).
/// [eventId] للفانتازي (إعلان جولة معينة)، [sport] للرياضات.
/// [prefixEn]/[prefixAr]: كلمة قبل اسم الراعي في قوالب "برعاية" (لو الإعلان نفسه مالوش عنوان).
class AdSlot extends StatefulWidget {
  const AdSlot(this.placement, {
    super.key, this.eventId, this.sport, this.slotKey = '', this.padding = EdgeInsets.zero,
    this.prefixEn, this.prefixAr, this.center = false, this.compact = false, this.boxed = false,
    this.banner = false,
  });

  final String placement;
  final String? eventId, sport;
  final String slotKey;
  final EdgeInsetsGeometry padding;
  final String? prefixEn, prefixAr;
  final bool center, compact;
  /// boxed = جوه كبسولة غامقة (لما يبقى فوق صورة أو هيتشير كصورة)
  final bool boxed;
  /// banner = أي إعلان صورة/فيديو (native / video / banner) بيترسم بانر ثابت من غير ✕؛
  /// الدوسة: لينك برّه، أو الكارت الكبير اللي بيتقفل لوحده بعد كام ثانية (onAdBannerTap)
  final bool banner;

  @override
  State<AdSlot> createState() => _AdSlotState();
}

class _AdSlotState extends State<AdSlot> {
  @override
  void initState() {
    super.initState();
    Ads.ensure();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: Ads.version,
        builder: (context, _, __) {
          final ad = Ads.pick(widget.placement,
              eventId: widget.eventId, sport: widget.sport, slotKey: widget.slotKey);
          if (ad == null) return const SizedBox.shrink();
          Widget v = widget.banner && const {'banner', 'native', 'video', 'fullscreen'}.contains(ad.template)
              ? AdImpression(ad: ad, child: AdBanner(ad, onTap: () => onAdBannerTap(context, ad)))
              : AdView(ad,
              prefixEn: widget.prefixEn, prefixAr: widget.prefixAr,
              center: widget.center, compact: widget.compact);
          if (widget.boxed) {
            v = Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: const Color(0xE6101014), borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12)),
              child: v,
            ));
          }
          return Padding(padding: widget.padding, child: v);
        },
      );
}

/// يرسم إعلان حسب القالب بتاعه + بيعدّ المشاهدة بعد ثانية ظاهر
class AdView extends StatelessWidget {
  const AdView(this.ad, {super.key, this.prefixEn, this.prefixAr, this.center = false, this.compact = false});
  final AdItem ad;
  final String? prefixEn, prefixAr;
  final bool center, compact;

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (ad.template) {
      'text' => AdTextLine(ad, center: center),
      'title' => AdSponsorLine(ad, big: true, center: center,
          prefix: _t(prefixEn ?? 'Presented by', prefixAr ?? 'برعاية')),
      'logo' => AdSponsorLine(ad, big: false, center: center, chip: compact,
          prefix: _t(prefixEn ?? 'Powered by', prefixAr ?? 'مقدّم من')),
      'banner' => AdBanner(ad),
      'native' || 'video' => AdNativeCard(ad, compact: compact),
      'story' => Align(alignment: AlignmentDirectional.centerStart, child: AdStoryCircle(ad)),
      'fullscreen' => AdBanner(ad),
      _ => const SizedBox.shrink(),
    };
    return AdImpression(ad: ad, child: child);
  }
}

/// بيعدّ مشاهدة لما الإعلان يفضل ظاهر ثانية (مرة واحدة في الجلسة)
class AdImpression extends StatefulWidget {
  const AdImpression({super.key, required this.ad, required this.child});
  final AdItem ad;
  final Widget child;
  @override
  State<AdImpression> createState() => _AdImpressionState();
}

class _AdImpressionState extends State<AdImpression> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _t?.cancel();
    _t = Timer(const Duration(seconds: 1), () {
      if (mounted && (TickerMode.valuesOf(context).enabled)) Ads.impression(widget.ad);
    });
  }

  @override
  void didUpdateWidget(AdImpression old) {
    super.didUpdateWidget(old);
    if (old.ad.id != widget.ad.id) _start();
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// "إعلان" — دايماً ظاهر على أي إعلان (صراحة مع اليوزر + قواعد جوجل بلاي)
class AdLabel extends StatelessWidget {
  const AdLabel({super.key, this.demo = false, this.onDark = true});
  final bool demo, onDark;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: onDark ? Colors.black.withOpacity(0.45) : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24, width: 0.6),
        ),
        child: Text(
          demo ? _t('Ad · Demo', 'إعلان · تجريبي') : _t('Ad', 'إعلان'),
          style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.2, height: 1.2),
        ),
      );
}

class AdLogo extends StatelessWidget {
  const AdLogo(this.ad, {super.key, this.size = 22});
  final AdItem ad;
  final double size;
  @override
  Widget build(BuildContext context) {
    final url = ad.sponsorLogo;
    Widget fallback() => Container(
          width: size, height: size, alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(size * 0.28)),
          child: Text(ad.displayName.isEmpty ? '•' : ad.displayName.characters.first.toUpperCase(),
              style: TextStyle(color: Colors.white, fontSize: size * 0.5, fontWeight: FontWeight.w900)),
        );
    if (url == null) return fallback();
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Image(
        image: MediaCache.image(url), width: size, height: size, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      ),
    );
  }
}

/// قالب title / logo: "برعاية [لوجو] اسم الراعي" — هادي وصغير
class AdSponsorLine extends StatelessWidget {
  const AdSponsorLine(this.ad, {super.key, required this.big, required this.prefix, this.center = false, this.chip = false});
  final AdItem ad;
  final bool big, center;
  /// chip = مكان ضيق (كارت رياضة): كلمة صغيرة + اللوجو بس على خلفية غامقة
  final bool chip;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final fg = ad.fg ?? Colors.white;
    if (chip) {
      return Container(
        padding: const EdgeInsetsDirectional.fromSTEB(6, 3, 3, 3),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24, width: 0.6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(prefix, style: const TextStyle(color: Colors.white70, fontSize: 8.5, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          AdLogo(ad, size: 15),
        ]),
      );
    }
    final line = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(ad.title ?? prefix,
            style: TextStyle(color: fg.withOpacity(0.6), fontSize: big ? 11.5 : 10.5, fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        AdLogo(ad, size: big ? 22 : 17),
        const SizedBox(width: 6),
        Flexible(
          child: Text(ad.sponsorName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontSize: big ? 13 : 11.5, fontWeight: FontWeight.w800)),
        ),
        if (ad.demo) ...[const SizedBox(width: 6), const AdLabel(demo: true, onDark: false)],
      ],
    );
    final box = (ad.bg != null)
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: ad.bg, borderRadius: BorderRadius.circular(20)),
            child: line)
        : line;
    final tappable = ad.hasLink ? GestureDetector(onTap: () => Ads.open(ad), behavior: HitTestBehavior.opaque, child: box) : box;
    return center ? Center(child: tappable) : Align(alignment: AlignmentDirectional.centerStart, child: tappable);
  }
}

/// قالب text: سطر كلام بس (+ "إعلان")
class AdTextLine extends StatelessWidget {
  const AdTextLine(this.ad, {super.key, this.center = false});
  final AdItem ad;
  final bool center;
  @override
  Widget build(BuildContext context) {
    final fg = ad.fg ?? Colors.white70;
    final text = ad.body ?? ad.title ?? ad.sponsorName ?? '';
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        AdLabel(demo: ad.demo, onDark: false),
        const SizedBox(width: 8),
        Flexible(
          child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: center ? TextAlign.center : TextAlign.start,
              style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600, height: 1.35)),
        ),
        if (ad.hasLink && ad.cta != null) ...[
          const SizedBox(width: 8),
          Text(ad.cta!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
        ],
      ],
    );
    final box = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: ad.bg ?? Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: row,
    );
    return ad.hasLink ? GestureDetector(onTap: () => Ads.open(ad), child: box) : box;
  }
}

/// صورة أو فيديو الإعلان (الفيديو صامت ومتكرر، بيتكاش على الموبايل)
class AdMedia extends StatelessWidget {
  const AdMedia(this.ad, {super.key, this.fit = BoxFit.cover});
  final AdItem ad;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    final url = ad.media;
    if (url == null) {
      return Container(color: ad.bg ?? const Color(0xFF15151B),
          alignment: Alignment.center, child: AdLogo(ad, size: 44));
    }
    if (ad.isVideo) return AdVideo(url: url, poster: ad.poster, fit: fit);
    return Image(
      image: MediaCache.image(url), fit: fit,
      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF15151B)),
    );
  }
}

class AdVideo extends StatefulWidget {
  const AdVideo({super.key, required this.url, this.poster, this.fit = BoxFit.cover, this.onEnded, this.loop = true});
  final String url;
  final String? poster;
  final BoxFit fit;
  final bool loop;
  final VoidCallback? onEnded;
  @override
  State<AdVideo> createState() => _AdVideoState();
}

class _AdVideoState extends State<AdVideo> {
  VideoPlayerController? _c;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = await MediaCache.video(widget.url, options: VideoPlayerOptions(mixWithOthers: true));
      if (!mounted) { c.dispose(); return; }
      await c.initialize();
      await c.setVolume(0);   // الإعلانات مش بتشتغل بصوت لوحدها أبداً
      await c.setLooping(widget.loop);
      c.addListener(_tick);
      if (!mounted) { c.dispose(); return; }
      setState(() => _c = c);
      await c.play();
    } catch (e) {
      debugPrint('Ad video failed: $e');
    }
  }

  void _tick() {
    final c = _c;
    if (c == null || widget.loop || _ended) return;
    final v = c.value;
    if (v.isInitialized && v.duration > Duration.zero && v.position >= v.duration - const Duration(milliseconds: 150)) {
      _ended = true;
      widget.onEnded?.call();
    }
  }

  @override
  void dispose() {
    _c?.removeListener(_tick);
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final poster = widget.poster;
    final under = poster != null
        ? Image(image: MediaCache.image(poster), fit: widget.fit, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF15151B)))
        : const ColoredBox(color: Color(0xFF15151B));
    if (c == null || !c.value.isInitialized) return SizedBox.expand(child: under);
    return SizedBox.expand(
      child: FittedBox(
        fit: widget.fit, clipBehavior: Clip.hardEdge,
        child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
      ),
    );
  }
}

/// قالب banner: صورة/فيديو عريض (3:1 تقريباً) + "إعلان" في الركن
class AdBanner extends StatelessWidget {
  const AdBanner(this.ad, {super.key, this.aspect = 3.2, this.onTap});
  final AdItem ad;
  final double aspect;
  /// null = اللينك على طول (Ads.open)
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final box = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: aspect,
        child: Stack(fit: StackFit.expand, children: [
          AdMedia(ad),
          if (ad.title != null || ad.cta != null)
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xAA000000)]))),
          PositionedDirectional(top: 8, end: 8, child: AdLabel(demo: ad.demo)),
          if (ad.title != null || ad.cta != null)
            PositionedDirectional(start: 12, end: 12, bottom: 9, child: Row(children: [
              if (ad.title != null)
                Expanded(child: Text(ad.title!, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: ad.fg ?? Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)))
              else const Spacer(),
              if (ad.hasLink && ad.cta != null) _CtaPill(ad.cta!, small: true),
            ])),
        ]),
      ),
    );
    return GestureDetector(onTap: onTap ?? (ad.hasLink ? () => Ads.open(ad) : null), child: box);
  }
}

class _CtaPill extends StatelessWidget {
  const _CtaPill(this.text, {this.small = false});
  final String text;
  final bool small;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 10 : 14, vertical: small ? 5 : 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: Colors.black, fontSize: small ? 11.5 : 13, fontWeight: FontWeight.w800)),
      );
}

/// قالب native / video: كارت شبه البوست (الراعي + "إعلان" + صورة/فيديو + عنوان + زرار) وبيتقفل بـ ×
class AdNativeCard extends StatelessWidget {
  const AdNativeCard(this.ad, {super.key, this.compact = false, this.aspect});
  final AdItem ad;
  final bool compact;
  final double? aspect;
  @override
  Widget build(BuildContext context) {
    final fg = ad.fg ?? Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: ad.bg ?? const Color(0xFF121217),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 4, 8),
          child: Row(children: [
            AdLogo(ad, size: 30),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ad.sponsorName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w800)),
              Text(ad.demo ? _t('Sponsored · Demo', 'إعلان · تجريبي') : _t('Sponsored', 'إعلان'),
                  style: TextStyle(color: fg.withOpacity(0.5), fontSize: 10.5)),
            ])),
            IconButton(
              tooltip: _t('Hide', 'إخفاء'),
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, color: fg.withOpacity(0.45), size: 18),
              onPressed: () => Ads.dismiss(ad),
            ),
          ]),
        ),
        if (ad.media != null || ad.template == 'video')
          GestureDetector(
            onTap: ad.hasLink ? () => Ads.open(ad) : null,
            child: AspectRatio(aspectRatio: aspect ?? (compact ? 16 / 9 : (ad.isVideo ? 4 / 5 : 16 / 10)), child: AdMedia(ad)),
          ),
        if (ad.title != null || ad.body != null || (ad.hasLink && ad.cta != null))
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (ad.title != null)
                  Text(ad.title!, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w800, height: 1.3)),
                if (ad.body != null) ...[
                  const SizedBox(height: 3),
                  Text(ad.body!, maxLines: compact ? 2 : 3, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg.withOpacity(0.7), fontSize: 12.5, height: 1.4)),
                ],
              ])),
              if (ad.hasLink) ...[
                const SizedBox(width: 10),
                GestureDetector(onTap: () => Ads.open(ad), child: _CtaPill(ad.cta ?? _t('Learn more', 'اعرف أكتر'))),
              ],
            ]),
          ),
      ]),
    );
  }
}

/// قالب story: دايرة في صف الستوريز (حلقة رمادي/أبيض، مش أحمر — الأحمر = ستوري جديدة)
class AdStoryCircle extends StatelessWidget {
  const AdStoryCircle(this.ad, {super.key, this.size = 64});
  final AdItem ad;
  final double size;
  @override
  Widget build(BuildContext context) => AdImpression(
        ad: ad,
        child: GestureDetector(
          onTap: () => openAdStory(context, ad),
          child: SizedBox(
            width: size + 12,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: size, height: size, padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFFBFC6D1), Color(0xFF5E6672)])),
                child: Container(
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
                  padding: const EdgeInsets.all(2),
                  child: ClipOval(child: ad.poster != null || (ad.media != null && !ad.isVideo)
                      ? Image(image: MediaCache.image(ad.poster ?? ad.media!), fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(child: AdLogo(ad, size: size * 0.5)))
                      : Center(child: AdLogo(ad, size: size * 0.55))),
                ),
              ),
              const SizedBox(height: 5),
              Text(ad.sponsorName ?? _t('Ad', 'إعلان'), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600)),
              Text(_t('Ad', 'إعلان'), style: const TextStyle(color: Colors.white38, fontSize: 9)),
            ]),
          ),
        ),
      );
}

/// فتح ستوري الإعلان: شاشة كاملة، صورة 6 ثواني أو فيديو ≤ 15 ثانية، بتتقفل في أي وقت
Future<void> openAdStory(BuildContext context, AdItem ad) => Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (_, __, ___) => WebStage(child: _AdStoryPage(ad: ad)),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ),
    );

class _AdStoryPage extends StatefulWidget {
  const _AdStoryPage({required this.ad});
  final AdItem ad;
  @override
  State<_AdStoryPage> createState() => _AdStoryPageState();
}

class _AdStoryPageState extends State<_AdStoryPage> with SingleTickerProviderStateMixin {
  late final AnimationController _p;

  @override
  void initState() {
    super.initState();
    final secs = widget.ad.isVideo ? (widget.ad.durationS ?? 15).clamp(3, 15).toInt() : 6;
    _p = AnimationController(vsync: this, duration: Duration(seconds: secs))
      ..addStatusListener((s) { if (s == AnimationStatus.completed && mounted) Navigator.of(context).maybePop(); })
      ..forward();
  }

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdFullscreen(
        ad: widget.ad,
        progress: _p,
        onClose: () => Navigator.of(context).maybePop(),
      );
}

/// قالب fullscreen: إعلان بالطول (في الفيد الكامل بين البوستات، أو ستوري)
class AdFullscreen extends StatelessWidget {
  const AdFullscreen({super.key, required this.ad, this.progress, this.onClose, this.showSwipeHint = false});
  final AdItem ad;
  final Animation<double>? progress;
  final VoidCallback? onClose;
  final bool showSwipeHint;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    return AdImpression(
      ad: ad,
      child: Material(
        color: Colors.black,
        child: Stack(fit: StackFit.expand, children: [
          GestureDetector(onTap: ad.hasLink ? () => Ads.open(ad) : null,
              child: AdMedia(ad, fit: ad.media == null ? BoxFit.cover : BoxFit.cover)),
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              stops: [0, 0.18, 0.6, 1],
              colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0xCC000000)]))),
          Positioned(left: 12, right: 12, top: pad.top + 8, child: Column(children: [
            if (progress != null)
              AnimatedBuilder(animation: progress!, builder: (_, __) => ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: progress!.value, minHeight: 2.5,
                    backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(Colors.white)))),
            const SizedBox(height: 10),
            Row(children: [
              AdLogo(ad, size: 30),
              const SizedBox(width: 9),
              Expanded(child: Text(ad.sponsorName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800))),
              AdLabel(demo: ad.demo),
              if (onClose != null)
                IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, color: Colors.white)),
            ]),
          ])),
          Positioned(left: 16, right: 16, bottom: pad.bottom + 24, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (ad.title != null)
              Text(ad.title!, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.25)),
            if (ad.body != null) ...[
              const SizedBox(height: 6),
              Text(ad.body!, maxLines: 4, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.45)),
            ],
            if (ad.hasLink) ...[
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, height: 46, child: ElevatedButton(
                onPressed: () => Ads.open(ad),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(ad.cta ?? _t('Learn more', 'اعرف أكتر'), style: const TextStyle(fontWeight: FontWeight.w800)),
              )),
            ],
            if (showSwipeHint) ...[
              const SizedBox(height: 10),
              Center(child: Text(_t('Swipe up to skip', 'اسحب لفوق عشان تكمّل'),
                  style: const TextStyle(color: Colors.white54, fontSize: 11.5))),
            ],
          ])),
        ]),
      ),
    );
  }
}
