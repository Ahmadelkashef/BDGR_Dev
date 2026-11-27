import 'package:flutter/material.dart';
import 'app_lang.dart';
import 'brand.dart';
import 'profile/profile_page.dart' show captureVerifiedLocation;

/// كارت "شوف ترتيبك في محافظتك": بيظهر في أي مكان فيه فلتر موقع واليوزر معندوش موقع متأكد منه.
/// زرار واحد بس (استخدم موقعي) — مفيش اختيار يدوي علشان ترتيب وجوايز المحافظة تبقى بالمكان الحقيقي.
class LocationNeededCard extends StatefulWidget {
  final bool isArabic;
  final bool compact;
  final VoidCallback onDone;
  const LocationNeededCard({super.key, required this.isArabic, required this.onDone, this.compact = false});
  @override
  State<LocationNeededCard> createState() => _LocationNeededCardState();
}

class _LocationNeededCardState extends State<LocationNeededCard> {
  bool _busy = false;
  String t(String en, String ar) => widget.isArabic ? ar : en;

  Future<void> _go() async {
    setState(() => _busy = true);
    final r = await captureVerifiedLocation(context);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) {
      final name = widget.isArabic ? (r['governorate_ar'] ?? r['governorate']) : r['governorate'];
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('📍 You are in $name', '📍 انت في $name'))));
      widget.onDone();
    }
  }

  Widget _point(String e, String s) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 24, child: Text(e, style: const TextStyle(fontSize: 14))),
      Expanded(child: Text(s, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45))),
    ]));

  @override
  Widget build(BuildContext context) {
    final btn = SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(
      onPressed: _busy ? null : _go,
      style: ElevatedButton.styleFrom(backgroundColor: Brand.green, foregroundColor: Colors.black, elevation: 0,
        disabledBackgroundColor: Brand.green.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.my_location_rounded, size: 18),
      label: Text(_busy ? t('Finding your area…', 'بنحدد منطقتك…') : t('Use my location', 'استخدم موقعي'),
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5))));
    if (widget.compact) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Brand.green.withOpacity(0.05),
          border: Border.all(color: Brand.green.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('📍 Compete in your governorate', '📍 نافس في محافظتك'),
            style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(t('See your rank there and go for the #1 prize. We only use your governorate and city.',
                 'شوف ترتيبك فيها وخش على جايزة الأول. بنستخدم المحافظة والمدينة بس.'),
            style: const TextStyle(color: Colors.white60, fontSize: 12.5, height: 1.45)),
          const SizedBox(height: 12),
          btn,
        ]));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Brand.green.withOpacity(0.10), const Color(0xFF151518)]),
          border: Border.all(color: Brand.green.withOpacity(0.35))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 48, height: 48, alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Brand.green.withOpacity(0.12)),
            child: const Icon(Icons.location_on_rounded, color: Brand.green, size: 26)),
          const SizedBox(height: 12),
          Text(t('See your rank in your governorate', 'شوف ترتيبك في محافظتك'),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          _point('🏆', t('Compete for the #1 prize in your governorate and city', 'اتنافس على جايزة الأول في محافظتك ومدينتك')),
          _point('👥', t('Know where you stand among people near you', 'اعرف ترتيبك بين الناس اللي حواليك')),
          _point('🔒', t("We never show your location to anyone — only your governorate and city are used.",
                         'مش بنعرض مكانك لحد. بنستخدم المحافظة والمدينة بس.')),
          const SizedBox(height: 16),
          btn,
        ]),
      ),
    );
  }
}
