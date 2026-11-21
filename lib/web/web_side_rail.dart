import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_config.dart';
import '../app_lang.dart';
import '../brand.dart';

/// الويب: عمود جانبي جنب الفيد على الشاشات الواسعة (زي أي موقع سوشيال).
/// فيه كارت الفانتازي الحقيقي (نفس داتا الهوم) + المسابقات + لينكات الشروط.
class WebSideRail extends StatefulWidget {
  const WebSideRail({super.key, required this.onOpenFantasy, required this.onOpenCompetitions});

  final VoidCallback onOpenFantasy;
  final VoidCallback onOpenCompetitions;

  static const double width = 320;

  @override
  State<WebSideRail> createState() => _WebSideRailState();
}

class _WebSideRailState extends State<WebSideRail> {
  Map<String, dynamic>? _hero;
  int? _players;
  Timer? _tick;

  bool get _ar => AppLang.isArabic;
  String _t(String en, String ar) => _ar ? ar : en;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await supa.rpc('home_fantasy_hero');
      if (r is Map && mounted) setState(() => _hero = Map<String, dynamic>.from(r));
    } catch (_) {}
    try {
      final n = await supa.rpc('home_fantasy_players_count');
      if (n is num && mounted) setState(() => _players = n.toInt());
    } catch (_) {}
  }

  String? get _countdown {
    final at = DateTime.tryParse('${_hero?['at'] ?? ''}');
    if (at == null) return null;
    final d = at.difference(DateTime.now());
    if (d.isNegative) return null;
    if (d.inDays > 0) return _t('${d.inDays}d ${d.inHours % 24}h', '${d.inDays}ي ${d.inHours % 24}س');
    if (d.inHours > 0) return _t('${d.inHours}h ${d.inMinutes % 60}m', '${d.inHours}س ${d.inMinutes % 60}د');
    return _t('${d.inMinutes}m', '${d.inMinutes}د');
  }

  String get _countdownLabel => _hero?['mode'] == 'opens'
      ? _t('Next round', 'الجولة الجاية')
      : _t('Deadline', 'آخر ميعاد');

  @override
  Widget build(BuildContext context) {
    final prize = _hero == null ? null : '${_hero![_ar ? 'prize_ar' : 'prize_en'] ?? ''}';
    final cd = _countdown;
    return SizedBox(
      width: WebSideRail.width,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 70, 0, 30),
        children: [
          _card(
            onTap: widget.onOpenFantasy,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_t('FANTASY FOOTBALL', 'فانتازي كورة'),
                  style: const TextStyle(color: Brand.green, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.3)),
              const SizedBox(height: 8),
              Text(_t('Build your team before the deadline', 'كوّن فريقك قبل آخر ميعاد'),
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, height: 1.25)),
              const SizedBox(height: 14),
              Row(children: [
                if (_players != null) _stat('$_players', _t('Players', 'لاعب')),
                if (cd != null) _stat(cd, _countdownLabel),
                if (prize != null && prize.isNotEmpty) _stat(prize, _t('1st Prize', 'جايزة الأول')),
              ]),
              const SizedBox(height: 16),
              Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFFF1A1A), borderRadius: BorderRadius.circular(13)),
                child: Text(_t('PLAY NOW', 'العب دلوقتي'),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          _card(
            onTap: widget.onOpenCompetitions,
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: Brand.navAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.emoji_events_outlined, color: Brand.navAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_t('Competitions', 'المسابقات'),
                      style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(_t('Pick your sports — coming soon', 'اختار رياضاتك — قريب'),
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                ]),
              ),
              Icon(_ar ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: Colors.white38),
            ]),
          ),
          const SizedBox(height: 26),
          Wrap(spacing: 14, runSpacing: 6, children: [
            _link(_t('Terms', 'الشروط'), '${Brand.legalUrl}#terms'),
            _link(_t('Privacy', 'الخصوصية'), '${Brand.legalUrl}#privacy'),
            _link(_t('Delete account', 'مسح الحساب'), '${Brand.legalUrl}#delete'),
          ]),
          const SizedBox(height: 8),
          Text('© ${DateTime.now().year} BDGR',
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11.5)),
        ],
      ),
    );
  }

  Widget _stat(String v, String l) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(l, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10.5)),
        ]),
      );

  Widget _card({required Widget child, VoidCallback? onTap}) => MouseRegion(
        cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF14151B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: child,
          ),
        ),
      );

  Widget _link(String label, String url) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => launchUrl(Uri.parse(url)),
          child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
        ),
      );
}
