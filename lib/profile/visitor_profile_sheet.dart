import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_lang.dart';
import '../brand.dart';
import 'profile_page.dart'; // for ProfilePage + ProfileVisitTarget
import 'profile_trophies.dart';
import 'trophy_cabinet.dart' show ProfileCabinetCount;
import '../official_account.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VisitorProfileSheet — أول شاشة للزائر (صفحة كاملة)
// الصورة واخدة معظم الشاشة، وتحت: الاسم والأرقام وزرار Follow و See Profile.
// الاتنين بيفتحوا بروفايل اليوزر كامل كزائر.
// Usage:
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => VisitorProfileSheet(userId: someUserId)));
//   // صاحب البروفايل بيشوف نفسه كزائر:
//   VisitorProfileSheet(userId: myId, isOwnPreview: true)
// ─────────────────────────────────────────────────────────────────────────────

class VisitorProfileSheet extends StatefulWidget {
  final int userId;
  /// صاحب البروفايل بيعاين نفسه: Follow مش بيتابع، بس بيفتح البروفايل
  final bool isOwnPreview;
  const VisitorProfileSheet({
    super.key,
    required this.userId,
    this.isOwnPreview = false,
  });

  @override
  State<VisitorProfileSheet> createState() => _VisitorProfileSheetState();
}

class _VisitorProfileSheetState extends State<VisitorProfileSheet> {

  // ── Loading / error state ──────────────────────────────────────────────────
  bool    _loading      = true;
  String? _error;

  // ── Profile data ───────────────────────────────────────────────────────────
  String? _avatarUrl;
  String  _displayName          = '';
  String  _username             = '';
  bool    _isVerified           = false;
  int     _followingCount       = 0;
  int     _followersCount       = 0;
  int     _trophiesCount        = 0;
  bool    _isFollowing          = false;
  bool    _requireFollowToView  = false;

  // ── Follow action state ────────────────────────────────────────────────────
  bool _followLoading = false;

  // ── Block (أنا عامل بلوك للشخص ده) ─────────────────────────────────────────
  bool _iBlocked   = false;
  bool _unblocking = false;

  // ──────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ── Load profile from DB ──────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    // حساب BDGR الرسمي: نفتح البروفايل الكامل على طول (ليه شكل خاص)
    await OfficialAccount.load();
    if (!widget.isOwnPreview && OfficialAccount.isOfficial(widget.userId)) {
      if (mounted) _openFullProfile();
      return;
    }
    try {
      final data = await Supabase.instance.client.rpc(
        'get_visitor_profile_card',
        params: {'p_target_user_id': widget.userId},
      );

      if (!mounted) return;

      if (data == null || (data as List).isEmpty) {
        // مفيش داتا: يا البروفايل مش موجود، يا فيه بلوك
        try {
          final b = await Supabase.instance.client.rpc('get_block_status',
              params: {'p_target_user_id': widget.userId});
          final row = b is List && b.isNotEmpty ? b.first as Map : null;
          _iBlocked = row?['i_blocked'] == true;
        } catch (_) {}
        if (!mounted) return;
        setState(() { _error = 'Profile not found'; _loading = false; });
        return;
      }

      final row = data[0] as Map<String, dynamic>;
      setState(() {
        _avatarUrl            = row['avatar_url'] as String?;
        _displayName          = (row['display_name'] as String?) ?? '';
        _username             = (row['username']     as String?) ?? '';
        _isVerified           = (row['is_verified']  as bool?)   ?? false;
        _followingCount       = (row['following_count'] as num?)?.toInt() ?? 0;
        _followersCount       = (row['followers_count'] as num?)?.toInt() ?? 0;
        _isFollowing          = (row['is_following']             as bool?) ?? false;
        _requireFollowToView  = (row['require_follow_to_view']   as bool?) ?? false;
        _loading = false;
      });
      // الإنجازات مكان الفانز (27 نوفمبر)
      final uid = int.tryParse('${widget.userId}');
      if (uid != null) {
        ProfileTrophies.load(uid).then((t) { if (mounted && t != null) setState(() => _trophiesCount =
            // same number as the full profile: the cabinet total when the cabinet is on
            ProfileUi.cabinet && ProfileUi.arenaTabs ? t.cabinetTotal() : t.trophies); });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _unblock() async {
    setState(() => _unblocking = true);
    try {
      await Supabase.instance.client.rpc('unblock_user',
          params: {'p_target_user_id': widget.userId});
      if (!mounted) return;
      setState(() { _iBlocked = false; _unblocking = false; _error = null; _loading = true; });
      await _loadProfile();
    } catch (e) {
      debugPrint('unblock_user error: $e');
      if (mounted) setState(() => _unblocking = false);
    }
  }

  // ── Follow tap: follow (if needed) then open full profile ────────────────
  Future<void> _onFollowTap() async {
    if (!_isFollowing && !widget.isOwnPreview) {
      // Follow first, then navigate with isFollowing = true
      await _toggleFollow();
    }
    if (!mounted) return;
    _openFullProfile();
  }

  // ── Follow / Unfollow ─────────────────────────────────────────────────────
  Future<void> _toggleFollow() async {
    if (_followLoading) return;

    // Optimistic flip
    final wasFollowing = _isFollowing;
    setState(() {
      _isFollowing     = !wasFollowing;
      _followersCount += _isFollowing ? 1 : -1;
      _followLoading   = true;
    });

    try {
      if (!wasFollowing) {
        await Supabase.instance.client.rpc(
          'follow_user',
          params: {'p_target_user_id': widget.userId},
        );
      } else {
        await Supabase.instance.client.rpc(
          'unfollow_user',
          params: {'p_target_user_id': widget.userId},
        );
      }
    } catch (e) {
      // Revert on error
      if (!mounted) return;
      setState(() {
        _isFollowing     = wasFollowing;
        _followersCount += wasFollowing ? 1 : -1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  // ── Open full profile (used by both Follow and See Profile) ──────────────
  void _openFullProfile() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          visitTarget: ProfileVisitTarget(
            userId:      widget.userId.toString(),
            username:    _username,
            displayName: _displayName,
            avatarUrl:   _avatarUrl,
            isFollowing: _isFollowing,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  static const Color _bg = Color(0xFF0B0B0F);

  @override
  Widget build(BuildContext context) {
    final media  = MediaQuery.of(context);
    final height = media.size.height;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          if (_loading)
            const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFFFF0000), strokeWidth: 2),
            )
          else if (_error != null)
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.block, color: Colors.white24, size: 48),
                const SizedBox(height: 12),
                Text(
                  _iBlocked
                      ? AppLang.t('You blocked this user', 'إنت عامل بلوك لليوزر ده')
                      : AppLang.t('This profile is not available', 'البروفايل ده مش متاح'),
                  style: const TextStyle(color: Colors.white70, fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
                if (_iBlocked) ...[
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _unblocking ? null : _unblock,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(AppLang.t('Unblock', 'شيل البلوك')),
                  ),
                ],
              ]),
            )
          else ...[
            // ── الصورة: حوالي 70% من الشاشة ───────────────────────────────
            Positioned(
              top: 0, left: 0, right: 0,
              height: height * 0.70,
              child: Stack(fit: StackFit.expand, children: [
                if (_avatarUrl != null && _avatarUrl!.trim().isNotEmpty)
                  Image.network(
                    _avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _avatarPlaceholder(),
                  )
                else
                  _avatarPlaceholder(),
                // تدرّج لتحت علشان الصورة تدخل في الخلفية
                const Positioned(
                  left: 0, right: 0, bottom: 0,
                  height: 220,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [_bg, Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ]),
            ),

            // ── تحت: الاسم والأرقام والزراير ──────────────────────────────
            Positioned(
              left: 20, right: 20,
              bottom: media.padding.bottom + 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // name + verified
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          _displayName.isNotEmpty ? _displayName : 'User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isVerified && Brand.showVerifiedBadge) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified,
                            color: Color(0xFF00FF87), size: 22),
                      ],
                    ],
                  ),
                  if (_username.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('@$_username',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 14)),
                  ],

                  const SizedBox(height: 18),

                  // stats row — نفس شكل البروفايل
                  Row(
                    children: [
                      _stat(_fmt(_followersCount), AppLang.t('Followers', 'متابعون')),
                      _stat(_fmt(_followingCount), AppLang.t('Following', 'يتابع')),
                      _stat(_fmt(_trophiesCount), AppLang.t('Trophies', 'إنجازات')),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // Follow — بيتابع (لو لسه) وبعدين يفتح البروفايل
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _followLoading ? null : _onFollowTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFollowing
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFFF0000),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF2A2A2A),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _followLoading
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              _isFollowing ? AppLang.t('Following', 'متابَع') : AppLang.t('Follow', 'تابِع'),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // See Profile — مستخبي لو البروفايل خاص ومش متابعه
                  if (_requireFollowToView && !_isFollowing && !widget.isOwnPreview)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        AppLang.t('Follow @$_username to view their profile',
                            'تابِع @$_username عشان تشوف البروفايل'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 13),
                      ),
                    )
                  else
                    // زرار تاني أخف من Follow: من غير إطار، بعلامة عين وسهم
                    TextButton(
                      onPressed: _openFullProfile,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.remove_red_eye_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text(AppLang.t('See Profile', 'شوف البروفايل'),
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, size: 20),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          // ── زرار الرجوع ───────────────────────────────────────────────────
          Positioned(
            top: media.padding.top + 10,
            left: 12,
            child: Material(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      size: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder() => const ColoredBox(
        color: Color(0xFF1E1E1E),
        child: Center(
          child: Icon(Icons.person, color: Colors.white24, size: 140),
        ),
      );

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
    return n.toString();
  }

  Widget _stat(String value, String label) => Expanded(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: Colors.white70, fontSize: 13)),
      ],
    ),
  );

}
