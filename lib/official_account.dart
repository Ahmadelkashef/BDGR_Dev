import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'brand.dart';

/// حساب BDGR الرسمي: حساب واحد بس في الداتابيز (`users.is_official`).
/// محدش بيعمل بيه login، بيتدار من لوحة التحكم (قسم "حساب BDGR").
class OfficialAccount {
  OfficialAccount._();

  static const Color gold = Color(0xFFD4AF37);
  static const Color goldSoft = Color(0x33D4AF37);

  static int? _id;
  static Future<int?>? _loading;

  /// رقم الحساب الرسمي لو اتحمّل (null لسه).
  static int? get id => _id;

  /// بيجيب الرقم مرة واحدة ويخزنه. لو فشل يجرب تاني المرة الجاية.
  static Future<int?> load() {
    if (_id != null) return Future.value(_id);
    return _loading ??= _fetch();
  }

  static Future<int?> _fetch() async {
    try {
      final res = await Supabase.instance.client.rpc('official_account');
      final v = res is Map ? res['user_id'] : null;
      _id = v is num ? v.toInt() : int.tryParse('${v ?? ''}');
    } catch (e) {
      debugPrint('official_account error: $e');
    }
    _loading = null;
    return _id;
  }

  static bool isOfficial(Object? userId) {
    if (_id == null || userId == null) return false;
    final v = userId is num ? userId.toInt() : int.tryParse(userId.toString());
    return v == _id;
  }
}

/// علامة الحساب الرسمي (دهبي) جنب الاسم.
class OfficialBadge extends StatelessWidget {
  const OfficialBadge({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.verified, color: OfficialAccount.gold, size: size);
}

/// البادجر الأبيض على أسود (لوجو BDGR) — لما الحساب الرسمي ملوش صورة.
class OfficialAvatarFallback extends StatelessWidget {
  const OfficialAvatarFallback({super.key, this.padding = 0.22});
  final double padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, c) {
          final side = c.biggest.shortestSide.isFinite ? c.biggest.shortestSide : 90.0;
          return ColoredBox(
            color: Colors.black,
            child: Padding(
              padding: EdgeInsets.all(side * padding),
              child: Image.asset(Brand.badger, fit: BoxFit.contain),
            ),
          );
        },
      );
}

/// دايرة BDGR الصغيرة (في الفيد والريلز والستوريز): لوجو البادجر الأبيض على أسود.
/// الدهبي بس لعلامة التوثيق، مش للأفاتار.
class OfficialMark extends StatelessWidget {
  const OfficialMark({super.key, this.size = 32});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black,
          border: Border.all(color: Colors.white24, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: const OfficialAvatarFallback(padding: 0.2),
      );
}
