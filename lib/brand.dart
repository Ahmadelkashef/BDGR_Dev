import 'package:flutter/material.dart';

/// هوية التطبيق — الألوان والأصول في مكان واحد.
/// لو عايز تغير أي لون، غيره هنا بس وكل حاجة بتتغير.
class Brand {
  Brand._();

  // ── أصول ──────────────────────────────────────────────────────────────────
  static const String logo   = 'assets/logo_white.png';
  static const String badger = 'assets/badger_white.png';

  // ── ألوان رئيسية ──────────────────────────────────────────────────────────
  static const Color background = Color(0xFF0B0B0F);
  static const Color green      = Color(0xFF00FF87);  // للأزرار والـ CTAs

  // ── ألوان الـ Navigation Bar ───────────────────────────────────────────────
  /// لون التاب النشط (الدايرة والأيقونة والليبل)
  static const Color navAccent   = Color(0xFFFF0000);
  /// توهج تحت الدايرة النشطة
  static const Color navGlow     = Color(0x59FF0000);
  /// خلفية شريط التنقل
  static const Color navBg       = Color(0xFF1A1A1A);
  /// لون الأيقونة والليبل غير النشطين
  static const Color navInactive = Color(0x73FFFFFF);
  /// لون الأيقونة جوه الدايرة النشطة (لازم يكون واضح على navAccent)
  static const Color navIconActive = Color(0xFFFFFFFF);

  // ── مزايا ─────────────────────────────────────────────────────────────────
  /// علامة Verified جنب الاسم. مقفولة لحد ما يبقى ليها لوجيك توثيق حقيقي.
  static const bool showVerifiedBadge = false;

  // ── لينك المشاركة ─────────────────────────────────────────────────────────
  /// صفحة صغيرة (GitHub Pages) بتفتح التطبيق على المومنت، أو تعرض زرار التحميل.
  /// المحتوى نفسه ما بيظهرش فيها، بيتشاف جوه التطبيق بس.
  static const String shareLinkBase = 'https://ahmadelkashef.github.io/bdgr-link/';

  /// الشروط وسياسة الخصوصية + مسح الحساب (#terms / #privacy / #delete). نفس اللينك لـ Google Play.
  static const String legalUrl = '${shareLinkBase}legal/';

  static String momentShareLink(String momentId) => '$shareLinkBase?m=$momentId';
  /// بوست في الفيد: بيفتح التطبيق على البوست
  static String postShareLink(String postId) => '$shareLinkBase?p=$postId';
  /// بوست يوزر
  static String ugcShareLink(String id) => '$shareLinkBase?u=$id';
  /// دعوة لليج: بتفتح التطبيق وتدخّل اليوزر الليج بالكود
  static String leagueShareLink(String code) => '$shareLinkBase?l=${Uri.encodeComponent(code)}';
}

/// اللوجو الكامل (البادجر + BDGR + الشعار)
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.width = 220});
  final double width;

  @override
  Widget build(BuildContext context) =>
      Image.asset(Brand.logo, width: width, fit: BoxFit.contain);
}

/// شاشة السبلاش اللي بتظهر لحظة تشغيل التطبيق
class BrandSplash extends StatelessWidget {
  const BrandSplash({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Brand.background,
        child: Center(child: BrandLogo()),
      );
}
