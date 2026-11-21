import 'package:flutter/material.dart';

import '../profile/profile_page.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ProfileSearchPage(
      userId: '',
      username: 'ahmed.mekki',
      displayName: 'Ahmed Mekki',
      avatarUrl: null,
    ),
  ));
}

// ---------------------------------------------------------------------------
// شاشة معاينة البروفايل (تتحول إلى البروفايل الكامل عند الضغط على See Profile)
// ---------------------------------------------------------------------------
class ProfileSearchPage extends StatefulWidget {
  final String userId;
  final String username;
  final String displayName;
  final String? avatarUrl;

  const ProfileSearchPage({
    super.key,
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  @override
  State<ProfileSearchPage> createState() => _ProfileSearchPageState();
}

class _ProfileSearchPageState extends State<ProfileSearchPage> {
  bool _isFollowing = false;

  final String _sampleAvatar =
      'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=900&q=80';

  String get _profileAvatar =>
      widget.avatarUrl != null && widget.avatarUrl!.trim().isNotEmpty
          ? widget.avatarUrl!.trim()
          : _sampleAvatar;

  // See Profile: بيفتح بروفايل اليوزر الحقيقي في وضع زائر
  void _openFullProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfilePage(
          visitTarget: ProfileVisitTarget(
            userId: widget.userId,
            username: widget.username,
            displayName: widget.displayName,
            avatarUrl: widget.avatarUrl,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    // الشاشة الأولى الافتراضية (شاشة المعاينة)
    final heroHeight = (media.size.height * 0.62).clamp(350.0, 650.0).toDouble();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // قسم الصورة الكبيرة والزرار اللي فوق
            Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: heroHeight,
                  child: Image.network(
                    _profileAvatar,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: media.padding.top + 10,
                  left: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),

            // القسم الأسود اللي تحت الصورة (البيانات والأزرار)
            Container(
              color: Colors.black,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                children: [
                  // الاسم + علامة التوثيق + زرار See Profile
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.check_circle, size: 16, color: Color(0xFF3B82F6)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '@${widget.username}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  // الإحصائيات (Following, Followers, Fans)
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatColumn(value: '248', label: 'Following'),
                      _StatColumn(value: '1.8K', label: 'Followers'),
                      _StatColumn(value: '12', label: 'Fans'),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // زرار Follow الأحمر العريض
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFollowing ? const Color(0xFF242424) : const Color(0xFFFF0000),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _isFollowing = !_isFollowing;
                        });
                      },
                      child: Text(
                        _isFollowing ? 'Following' : 'Follow',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // زرار See Profile تحت Follow: بيفتح بروفايل اليوزر كزائر
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFF242424),
                        side: const BorderSide(color: Color(0xFF414141)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _openFullProfile,
                      child: const Text(
                        'See Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;

  const _StatColumn({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
        ),
      ],
    );
  }
}
