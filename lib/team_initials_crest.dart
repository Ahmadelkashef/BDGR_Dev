import 'package:flutter/material.dart';

/// Default crest for a team that has no logo (owner, 24 Nov): a calm shield
/// with the team's initials. Drawn in code: no file, no egress.
/// Same initials rule as the dashboard (`tlInitials` in mgmt/index.html).
String teamInitials(String? name) {
  final cleaned = (name ?? '').replaceAll(RegExp(r'[^A-Za-z0-9À-ɏ ]'), ' ');
  const skip = {'fc', 'sc', 'cf', 'ac', 'afc', 'cd', 'ud', 'sv', 'al', 'el', 'the'};
  final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty && !skip.contains(w.toLowerCase())).toList();
  if (words.isEmpty) return '?';
  final s = words.length == 1
      ? (words.first.length > 3 ? words.first.substring(0, 3) : words.first)
      : words.take(3).map((w) => w[0]).join();
  return s.toUpperCase();
}

class TeamInitialsCrest extends StatelessWidget {
  final String? name; // English name (initials are Latin letters)
  final double size;
  const TeamInitialsCrest({super.key, required this.name, this.size = 30});

  @override
  Widget build(BuildContext context) {
    final ini = teamInitials(name);
    return SizedBox(width: size, height: size, child: CustomPaint(
      painter: _ShieldPainter(),
      child: Padding(
        padding: EdgeInsets.only(bottom: size * 0.12),
        child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.14),
          child: Text(ini, maxLines: 1, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900,
            fontSize: size * (ini.length > 2 ? 0.28 : 0.34), letterSpacing: 0.5))))),
      )));
  }
}

class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    // convex outline only (no concave paths inside clips: Samsung Vulkan rule)
    final p = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.92, h * 0.14)
      ..lineTo(w * 0.92, h * 0.56)
      ..lineTo(w * 0.5, h)
      ..lineTo(w * 0.08, h * 0.56)
      ..lineTo(w * 0.08, h * 0.14)
      ..close();
    c.drawPath(p, Paint()..color = const Color(0xFF2E2E38));
    c.drawPath(p, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.04).clamp(1.0, 2.0).toDouble()
      ..color = const Color(0x33FFFFFF));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
