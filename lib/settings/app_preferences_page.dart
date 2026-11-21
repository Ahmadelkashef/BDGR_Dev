import 'package:flutter/material.dart';

import '../app_config.dart';
import '../app_lang.dart';
import '../auth/video_preloader.dart';
import '../media_cache.dart';
import '../local_store.dart';
import 'settings_ui.dart';

/// تفضيلات التطبيق: اللغة + مسح الملفات المؤقتة + رقم النسخة.
/// كل حاجة هنا خاصة بالموبايل ده (مش بتتحفظ في الحساب).
class AppPreferencesPage extends StatefulWidget {
  const AppPreferencesPage({super.key});

  @override
  State<AppPreferencesPage> createState() => _AppPreferencesPageState();
}

class _AppPreferencesPageState extends State<AppPreferencesPage> {
  bool _clearing = false;

  bool get _ar => AppLang.isArabic;
  String _t(String en, String ar) => AppLang.t(en, ar);

  Future<void> _setLang(String lang) async {
    if ((lang == 'ar') == _ar) return;
    AppLang.set(lang);
    await LocalStore.setLang(lang);
    if (mounted) setState(() {});
  }

  Future<void> _clearCache() async {
    final ok = await sInfo(context,
        title: _t('Clear temporary files?', 'تمسح الملفات المؤقتة؟'),
        icon: Icons.cleaning_services_outlined,
        body: [_t('Saved images and videos on this phone will be removed. They download again when needed. Your account and data are not affected.',
                  'الصور والفيديوهات المتخزنة على الموبايل ده هتتمسح، وهتتحمّل تاني لما تحتاجها. حسابك وبياناتك مش هيتأثروا.')],
        confirm: _t('Clear', 'امسح'));
    if (ok != true || !mounted) return;
    setState(() => _clearing = true);
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await VideoPreloader.clearCache();
      await MediaCache.clear();
      if (mounted) sToast(context, _t('Temporary files cleared ✓', 'الملفات المؤقتة اتمسحت ✓'));
    } catch (e) {
      debugPrint('clear cache error: $e');
      if (mounted) sToast(context, _t('Something went wrong. Try again.', 'حصلت مشكلة. جرّب تاني.'));
    }
    if (mounted) setState(() => _clearing = false);
  }

  Widget _langSeg() => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: SC.chip, borderRadius: BorderRadius.circular(11)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final o in [('ar', 'عربي'), ('en', 'English')])
            GestureDetector(
              onTap: () => _setLang(o.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: (o.$1 == 'ar') == _ar ? SC.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(o.$2, style: TextStyle(color: SC.text, fontSize: 12.5,
                    fontWeight: (o.$1 == 'ar') == _ar ? FontWeight.w800 : FontWeight.w600)),
              ),
            ),
        ]),
      );

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
        child: SPage(
          title: _t('App Preferences', 'تفضيلات التطبيق'),
          subtitle: _t('Settings for the app on this phone.', 'إعدادات التطبيق على الموبايل ده.'),
          bottomText: 'BDGR · ${AppConfig.appVersion}',
          children: [
            SSection(
              icon: Icons.translate_rounded,
              title: _t('Language', 'اللغة'),
              children: [SCard(children: [
                SRow(title: _t('App language', 'لغة التطبيق'), trailing: _langSeg()),
              ])],
            ),
            SSection(
              icon: Icons.storage_rounded,
              title: _t('Storage', 'المساحة'),
              children: [SCard(children: [
                SRow(
                  icon: Icons.cleaning_services_outlined,
                  title: _t('Clear temporary files', 'امسح الملفات المؤقتة'),
                  desc: _t('Frees space and refreshes images that look outdated.',
                      'بيفضّي مساحة، وبيحدّث الصور اللي شكلها قديم.'),
                  trailing: _clearing
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(color: SC.accent, strokeWidth: 2))
                      : SBtn(_t('Clear', 'امسح'), onTap: _clearCache),
                ),
              ])],
            ),
            SSection(
              icon: Icons.info_outline_rounded,
              title: _t('About', 'عن التطبيق'),
              children: [SCard(children: [
                SRow(
                  title: _t('Version', 'النسخة'),
                  desc: _t('Mention it when you report a problem.', 'اذكرها لما تبلّغ عن مشكلة.'),
                  trailing: Text(AppConfig.appVersion,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: SC.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
                ),
              ])],
            ),
          ],
        ),
      );
}
