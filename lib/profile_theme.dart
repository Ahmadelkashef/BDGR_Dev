part of 'profile_page.dart';

const Color _kRed = Color(0xFFFF0000);
const Color _kBlack = Color(0xFF000000);
const Color _kCardBg = Color(0xFF1A1A1A);
const Color _kCardBorder = Color(0xFF303030);
const Color _kSecondaryBg = Color(0xFF242424);
const Color _kSecondaryBorder = Color(0xFF414141);
const Color _kLine = Color(0xFF333333);
const Color _kGray500 = Color(0xFF6B7280);
const Color _kGray400 = Color(0xFF9CA3AF);
const Color _kGray300 = Color(0xFFD1D5DB);
const Color _kGray200 = Color(0xFFE5E7EB);
const Color _kGray600 = Color(0xFF4B5563);
const Color _kModalBorder = Color(0xFF383838);
const Color _kFieldBg = Color(0xFF111111);
const Color _kEmerald = Color(0xFF34D399);
const Color _kBlue = Color(0xFF60A5FA);

const String _kDefaultAvatar =
    'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&s=300';
const String _kDefaultAvatarLarge =
    'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&s=900';

// صور تجريبية بتحل محل اختيار الملف (UI فقط)
TextStyle _s(
  double size,
  FontWeight weight,
  Color color, {
  double? letterSpacing,
  double? height,
  TextDecoration decoration = TextDecoration.none,
}) {
  return TextStyle(
    color: color,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: height,
    decoration: decoration,
  );
}

IconData _sportIcon(String sport) {
  switch (sport.toLowerCase()) {
    case 'football':
    case 'soccer':
      return Icons.sports_soccer;
    case 'padel':
      return Icons.sports_tennis;
    case 'tennis':
      return Icons.sports_baseball;
    case 'basketball':
      return Icons.sports_basketball;
    case 'volleyball':
      return Icons.sports_volleyball;
    case 'swimming':
      return Icons.pool;
    case 'handball':
      return Icons.back_hand;
    case 'training':
    case 'fitness':
      return Icons.fitness_center;
    default:
      return Icons.military_tech;
  }
}

/// true = بيانات تجريبية للفانتازي (لحد ما نربط الباك اند).
/// false = الحالة الفاضية (أو التشكيلة اللي بتيجي من BuildTeam بس).
const bool _kUseFantasySampleData = true;

/// 1234567 -> 1,234,567
String _fmtNum(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
