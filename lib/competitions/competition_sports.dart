import 'package:flutter/material.dart';

/// قايمة الرياضات في مكان واحد: الهوم (كروت More coming) + صفحة المسابقات.
/// المفاتيح (id) لازم تطابق _competition_sports() في الداتابيز.

const String _kMedia = 'https://huggingface.co/datasets/Meekkii/IPLAY/resolve/main';

class CompSport {
  const CompSport(this.id, this.en, this.ar, this.image, this.icon, {this.video});

  final String id, en, ar;

  /// اسم ملف الصورة جوه Images/Competitions (بنفس حالة الحروف)
  final String image;
  final IconData icon;

  /// اسم الفيديو جوه Videos/Home (من غير .mp4). لو مش موجود أو ما اتحملش،
  /// الصورة هي اللي بتفضل ظاهرة.
  final String? video;

  String get imageUrl => '$_kMedia/Images/Competitions/$image';
  String? get videoUrl => video == null ? null : '$_kMedia/Videos/Home/$video.mp4';

  String name(bool ar) => ar ? this.ar : en;
}

const List<CompSport> kCompSports = [
  CompSport('football', 'Football', 'كرة القدم', 'football.jpg', Icons.sports_soccer, video: 'Football'),
  CompSport('padel', 'Padel', 'بادل', 'padel.jpg', Icons.sports_tennis, video: 'Padel'),
  CompSport('basketball', 'Basketball', 'كرة السلة', 'basketball.jpg', Icons.sports_basketball, video: 'Basketball'),
  CompSport('table_tennis', 'Table Tennis', 'تنس الطاولة', 'table-tennis.jpg', Icons.sports_tennis, video: 'Table_Tennis'),
  CompSport('handball', 'Handball', 'كرة اليد', 'handball.jpg', Icons.sports_handball, video: 'Handball'),
  CompSport('volleyball', 'Volleyball', 'الكرة الطائرة', 'volleyball.jpg', Icons.sports_volleyball, video: 'Volleyball'),
  CompSport('swimming', 'Swimming', 'السباحة', 'swimming.jpg', Icons.pool, video: 'Swimming'),
  CompSport('boxing', 'Boxing', 'الملاكمة', 'boxing.jpg', Icons.sports_mma, video: 'Boxing'),
  CompSport('mma', 'MMA', 'MMA', 'mma.jpg', Icons.sports_mma, video: 'MMA'),
  CompSport('gymnastics', 'Gymnastics', 'الجمباز', 'Gymnastics.jpg', Icons.sports_gymnastics, video: 'Gymnastics'),
  CompSport('golf', 'Golf', 'الجولف', 'golf.jpg', Icons.sports_golf, video: 'Golf'),
  CompSport('judo', 'Judo', 'الجودو', 'Judo.jpg', Icons.sports_martial_arts, video: 'Judo'),
  CompSport('taekwondo', 'Taekwondo', 'التايكوندو', 'taekwondo.jpg', Icons.sports_martial_arts, video: 'Taekwondo'),
  CompSport('hockey', 'Hockey', 'الهوكي', 'Hockey.jpg', Icons.sports_hockey, video: 'Hockey'),
  CompSport('squash', 'Squash', 'الإسكواش', 'squash.jpg', Icons.sports_tennis, video: 'Squash'),
  CompSport('weightlifting', 'Weightlifting', 'رفع الأثقال', 'Weightlifting.jpg', Icons.fitness_center, video: 'Weightlifting'),
  CompSport('water_polo', 'Water Polo', 'كرة الماء', 'Water-Polo.jpg', Icons.pool, video: 'Water_Polo'),
  CompSport('tennis', 'Tennis', 'التنس', 'tennis.jpg', Icons.sports_tennis, video: 'Tennis'),
  CompSport('calisthenics', 'Calisthenics', 'كاليسثنكس', 'calisthenics.jpg', Icons.fitness_center, video: 'Calisthenics'),
];

/// الهوم بيحط هنا اللعبة اللي اليوزر داس عليها، وصفحة المسابقات بتعلّمها جاهزة
/// (من غير ما تتحفظ، لحد ما يدوس "سجّلني").
final ValueNotifier<String?> competitionPreselect = ValueNotifier<String?>(null);
