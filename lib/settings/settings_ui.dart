import 'package:flutter/material.dart';

import '../app_lang.dart';

/// عناصر مشتركة لصفحات قايمة الترس (اتحولت من ملفات HTML).
/// واجهة بس: مفيش أي حاجة بتتحفظ في الداتابيز.

class SC {
  SC._();
  static const bg      = Color(0xFF0B0B0F);   // أسود بادجر
  static const card    = Color(0xFF16171C);
  static const cardAlt = Color(0xFF111216);
  static const chip    = Color(0xFF24262D);
  static const border  = Color(0xFF2A2C33);
  static const text    = Colors.white;
  static const muted   = Color(0xFFA6AAB5);
  static const accent  = Color(0xFFFF1A1A);   // أحمر بادجر
  static const success = Color(0xFF4ADE80);
  static const danger  = Color(0xFFFF5A65);
  static const warning = Color(0xFFFBBF24);
}

void sToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: SC.chip,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: SC.border)),
    ));
}

/// مودال معلومات. body: String = فقرة، List<String> = نقط.
Future<bool?> sInfo(
  BuildContext context, {
  required String title,
  String? subtitle,
  List<Object> body = const [],
  String? note,
  String? confirm,
  bool danger = false,
  IconData icon = Icons.info_outline_rounded,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.72),
    builder: (ctx) => Dialog(
      backgroundColor: SC.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: SC.border)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SIconBox(icon: icon, accent: true, size: 42),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: SC.text, fontSize: 17, fontWeight: FontWeight.w800)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: SC.muted, fontSize: 12, height: 1.6)),
                ],
              ])),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => Navigator.of(ctx).pop(false),
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: SC.chip, borderRadius: BorderRadius.circular(9), border: Border.all(color: SC.border)),
                  child: const Icon(Icons.close_rounded, color: SC.muted, size: 17),
                ),
              ),
            ]),
            const SizedBox(height: 18),
            for (final b in body)
              if (b is String)
                Padding(padding: const EdgeInsets.only(bottom: 10),
                  child: Text(b, style: const TextStyle(color: Color(0xFFD4D7DF), fontSize: 13, height: 1.75)))
              else if (b is List)
                Padding(padding: const EdgeInsets.only(bottom: 10),
                  child: SBullets(b.map((e) => '$e').toList(), color: const Color(0xFFD4D7DF), size: 13)),
            if (note != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: SC.cardAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: SC.border)),
                child: Text(note, style: const TextStyle(color: SC.muted, fontSize: 11.5, height: 1.7)),
              ),
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              SBtn(confirm == null ? AppLang.t('Close', 'قفل') : AppLang.t('Cancel', 'إلغاء'), onTap: () => Navigator.of(ctx).pop(false)),
              if (confirm != null) ...[
                const SizedBox(width: 10),
                SBtn(confirm, primary: !danger, danger: danger, onTap: () => Navigator.of(ctx).pop(true)),
              ],
            ]),
          ]),
        ),
      ),
    ),
  );
}

class SIconBox extends StatelessWidget {
  const SIconBox({super.key, required this.icon, this.accent = false, this.size = 38, this.color});
  final IconData icon;
  final bool accent;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: accent ? SC.accent.withOpacity(0.10) : SC.chip,
          borderRadius: BorderRadius.circular(size * 0.3),
          border: Border.all(color: accent ? SC.accent.withOpacity(0.2) : SC.border),
        ),
        child: Icon(icon, size: size * 0.5, color: color ?? (accent ? SC.accent : const Color(0xFFD9DCE4))),
      );
}

/// صفحة كاملة: هيدر بزرار رجوع + مقدمة + المحتوى
class SPage extends StatelessWidget {
  const SPage({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow,
    this.introTitle,
    this.introText,
    this.introExtra,
    required this.children,
    this.bottomText,
    this.controller,
  });

  final String title, subtitle;
  final String? eyebrow, introTitle, introText, bottomText;
  final Widget? introExtra;
  final List<Widget> children;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: SC.bg,
        body: SafeArea(
          bottom: false,
          // SingleChildScrollView عشان Scrollable.ensureVisible يوصل لأي سكشن
          child: SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  borderRadius: BorderRadius.circular(13),
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: SC.card, borderRadius: BorderRadius.circular(13), border: Border.all(color: SC.border)),
                    child: const Icon(Icons.arrow_back_rounded, color: SC.text, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(color: SC.text, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: SC.muted, fontSize: 12, height: 1.5)),
                ])),
              ]),
              const SizedBox(height: 18),
              const Divider(height: 1, color: SC.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 22, 0, 22),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (eyebrow != null) ...[
                    Text(eyebrow!, style: const TextStyle(color: SC.accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                    const SizedBox(height: 10),
                  ],
                  if (introTitle != null)
                    Text(introTitle!, style: const TextStyle(color: SC.text, fontSize: 19, fontWeight: FontWeight.w800, height: 1.3)),
                  if (introText != null) ...[
                    const SizedBox(height: 8),
                    Text(introText!, style: const TextStyle(color: SC.muted, fontSize: 13, height: 1.75)),
                  ],
                  if (introExtra != null) introExtra!,
                ]),
              ),
              ...children,
              if (bottomText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(bottomText!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF777D8B), fontSize: 11, height: 1.8)),
                ),
            ]),
          ),
        ),
      );
}

class SSection extends StatelessWidget {
  const SSection({super.key, required this.icon, required this.title, this.description, required this.children});
  final IconData icon;
  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            SIconBox(icon: icon, accent: true, size: 36),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: SC.text, fontSize: 15, fontWeight: FontWeight.w700)),
              if (description != null) ...[
                const SizedBox(height: 3),
                Text(description!, style: const TextStyle(color: SC.muted, fontSize: 11.5, height: 1.5)),
              ],
            ])),
          ]),
          const SizedBox(height: 12),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ]),
      );
}

/// كارت فيه صفوف مفصولة بخط
class SCard extends StatelessWidget {
  const SCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: SC.card, borderRadius: BorderRadius.circular(15), border: Border.all(color: SC.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: SC.border),
            children[i],
          ],
        ]),
      );
}

class SRow extends StatelessWidget {
  const SRow({
    super.key,
    this.icon,
    required this.title,
    this.desc,
    this.value,
    this.valueMuted = false,
    this.trailing,
    this.onTap,
    this.highlight = false,
    this.below,
  });

  final IconData? icon;
  final String title;
  final String? desc, value;
  final bool valueMuted, highlight;
  final Widget? trailing, below;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: highlight ? SC.accent.withOpacity(0.045) : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            child: Row(children: [
              if (icon != null) ...[
                SIconBox(icon: icon!, accent: highlight),
                const SizedBox(width: 12),
              ],
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: SC.text, fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.4)),
                if (desc != null) ...[
                  const SizedBox(height: 4),
                  Text(desc!, style: const TextStyle(color: SC.muted, fontSize: 11.5, height: 1.6)),
                ],
                if (value != null) ...[
                  const SizedBox(height: 6),
                  Text(value!, style: TextStyle(color: valueMuted ? SC.muted : const Color(0xFFE2E4EA), fontSize: 13)),
                ],
                if (below != null) ...[const SizedBox(height: 8), below!],
              ])),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ]),
          ),
        ),
      );
}

class SSwitch extends StatelessWidget {
  const SSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Switch(
        value: value,
        onChanged: onChanged,
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : const Color(0xFFE5E7EB)),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? SC.accent : const Color(0xFF3B404B)),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? SC.accent : const Color(0xFF515765)),
      );
}

class SSelect extends StatelessWidget {
  const SSelect({super.key, required this.value, required this.options, required this.onChanged});
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 150),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: SC.chip, borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0xFF41444F))),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            dropdownColor: SC.card,
            iconEnabledColor: SC.muted,
            iconSize: 18,
            style: const TextStyle(color: SC.text, fontSize: 12),
            items: [
              for (final e in options.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ),
      );
}

class SBtn extends StatelessWidget {
  const SBtn(this.label, {super.key, required this.onTap, this.primary = false, this.danger = false, this.icon, this.expand = false});
  final String label;
  final VoidCallback onTap;
  final bool primary, danger, expand;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = primary ? SC.accent : danger ? SC.danger.withOpacity(0.09) : SC.chip;
    final fg = primary ? Colors.white : danger ? SC.danger : const Color(0xFFF0F1F5);
    final bd = primary ? SC.accent : danger ? SC.danger.withOpacity(0.35) : const Color(0xFF41444F);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: bd)),
          child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 15, color: fg), const SizedBox(width: 6)],
            Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class SPill extends StatelessWidget {
  const SPill(this.label, {super.key, this.dot = SC.muted, this.color});
  final String label;
  final Color dot;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color?.withOpacity(0.08) ?? SC.chip,
          borderRadius: BorderRadius.circular(color == null ? 8 : 20),
          border: Border.all(color: color?.withOpacity(0.22) ?? const Color(0xFF3B404C)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color ?? dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color ?? SC.muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// ملحوظة (أصفر افتراضي). title اختياري بيتكتب bold قبل النص.
class SNotice extends StatelessWidget {
  const SNotice({super.key, this.title, required this.text, this.color = SC.warning, this.icon = Icons.info_outline_rounded, this.plain = false});
  final String? title;
  final String text;
  final Color color;
  final IconData icon;
  final bool plain;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: plain ? SC.cardAlt : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: plain ? SC.border : color.withOpacity(0.2)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: plain ? SC.muted : color),
          const SizedBox(width: 10),
          Expanded(child: Text.rich(
            TextSpan(children: [
              if (title != null) TextSpan(text: '$title\n', style: const TextStyle(color: Color(0xFFE5E7EB), fontWeight: FontWeight.w700)),
              TextSpan(text: text),
            ]),
            style: const TextStyle(color: SC.muted, fontSize: 12, height: 1.7),
          )),
        ]),
      );
}

/// صندوق في آخر الصفحة (أيقونة حمرا + عنوان + نص)
class SFooterBox extends StatelessWidget {
  const SFooterBox({super.key, required this.title, required this.text, this.icon = Icons.verified_user_outlined});
  final String title, text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: SC.cardAlt, borderRadius: BorderRadius.circular(14), border: Border.all(color: SC.border)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 21, color: SC.accent),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: SC.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(text, style: const TextStyle(color: SC.muted, fontSize: 12, height: 1.7)),
          ])),
        ]),
      );
}

/// صندوق حفظ (عنوان + نص + زرار أحمر)
class SSaveArea extends StatelessWidget {
  const SSaveArea({super.key, required this.title, required this.text, required this.button, required this.onTap});
  final String title, text, button;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 6, bottom: 18),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: SC.cardAlt, borderRadius: BorderRadius.circular(14), border: Border.all(color: SC.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: const TextStyle(color: SC.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(color: SC.muted, fontSize: 12, height: 1.7)),
          const SizedBox(height: 14),
          SBtn(button, primary: true, expand: true, onTap: onTap),
        ]),
      );
}

class SEmpty extends StatelessWidget {
  const SEmpty({super.key, required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title, text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
        child: Column(children: [
          SIconBox(icon: icon, size: 48),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: SC.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: SC.muted, fontSize: 12, height: 1.7)),
        ]),
      );
}

class SBullets extends StatelessWidget {
  const SBullets(this.items, {super.key, this.color = SC.muted, this.size = 12});
  final List<String> items;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 7), child: Container(width: 5, height: 5, decoration: const BoxDecoration(color: SC.accent, shape: BoxShape.circle))),
              const SizedBox(width: 9),
              Expanded(child: Text(it, style: TextStyle(color: color, fontSize: size, height: 1.75))),
            ]),
          ),
      ]);
}
