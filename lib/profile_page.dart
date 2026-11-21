import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import '../brand.dart';

SupabaseClient get _sb => Supabase.instance.client;

// ── Colors ────────────────────────────────────────────────────────────────────
const _kAccent  = Color(0xFFFF0000);
const _kCard    = Color(0xFF1A1A1A);
const _kBorder  = Color(0xFF2A2A2A);
const _kField   = Color(0xFF242424);
const _kGray    = Color(0xFF6B7280);
const _kBg      = Brand.background;

// ── Location lists ────────────────────────────────────────────────────────────
const _kCountries = [
  'Egypt','Saudi Arabia','UAE','Kuwait','Qatar','Bahrain','Oman',
  'Jordan','Lebanon','Morocco','Tunisia','Algeria','Libya','Sudan',
  'Iraq','Syria','Palestine','Yemen',
];
const _kGovernorates = {
  'Egypt': ['Cairo','Alexandria','Giza','Qalyubia','Sharqia','Dakahlia',
    'Beheira','Kafr El Sheikh','Gharbia','Monufia','Faiyum','Beni Suef',
    'Minya','Asyut','Sohag','Qena','Luxor','Aswan','Red Sea','Suez',
    'Ismailia','Port Said','North Sinai','South Sinai','Matrouh',
    'New Valley','Damietta'],
  'Saudi Arabia': ['Riyadh','Makkah','Madinah','Eastern Province','Asir',
    'Tabuk','Hail','Northern Borders','Jawf','Qassim','Jizan','Najran','Baha'],
  'UAE': ['Abu Dhabi','Dubai','Sharjah','Ajman','Umm Al Quwain',
    'Ras Al Khaimah','Fujairah'],
};
const _kCities = {
  'Cairo':      ['Cairo','Nasr City','Heliopolis','Maadi','Zamalek','New Cairo','6th of October'],
  'Alexandria': ['Alexandria','Montaza','Smouha','Agami','Miami'],
  'Giza':       ['Giza','Sheikh Zayed','Dokki','Mohandessin','Haram'],
  'Riyadh':     ['Riyadh','Al Kharj','Diriyah'],
  'Makkah':     ['Makkah','Jeddah','Taif'],
  'Dubai':      ['Dubai','Deira','Bur Dubai','Jumeirah','Al Quoz'],
  'Abu Dhabi':  ['Abu Dhabi','Al Ain'],
};

// ── Moment model ──────────────────────────────────────────────────────────────
class _MomentItem {
  _MomentItem({
    required this.id,
    required this.storagePath,
    required this.mediaType,
    this.caption,
    required this.isPublished,
    required this.createdAt,
  });
  final String   id;
  final String   storagePath;
  final String   mediaType; // 'image' | 'video'
  final String?  caption;
  bool           isPublished;
  final DateTime createdAt;

  bool get isVideo => mediaType == 'video';

  String publicUrl() =>
      _sb.storage.from('moments').getPublicUrl(storagePath);
}

// ── ProfileVisitTarget ────────────────────────────────────────────────────────
class ProfileVisitTarget {
  const ProfileVisitTarget({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });
  final String  userId;
  final String  username;
  final String  displayName;
  final String? avatarUrl;
}

// ── ProfilePage ───────────────────────────────────────────────────────────────
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.visitTarget, this.onBuildTeam});
  final ProfileVisitTarget? visitTarget;
  final VoidCallback?        onBuildTeam;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {

  // ── Profile data ──
  int?    _userId;
  String  _displayName    = '';
  String  _username       = '';
  String? _avatarUrl;
  String? _coverUrl;
  String  _bio            = '';
  String  _country        = '';
  String  _governorate    = '';
  String  _city           = '';
  String  _followingCount = '0';
  String  _followersCount = '0';
  String  _fansCount      = '0';
  DateTime? _joinedAt;
  DateTime? _birthDate;
  String?   _gender;
  List<String> _sportIds   = [];
  List<String> _sportNames = [];
  bool    _isLoading      = true;

  // ── Local images ──
  Uint8List? _localAvatar;
  Uint8List? _localCover;
  bool _avatarUploading = false;
  bool _coverUploading  = false;

  // ── Moments ──
  List<_MomentItem> _moments         = [];
  bool              _momentsLoading  = false;
  bool              _uploading       = false;

  bool get _isOwner => widget.visitTarget == null;

  bool get _isVerified =>
      _username.isNotEmpty &&
      _displayName.isNotEmpty &&
      _displayName != 'BDGR Athlete' &&
      _bio.isNotEmpty &&
      _bio != 'Unranked. Unafraid.' &&
      (_avatarUrl?.isNotEmpty == true || _localAvatar != null);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ── Load profile ──────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    try {
      final res = await _sb.rpc('get_my_profile_info');
      if (res == null || (res as List).isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final d = res[0] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _userId         = (d['user_id'] as num?)?.toInt();
        _displayName    = d['display_name']?.toString() ?? 'BDGR Athlete';
        _username       = d['username']?.toString() ?? '';
        _avatarUrl      = d['avatar_url']?.toString();
        _coverUrl       = d['cover_url']?.toString();
        _bio            = d['bio']?.toString() ?? '';
        _country        = d['country']?.toString() ?? '';
        _governorate    = d['governorate']?.toString() ?? '';
        _city           = d['city']?.toString() ?? '';
        _followingCount = _fmt((d['following_count'] as num?)?.toInt() ?? 0);
        _followersCount = _fmt((d['followers_count'] as num?)?.toInt() ?? 0);
        _fansCount      = _fmt((d['fans_count']      as num?)?.toInt() ?? 0);
        _joinedAt       = d['joined_at'] != null
            ? DateTime.tryParse(d['joined_at'].toString()) : null;
        _birthDate      = d['birth_date'] != null
            ? DateTime.tryParse(d['birth_date'].toString()) : null;
        _gender         = d['gender']?.toString();
        if (d['sport_ids'] != null)
          _sportIds = List<String>.from(
              (d['sport_ids'] as List).map((e) => e.toString()));
        if (d['sport_names'] != null)
          _sportNames = List<String>.from(
              (d['sport_names'] as List).map((e) => e.toString()));
        _isLoading = false;
      });
      await _loadMoments();
    } catch (e) {
      debugPrint('profile error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Load moments ──────────────────────────────────────────────────────────

  Future<void> _loadMoments() async {
    if (!mounted) return;
    setState(() => _momentsLoading = true);
    try {
      final res = await _sb.rpc('get_my_moments') as List;
      if (!mounted) return;
      setState(() {
        _moments = res.map((e) {
          final m = e as Map<String, dynamic>;
          return _MomentItem(
            id:          m['id'].toString(),
            storagePath: m['storage_path'].toString(),
            mediaType:   m['media_type'].toString(),
            caption:     m['caption']?.toString(),
            isPublished: m['is_published'] == true,
            createdAt:   DateTime.tryParse(m['created_at'].toString()) ?? DateTime.now(),
          );
        }).toList();
        _momentsLoading = false;
      });
    } catch (e) {
      debugPrint('moments error: $e');
      if (mounted) setState(() => _momentsLoading = false);
    }
  }

  // ── Upload moment ─────────────────────────────────────────────────────────

  Future<void> _addMoment({required bool isVideo}) async {
    final authUid = _sb.auth.currentUser?.id;
    if (authUid == null) { _snack('Not authenticated.'); return; }

    final picker = ImagePicker();
    final file   = isVideo
        ? await picker.pickVideo(source: ImageSource.gallery,
            maxDuration: const Duration(minutes: 2))
        : await picker.pickImage(source: ImageSource.gallery,
            imageQuality: 85);

    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      _snack('File must be under 5 MB.');
      return;
    }

    setState(() => _uploading = true);
    try {
      final ext      = file.path.split('.').last.toLowerCase();
      final filename = '${const Uuid().v4()}.$ext';
      final path     = '$authUid/$filename';
      final mime     = _mimeFromExt(ext, isVideo: isVideo);

      await _sb.storage.from('moments').uploadBinary(
        path, bytes,
        fileOptions: FileOptions(contentType: mime, upsert: true),
      );

      await _sb.rpc('add_moment', params: {
        'p_storage_path': path,
        'p_media_type':   isVideo ? 'video' : 'image',
        'p_file_size':    bytes.length,
      });

      await _loadMoments();
    } catch (e) {
      debugPrint('upload error: $e');
      _snack('Error: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── Replace moment ───────────────────────────────────────────────────────

  Future<void> _replaceMoment(_MomentItem m) async {
    final authUid = _sb.auth.currentUser?.id;
    if (authUid == null) { _snack('Not authenticated.'); return; }
    final isVideo = m.isVideo;
    final picker  = ImagePicker();
    final file    = isVideo
        ? await picker.pickVideo(source: ImageSource.gallery,
            maxDuration: const Duration(minutes: 2))
        : await picker.pickImage(source: ImageSource.gallery,
            imageQuality: 85);
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      _snack('File must be under 5 MB.');
      return;
    }

    setState(() => _uploading = true);
    try {
      // Upload new file
      final ext      = file.path.split('.').last.toLowerCase();
      final filename = '${const Uuid().v4()}.$ext';
      final newPath  = '$authUid/$filename';
      final mime     = _mimeFromExt(ext, isVideo: isVideo);

      await _sb.storage.from('moments').uploadBinary(
        newPath, bytes,
        fileOptions: FileOptions(contentType: mime, upsert: true),
      );

      // Update DB with new path + delete old file
      await _sb.rpc('replace_moment_media', params: {
        'p_id':           m.id,
        'p_storage_path': newPath,
        'p_media_type':   isVideo ? 'video' : 'image',
        'p_file_size':    bytes.length,
      });

      // Delete old file from storage
      await _sb.storage.from('moments').remove([m.storagePath]);

      await _loadMoments();
    } catch (e) {
      debugPrint('replace error: $e');
      _snack('Replace failed. Please try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── Delete moment ─────────────────────────────────────────────────────────

  Future<void> _deleteMoment(_MomentItem m) async {
    try {
      await _sb.storage.from('moments').remove([m.storagePath]);
      await _sb.rpc('delete_moment', params: {'p_id': m.id});
      await _loadMoments();
    } catch (e) {
      debugPrint('delete error: $e');
      _snack('Could not delete moment.');
    }
  }

  // ── Toggle publish ────────────────────────────────────────────────────────

  Future<void> _togglePublish(_MomentItem m) async {
    try {
      await _sb.rpc('toggle_moment_publish', params: {'p_id': m.id});
      await _loadMoments();
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('max_published_reached')) {
        _snack('Maximum 2 published moments allowed.');
      } else {
        _snack('Could not update moment.');
      }
    }
  }

  String _mimeFromExt(String ext, {required bool isVideo}) {
    if (isVideo) {
      switch (ext) {
        case 'mov':  return 'video/quicktime';
        case 'webm': return 'video/webm';
        default:     return 'video/mp4';
      }
    }
    switch (ext) {
      case 'png':  return 'image/png';
      case 'webp': return 'image/webp';
      default:     return 'image/jpeg';
    }
  }

  // ── Upload avatar / cover to storage ─────────────────────────────────────

  Future<void> _uploadImage({
    required Uint8List bytes,
    required bool isCover,
    required String ext,
  }) async {
    final authUid = _sb.auth.currentUser?.id;
    if (authUid == null) return;

    final folder   = isCover ? 'cover' : 'avatar';
    final filename = '${const Uuid().v4()}.$ext';
    final path     = '$authUid/$folder/$filename';
    final mime     = _mimeFromExt(ext, isVideo: false);

    try {
      await _sb.storage.from('Users').uploadBinary(
        path, bytes,
        fileOptions: FileOptions(contentType: mime, upsert: true),
      );
      final url = _sb.storage.from('Users').getPublicUrl(path);
      if (isCover) {
        await _sb.rpc('update_my_profile', params: {'p_cover_url': url});
        if (mounted) setState(() { _coverUrl = url; _coverUploading = false; });
      } else {
        await _sb.rpc('update_my_profile', params: {'p_avatar_url': url});
        if (mounted) setState(() { _avatarUrl = url; _avatarUploading = false; });
      }
    } catch (e) {
      debugPrint('image upload error: $e');
      if (mounted) setState(() {
        if (isCover) _coverUploading = false;
        else         _avatarUploading = false;
      });
      _snack('Image upload failed: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)));
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n/1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n/1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
    return '$n';
  }

  // ── Images ────────────────────────────────────────────────────────────────

  static const _allowedExt = ['jpg','jpeg','png','webp'];
  bool _validExt(String path) =>
      _allowedExt.contains(path.split('.').last.toLowerCase());

  ImageProvider? get _avatarImage {
    if (_localAvatar != null) return MemoryImage(_localAvatar!);
    if (_avatarUrl?.isNotEmpty == true) return NetworkImage(_avatarUrl!);
    return null;
  }

  ImageProvider? get _coverImage {
    if (_localCover != null) return MemoryImage(_localCover!);
    if (_coverUrl?.isNotEmpty == true) return NetworkImage(_coverUrl!);
    return null;
  }

  Future<void> _pickCover() async {
    if (_coverImage != null) { _showImageSheet(isCover: true); return; }
    await _selectNewImage(isCover: true);
  }

  Future<void> _pickAvatar() async {
    if (_avatarImage != null) { _showImageSheet(isCover: false); return; }
    await _selectNewImage(isCover: false);
  }

  Future<void> _selectNewImage({required bool isCover}) async {
    final r = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (r == null || !mounted) return;
    if (!_validExt(r.path)) {
      _snack('Only jpg, png, and webp images are allowed.');
      return;
    }
    final bytes = await r.readAsBytes();
    if (!mounted) return;
    final ext = r.path.split('.').last.toLowerCase();
    // Show immediately from local bytes
    setState(() {
      if (isCover) { _localCover = bytes; _coverUploading = true; }
      else          { _localAvatar = bytes; _avatarUploading = true; }
    });
    // Upload to storage in background
    await _uploadImage(bytes: bytes, isCover: isCover, ext: ext);
  }

  void _showImageSheet({required bool isCover}) {
    final img = isCover ? _coverImage : _avatarImage;
    if (img == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ImageViewSheet(
        image: img, isAvatar: !isCover,
        onEdit:   () async { Navigator.pop(ctx); await _selectNewImage(isCover: isCover); },
        onRemove: () async {
          Navigator.pop(ctx);
          if (isCover) {
            setState(() { _localCover = null; _coverUrl = null; });
            await _sb.rpc('update_my_profile', params: {'p_cover_url': ''});
          } else {
            setState(() { _localAvatar = null; _avatarUrl = null; });
            await _sb.rpc('update_my_profile', params: {'p_avatar_url': ''});
          }
        },
      ),
    );
  }

  // ── Edit profile ──────────────────────────────────────────────────────────

  Future<void> _openEdit() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EditProfileSheet(
        displayName: _displayName, bio: _bio,
        country: _country, governorate: _governorate, city: _city,
        sportIds: _sportIds, birthDate: _birthDate, gender: _gender,
        onSave: ({required displayName, required bio, required country,
                  required governorate, required city,
                  required sportIds, Map<String,dynamic>? locationData,
                  DateTime? birthDate, String? gender}) async {
          await _sb.rpc('update_my_profile', params: {
            'p_display_name': displayName,
            'p_bio':          bio,
            'p_country':      country,
            'p_governorate':  governorate,
            'p_city':         city,
            if (locationData != null) 'p_location_data': locationData,
            'p_sport_ids':    sportIds,
            if (birthDate != null) 'p_birth_date':
                birthDate.toIso8601String().split('T')[0],
            if (gender != null) 'p_gender': gender,
          });
          if (mounted) await _loadProfile();
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: _kBg,
          body: Center(child: CircularProgressIndicator(color: _kAccent)));
    }
    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          if (_isOwner || _moments.isNotEmpty) ...[
            SliverToBoxAdapter(child: _buildStoriesRow()),
            SliverToBoxAdapter(child: _buildMomentsGrid()),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildCover(),
      SizedBox(
        height: 56,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxHeight: 96,
          maxWidth: 96 + 16,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Transform.translate(
              offset: const Offset(0, -40),
              child: _buildAvatar(),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildNameRow(),
          const SizedBox(height: 14),
          _buildStats(),
          const SizedBox(height: 14),
          Text(
            _bio.isNotEmpty ? _bio : 'Unranked. Unafraid.',
            style: TextStyle(
              color: _bio.isNotEmpty ? Colors.white70 : Colors.white38,
              fontSize: 14, height: 1.5,
              fontStyle: _bio.isNotEmpty ? FontStyle.normal : FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          _buildMeta(),
          const SizedBox(height: 12),
          if (_sportNames.isNotEmpty) ...[
            Wrap(spacing: 8, runSpacing: 6,
              children: _sportNames.map((name) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _kCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kBorder)),
                child: Text(name, style: const TextStyle(
                    color: Colors.white70, fontSize: 12)),
              )).toList()),
            const SizedBox(height: 12),
          ],
          if (_isOwner) _buildOwnerButtons(),
          const SizedBox(height: 8),
        ]),
      ),
    ],
  );

  // ── Cover ─────────────────────────────────────────────────────────────────

  Widget _buildCover() {
    final top = MediaQuery.of(context).padding.top;
    final stack = SizedBox(
      height: 160 + top,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: _coverImage != null
              ? Image(image: _coverImage!, fit: BoxFit.cover)
              : Stack(fit: StackFit.expand, children: [
                  Container(color: const Color(0xFF0D0808)),
                  Center(child: Opacity(opacity: 0.12,
                    child: Image.asset('assets/badger_white.png',
                        fit: BoxFit.contain))),
                ]),
        ),
        Positioned.fill(child: Container(
          decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
          )),
        )),
        if (_isOwner)
          Positioned(top: top + 10, right: 12,
            child: _iconBtn(Icons.camera_alt, _pickCover)),
      ]),
    );
    if (!_isOwner) return stack;
    return GestureDetector(onTap: _pickCover, child: stack);
  }

  Widget _buildAvatar() {
    final circle = Stack(children: [
      Container(
        width: 90, height: 90,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _kBg, width: 3),
          color: _kCard,
          image: _avatarImage != null
              ? DecorationImage(image: _avatarImage!, fit: BoxFit.cover)
              : null,
        ),
        child: _avatarImage == null
            ? const Icon(Icons.person, color: Colors.white38, size: 40) : null,
      ),
      if (_isOwner)
        Positioned(bottom: 2, right: 2, child: Container(
          width: 26, height: 26,
          decoration: BoxDecoration(color: _kAccent, shape: BoxShape.circle,
              border: Border.all(color: _kBg, width: 2)),
          child: const Icon(Icons.camera_alt, size: 13, color: Colors.white),
        )),
    ]);
    if (!_isOwner) return circle;
    return GestureDetector(onTap: _pickAvatar, child: circle);
  }

  Widget _buildNameRow() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Flexible(child: Text(
          _displayName.isNotEmpty ? _displayName : 'BDGR Athlete',
          style: const TextStyle(color: Colors.white, fontSize: 22,
              fontWeight: FontWeight.w800, letterSpacing: -0.5),
        )),
        if (_isVerified) ...[
          const SizedBox(width: 6),
          const Icon(Icons.verified, color: Brand.green, size: 18),
        ],
      ]),
      if (_username.isNotEmpty)
        Text('@$_username', style: const TextStyle(color: _kGray, fontSize: 13)),
    ],
  );

  Widget _buildStats() => Row(children: [
    _stat(_followingCount, 'Following'),
    _vLine(),
    _stat(_followersCount, 'Followers'),
    _vLine(),
    _stat(_fansCount, 'Fans'),
  ]);

  Widget _stat(String val, String label) => Expanded(child: Column(children: [
    Text(val, style: const TextStyle(color: Colors.white, fontSize: 18,
        fontWeight: FontWeight.w800)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(color: _kGray, fontSize: 11)),
  ]));

  Widget _vLine() => Container(width: 1, height: 32, color: _kBorder,
      margin: const EdgeInsets.symmetric(horizontal: 4));

  Widget _buildMeta() {
    final parts = <String>[];
    if (_city.isNotEmpty)        parts.add(_city);
    if (_governorate.isNotEmpty) parts.add(_governorate);
    if (_country.isNotEmpty)     parts.add(_country);
    final location = parts.join(', ');
    final items = <Widget>[];
    if (location.isNotEmpty)
      items.add(_metaChip(Icons.location_on_outlined, location));
    if (_birthDate != null) {
      final age = DateTime.now().year - _birthDate!.year;
      items.add(_metaChip(Icons.cake_outlined, 'Age $age'));
    }
    if (_joinedAt != null) {
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
          'Jul','Aug','Sep','Oct','Nov','Dec'];
      items.add(_metaChip(Icons.calendar_today_outlined,
          'Joined ${months[_joinedAt!.month - 1]} ${_joinedAt!.year}'));
    }
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 4), child: item)).toList());
  }

  Widget _metaChip(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: Colors.white70),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
    ],
  );

  Widget _buildOwnerButtons() => Row(children: [
    Expanded(child: _outlineBtn(Icons.edit_outlined, 'Edit Profile', _openEdit)),
    const SizedBox(width: 10),
    Expanded(child: _outlineBtn(Icons.visibility_outlined, 'View as Visitor', () {})),
  ]);

  Widget _outlineBtn(IconData icon, String label, VoidCallback onTap) =>
      Material(color: _kCard, borderRadius: BorderRadius.circular(10),
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 15, color: Colors.white70),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white70,
                  fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );

  Widget _iconBtn(IconData icon, VoidCallback onTap) =>
      Material(color: Colors.black45, borderRadius: BorderRadius.circular(10),
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24)),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      );

  // ── Stories row (horizontal circles) ─────────────────────────────────────

  Widget _buildStoriesRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 0, 0),
      child: SizedBox(
        height: 88,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            // "+" add button (owner only, if < 6 moments)
            if (_isOwner && _moments.length < 6) ...[
              _AddMomentCircle(
                uploading: _uploading,
                onPickImage: () => _addMoment(isVideo: false),
                onPickVideo: () => _addMoment(isVideo: true),
              ),
              const SizedBox(width: 12),
            ],
            // Existing moments
            ..._moments.map((m) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _MomentCircle(
                moment: m,
                isOwner: _isOwner,
                onTap: () => _openMomentViewer(m),
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _openMomentViewer(_MomentItem m) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MomentViewerSheet(
        moment: m,
        isOwner: _isOwner,
        onDelete: () async {
          Navigator.pop(ctx);
          await _deleteMoment(m);
        },
        onTogglePublish: () async {
          Navigator.pop(ctx);
          await _togglePublish(m);
        },
        onReplace: () async {
          Navigator.pop(ctx);
          await _replaceMoment(m);
        },
      ),
    );
  }

  // ── Moments grid (2 columns) ──────────────────────────────────────────────

  Widget _buildMomentsGrid() {
    if (_momentsLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(
            color: _kAccent, strokeWidth: 2)),
      );
    }
    if (_moments.isEmpty && _isOwner) {
      return _buildEmptyMoments();
    }
    if (_moments.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];
    rows.add(const Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(children: [
        Text('MOMENTS', style: TextStyle(color: Color(0xFF6B7280),
            fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
      ]),
    ));

    for (var i = 0; i < _moments.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 10));
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Expanded(child: _MomentCard(
            moment: _moments[i],
            isOwner: _isOwner,
            onTap: () => _openMomentViewer(_moments[i]),
          )),
          const SizedBox(width: 10),
          Expanded(child: i + 1 < _moments.length
              ? _MomentCard(
                  moment: _moments[i + 1],
                  isOwner: _isOwner,
                  onTap: () => _openMomentViewer(_moments[i + 1]),
                )
              : const SizedBox.shrink()),
        ]),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _buildEmptyMoments() => Padding(
    padding: const EdgeInsets.all(16),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder, style: BorderStyle.solid),
        color: _kCard.withOpacity(0.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 48, height: 48,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.photo_library_outlined,
              size: 20, color: Color(0xFF6B7280)),
        ),
        const Text('No Moments Yet', style: TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Your sports story, one moment at a time.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 12, height: 1.5)),
        const SizedBox(height: 16),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _addBtn('Photo', Icons.image_outlined,
              () => _addMoment(isVideo: false)),
          const SizedBox(width: 10),
          _addBtn('Video', Icons.videocam_outlined,
              () => _addMoment(isVideo: true)),
        ]),
      ]),
    ),
  );

  Widget _addBtn(String label, IconData icon, VoidCallback onTap) =>
      Material(color: _kAccent, borderRadius: BorderRadius.circular(10),
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white,
                  fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

// ── Add Moment Circle ─────────────────────────────────────────────────────────

class _AddMomentCircle extends StatelessWidget {
  const _AddMomentCircle({
    required this.uploading,
    required this.onPickImage,
    required this.onPickVideo,
  });
  final bool         uploading;
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: uploading ? null : () => _showPicker(context),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF2A2A2A), width: 2),
            color: const Color(0xFF1A1A1A),
          ),
          child: uploading
              ? const Center(child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFFFF0000))))
              : const Icon(Icons.add, color: Color(0xFFFF0000), size: 24),
        ),
        const SizedBox(height: 4),
        const Text('Add', style: TextStyle(
            color: Color(0xFF6B7280), fontSize: 10)),
      ]),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Add Moment', style: TextStyle(color: Colors.white,
                fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _pickerBtn(ctx, 'Photo',
                  Icons.image_outlined, onPickImage)),
              const SizedBox(width: 10),
              Expanded(child: _pickerBtn(ctx, 'Video',
                  Icons.videocam_outlined, onPickVideo)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _pickerBtn(BuildContext ctx, String label, IconData icon,
      VoidCallback onTap) =>
      Material(color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () { Navigator.pop(ctx); onTap(); },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2A2A2A))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: const Color(0xFFFF0000), size: 22),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(color: Colors.white70,
                  fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}

// ── Moment Circle (story) ─────────────────────────────────────────────────────

class _MomentCircle extends StatelessWidget {
  const _MomentCircle({
    required this.moment,
    required this.isOwner,
    required this.onTap,
  });
  final _MomentItem  moment;
  final bool         isOwner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = moment.isPublished
        ? const Color(0xFFFF0000)
        : const Color(0xFF2A2A2A);

    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 2),
            color: const Color(0xFF1A1A1A),
          ),
          child: ClipOval(
            child: moment.isVideo
                ? Stack(fit: StackFit.expand, children: [
                    Container(color: Colors.black),
                    const Center(child: Icon(Icons.play_circle_outline,
                        color: Colors.white54, size: 24)),
                  ])
                : Image.network(moment.publicUrl(), fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image,
                        color: Colors.white38)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          moment.isPublished ? 'Live' : 'Draft',
          style: TextStyle(
            color: moment.isPublished
                ? const Color(0xFFFF0000) : const Color(0xFF6B7280),
            fontSize: 10,
          ),
        ),
      ]),
    );
  }
}

// ── Moment Card (grid) ────────────────────────────────────────────────────────

class _MomentCard extends StatelessWidget {
  const _MomentCard({
    required this.moment,
    required this.isOwner,
    required this.onTap,
  });
  final _MomentItem  moment;
  final bool         isOwner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 0.82,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(fit: StackFit.expand, children: [
            // Media
            moment.isVideo
                ? Stack(fit: StackFit.expand, children: [
                    Container(color: Colors.black),
                    const Center(child: Icon(Icons.play_circle_outline,
                        color: Colors.white38, size: 36)),
                  ])
                : Image.network(moment.publicUrl(), fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Center(child: Icon(Icons.broken_image,
                            color: Colors.white24))),
            // Gradient overlay
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.bottomCenter,
                heightFactor: 0.45,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent,
                          Colors.black.withOpacity(0.85)],
                    ),
                  ),
                ),
              ),
            ),
            // Video badge
            if (moment.isVideo)
              Positioned(top: 10, left: 10,
                child: Container(
                  width: 26, height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.videocam, size: 13, color: Colors.white),
                ),
              ),
            // Published badge
            if (moment.isPublished)
              Positioned(top: 10, right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Live', style: TextStyle(
                      color: Colors.white, fontSize: 9,
                      fontWeight: FontWeight.w700)),
                ),
              ),
            // Caption
            if (moment.caption?.isNotEmpty == true)
              Positioned(left: 10, right: 10, bottom: 10,
                child: Text(moment.caption!,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 11, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
      ),
    );
  }
}

// ── Moment Viewer Sheet ───────────────────────────────────────────────────────

class _MomentViewerSheet extends StatefulWidget {
  const _MomentViewerSheet({
    required this.moment,
    required this.isOwner,
    required this.onDelete,
    required this.onTogglePublish,
    required this.onReplace,
  });
  final _MomentItem  moment;
  final bool         isOwner;
  final VoidCallback onDelete;
  final VoidCallback onTogglePublish;
  final VoidCallback onReplace;

  @override
  State<_MomentViewerSheet> createState() => _MomentViewerSheetState();
}

class _MomentViewerSheetState extends State<_MomentViewerSheet> {
  VideoPlayerController? _vpc;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.moment.isVideo) _initVideo();
  }

  Future<void> _initVideo() async {
    final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(widget.moment.publicUrl()));
    _vpc = ctrl;
    await ctrl.initialize();
    if (mounted) {
      setState(() => _videoReady = true);
      ctrl.play();
      ctrl.setLooping(true);
    }
  }

  @override
  void dispose() {
    _vpc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h      = MediaQuery.of(context).size.height;
    final bottom = MediaQuery.of(context).padding.bottom;
    final imgH   = h - 120 - bottom;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Media area
      Container(
        height: imgH, width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          // Content
          Positioned.fill(child: widget.moment.isVideo
              ? (_videoReady && _vpc != null
                  ? FittedBox(fit: BoxFit.contain,
                      child: SizedBox(
                        width: _vpc!.value.size.width,
                        height: _vpc!.value.size.height,
                        child: VideoPlayer(_vpc!),
                      ))
                  : const Center(child: CircularProgressIndicator(
                      color: Color(0xFFFF0000), strokeWidth: 2)))
              : Image.network(widget.moment.publicUrl(), fit: BoxFit.contain)),
          // X button
          Positioned(top: 12, right: 12,
            child: Material(color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () => Navigator.pop(context),
                customBorder: const CircleBorder(),
                child: Container(width: 36, height: 36,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24)),
                  child: const Icon(Icons.close, color: Colors.white, size: 18)),
              ),
            ),
          ),
          // Video play/pause tap
          if (widget.moment.isVideo && _videoReady)
            Positioned.fill(child: GestureDetector(
              onTap: () => setState(() {
                _vpc!.value.isPlaying ? _vpc!.pause() : _vpc!.play();
              }),
              behavior: HitTestBehavior.translucent,
            )),
        ]),
      ),
      // Actions bar
      if (widget.isOwner)
        Container(
          color: const Color(0xFF1A1A1A),
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
          child: Row(children: [
            Expanded(child: _actionBtn(
              widget.moment.isPublished ? Icons.visibility_off : Icons.visibility,
              widget.moment.isPublished ? 'Unpublish' : 'Publish',
              const Color(0xFFFF0000),
              widget.onTogglePublish,
            )),
            const SizedBox(width: 8),
            Expanded(child: _actionBtn(
              Icons.swap_horiz, 'Replace',
              Colors.white60, widget.onReplace,
            )),
            const SizedBox(width: 8),
            Expanded(child: _actionBtn(
              Icons.delete_outline, 'Delete',
              Colors.white38, widget.onDelete,
            )),
          ]),
        ),
    ]);
  }

  Widget _actionBtn(IconData icon, String label, Color color,
      VoidCallback onTap) =>
      Material(color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.35))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontSize: 13,
                  fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

// ── Image View Sheet ──────────────────────────────────────────────────────────

class _ImageViewSheet extends StatelessWidget {
  const _ImageViewSheet({required this.image, required this.isAvatar,
      required this.onEdit, required this.onRemove});
  final ImageProvider image;
  final bool          isAvatar;
  final VoidCallback  onEdit;
  final VoidCallback  onRemove;

  @override
  Widget build(BuildContext context) {
    final h      = MediaQuery.of(context).size.height;
    final bottom = MediaQuery.of(context).padding.bottom;
    final imgH   = h - 100 - bottom;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(children: [
        Container(height: imgH, width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            image: DecorationImage(image: image,
                fit: isAvatar ? BoxFit.contain : BoxFit.cover),
          ),
        ),
        Positioned(top: 12, right: 12,
          child: Material(color: Colors.black54, shape: const CircleBorder(),
            child: InkWell(onTap: () => Navigator.pop(context),
              customBorder: const CircleBorder(),
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24)),
                child: const Icon(Icons.close, color: Colors.white, size: 18)),
            ),
          ),
        ),
      ]),
      Container(
        color: const Color(0xFF1A1A1A),
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
        child: Row(children: [
          Expanded(child: _btn(Icons.edit_outlined, 'Edit',
              const Color(0xFFFF0000), onEdit)),
          const SizedBox(width: 10),
          Expanded(child: _btn(Icons.delete_outline, 'Remove',
              Colors.white38, onRemove)),
        ]),
      ),
    ]);
  }

  Widget _btn(IconData icon, String label, Color color, VoidCallback onTap) =>
      Material(color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.35))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontSize: 13,
                  fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

// ── Edit Profile Sheet ────────────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.displayName, required this.bio,
    required this.country,     required this.governorate,
    required this.city,        required this.sportIds,
    this.birthDate,            this.gender,
    required this.onSave,
  });
  final String       displayName;
  final String       bio;
  final String       country;
  final String       governorate;
  final String       city;
  final List<String> sportIds;
  final DateTime?    birthDate;
  final String?      gender;
  final Future<void> Function({
    required String displayName, required String bio,
    required String country,     required String governorate,
    required String city,        required List<String> sportIds,
    Map<String,dynamic>? locationData,
    DateTime? birthDate, String? gender,
  }) onSave;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  String? _country;
  String? _governorate;
  String? _city;
  bool _countryManual = false;
  bool _governorateManual = false;
  bool _cityManual = false;
  late List<String> _selectedSportIds;
  DateTime? _birthDate;
  String?   _gender;
  List<Map<String,String>> _sports = [];
  bool _loadingSports = true;
  bool _loadingGps    = false;
  bool _saving        = false;
  Map<String,dynamic>? _locationData;

  List<String> get _govList  => _kGovernorates[_country ?? ''] ?? [];
  List<String> get _cityList => _kCities[_governorate ?? ''] ?? [];

  @override
  void initState() {
    super.initState();
    _nameCtrl         = TextEditingController(text: widget.displayName);
    _bioCtrl          = TextEditingController(text: widget.bio);
    _country          = widget.country.isNotEmpty     ? widget.country     : null;
    _governorate      = widget.governorate.isNotEmpty ? widget.governorate : null;
    _city             = widget.city.isNotEmpty         ? widget.city         : null;
    _selectedSportIds = List.from(widget.sportIds);
    _birthDate        = widget.birthDate;
    _gender           = widget.gender;
    _loadSports();
  }

  @override
  void dispose() { _nameCtrl.dispose(); _bioCtrl.dispose(); super.dispose(); }

  Future<void> _loadSports() async {
    try {
      final res = await _sb.rpc('get_sports_list') as List;
      if (!mounted) return;
      setState(() {
        _sports = res.map((e) => {
          'id':   e['id'].toString(),
          'name': e['name_en'].toString(),
        }).toList();
        _loadingSports = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSports = false);
    }
  }

  Future<void> _getGps() async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.location_on, color: Color(0xFFFF0000), size: 20),
          SizedBox(width: 8),
          Text('Enable Location', style: TextStyle(color: Colors.white,
              fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: const Text(
          'Know about new competitions in your area first,\n'
          'and see your ranking across your city and governorate.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now', style: TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enable', style: TextStyle(
                  color: Color(0xFFFF0000), fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (agreed != true || !mounted) return;
    setState(() => _loadingGps = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _loadingGps = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location permission denied. Please enable it in Settings.'),
            duration: Duration(seconds: 3),
          ));
          await Geolocator.openAppSettings();
        }
        return;
      }
      if (perm == LocationPermission.denied) {
        if (mounted) setState(() => _loadingGps = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium));
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse'
          '?format=json&lat=${pos.latitude}&lon=${pos.longitude}');
      final resp = await http.get(uri,
          headers: {'User-Agent': 'BDGR-App/1.0'});
      if (!mounted) { setState(() => _loadingGps = false); return; }
      if (resp.statusCode != 200) {
        setState(() => _loadingGps = false); return;
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final addr = (data['address'] as Map<String, dynamic>?) ?? {};
      final rawCountry = addr['country']?.toString() ?? '';
      final rawState   = (addr['state'] ?? addr['county'] ?? '').toString();
      final rawCity    = (addr['city'] ?? addr['town'] ?? addr['village'] ?? '').toString();
      final detCountry = _kCountries.firstWhere(
          (c) => c.toLowerCase() == rawCountry.toLowerCase(), orElse: () => '');
      final detGov = (_kGovernorates[detCountry] ?? []).firstWhere(
          (g) => rawState.toLowerCase().contains(g.toLowerCase()), orElse: () => '');
      final detCity = (_kCities[detGov] ?? []).firstWhere(
          (c) => rawCity.toLowerCase().contains(c.toLowerCase()), orElse: () => '');
      _locationData = {
        'gps': {
          'lat': pos.latitude, 'lng': pos.longitude,
          'country':     detCountry.isNotEmpty ? detCountry : rawCountry,
          'governorate': detGov.isNotEmpty     ? detGov     : rawState,
          'city':        detCity.isNotEmpty    ? detCity    : rawCity,
          'district':    (addr['suburb'] ?? addr['neighbourhood'] ?? '').toString(),
          'street':      addr['road']?.toString() ?? '',
          'postal_code': addr['postcode']?.toString() ?? '',
        },
      };
      setState(() {
        _country     = detCountry.isNotEmpty ? detCountry : _country;
        _governorate = detGov.isNotEmpty     ? detGov     : null;
        _city        = detCity.isNotEmpty    ? detCity    : null;
        _countryManual = false;
        _governorateManual = false;
        _cityManual = false;
        _loadingGps = false;
      });
    } catch (e) {
      debugPrint('GPS error: $e');
      if (mounted) setState(() => _loadingGps = false);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final locData = Map<String,dynamic>.from(_locationData ?? {});
    if (locData.containsKey('gps')) {
      final gps = locData['gps'] as Map<String,dynamic>;
      String mv(String? d, String? g) {
        if (d == null || d.isEmpty) return 'not_set';
        if (g == null || g.isEmpty) return 'not_set';
        return d.toLowerCase() == g.toLowerCase() ? 'same' : 'different';
      }
      locData['match'] = {
        'country':     mv(_country,     gps['country']?.toString()),
        'governorate': mv(_governorate, gps['governorate']?.toString()),
        'city':        mv(_city,        gps['city']?.toString()),
      };
    } else if (_country != null || _governorate != null || _city != null) {
      locData['match'] = {
        'country':     _country     != null ? 'gps_unavailable' : 'not_set',
        'governorate': _governorate != null ? 'gps_unavailable' : 'not_set',
        'city':        _city        != null ? 'gps_unavailable' : 'not_set',
      };
    }
    try {
      await widget.onSave(
        displayName:  _nameCtrl.text.trim(),
        bio:          _bioCtrl.text.trim(),
        country:      _country     ?? '',
        governorate:  _governorate ?? '',
        city:         _city        ?? '',
        sportIds:     _selectedSportIds,
        locationData: locData.isNotEmpty ? locData : null,
        birthDate:    _birthDate,
        gender:       _gender,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('save error: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Edit Profile', style: TextStyle(color: Colors.white,
                fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            _label('Display Name'),
            _textField(_nameCtrl, hint: 'Your name', maxLength: 50),
            const SizedBox(height: 14),
            _label('Bio'),
            _textField(_bioCtrl, hint: 'Tell your story...',
                maxLines: 3, maxLength: 150),
            const SizedBox(height: 14),
            // GPS big button
            Material(color: const Color(0xFFFF0000).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _loadingGps ? null : _getGps,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFFF0000).withOpacity(0.4)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (_loadingGps)
                      const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFFFF0000)))
                    else
                      const Icon(Icons.my_location,
                          color: Color(0xFFFF0000), size: 18),
                    const SizedBox(width: 8),
                    Text(_loadingGps ? 'Detecting location...'
                        : 'Auto-detect my location',
                      style: const TextStyle(color: Color(0xFFFF0000),
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Row(children: [
              Expanded(child: Divider(color: Color(0xFF2A2A2A))),
              Padding(padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('or set manually',
                    style: TextStyle(color: Colors.white38, fontSize: 11))),
              Expanded(child: Divider(color: Color(0xFF2A2A2A))),
            ]),
            const SizedBox(height: 10),
            _label('Country'),
            _dropdown(value: _country, items: _kCountries,
              hint: 'Select country',
              onChanged: (v) => setState(() {
                _country = v; _governorate = null; _city = null;
                _countryManual = true;
                _governorateManual = false; _cityManual = false;
              }),
            ),
            if (_country != null && _govList.isNotEmpty) ...[
              const SizedBox(height: 14),
              _label('Governorate / Region'),
              _dropdown(value: _governorate, items: _govList,
                hint: 'Select governorate',
                onChanged: (v) => setState(() {
                  _governorate = v; _city = null;
                  _governorateManual = true; _cityManual = false;
                }),
              ),
            ],
            if (_governorate != null && _cityList.isNotEmpty) ...[
              const SizedBox(height: 14),
              _label('City'),
              _dropdown(value: _city, items: _cityList,
                hint: 'Select city',
                onChanged: (v) => setState(() {
                  _city = v; _cityManual = true;
                }),
              ),
            ],
            const SizedBox(height: 14),
            _label('Date of Birth'),
            Material(color: _kField, borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _birthDate ?? DateTime(2000),
                    firstDate: DateTime(1950),
                    lastDate:  DateTime(DateTime.now().year - 5),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary:   Color(0xFFFF0000),
                          onPrimary: Colors.white,
                          surface:   Color(0xFF2A2A2A),
                          onSurface: Colors.white,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _birthDate = picked);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kBorder)),
                  child: Row(children: [
                    const Icon(Icons.cake_outlined,
                        color: Colors.white54, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      _birthDate != null
                          ? '${_birthDate!.day} / ${_birthDate!.month} / ${_birthDate!.year}'
                          : 'Select date of birth',
                      style: TextStyle(
                        color: _birthDate != null ? Colors.white : Colors.white38,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (_birthDate != null)
                      const Icon(Icons.check_circle,
                          color: Color(0xFFFF0000), size: 16),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _label('Gender'),
            Row(children: [
              Expanded(child: _genderBtn('Male',   Icons.male)),
              const SizedBox(width: 10),
              Expanded(child: _genderBtn('Female', Icons.female)),
            ]),
            const SizedBox(height: 14),
            _label('Sports'),
            _loadingSports
                ? const Center(child: CircularProgressIndicator(
                    color: Color(0xFFFF0000), strokeWidth: 2))
                : Wrap(spacing: 8, runSpacing: 8,
                    children: _sports.map((s) {
                      final sel = _selectedSportIds.contains(s['id']);
                      return Material(
                        color: sel ? const Color(0xFFFF0000).withOpacity(0.15) : _kField,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: () => setState(() {
                            if (sel) _selectedSportIds.remove(s['id']);
                            else _selectedSportIds.add(s['id']!);
                          }),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: sel ? const Color(0xFFFF0000) : _kBorder),
                            ),
                            child: Text(s['name']!, style: TextStyle(
                              color: sel ? const Color(0xFFFF0000) : Colors.white70,
                              fontSize: 12,
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                            )),
                          ),
                        ),
                      );
                    }).toList()),
            const SizedBox(height: 24),
            Material(color: const Color(0xFFFF0000),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _saving ? null : _save,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Center(child: _saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save', style: TextStyle(
                          color: Colors.white, fontSize: 15,
                          fontWeight: FontWeight.w800))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _genderBtn(String val, IconData icon) {
    final sel = _gender == val.toLowerCase();
    return Material(
      color: sel ? const Color(0xFFFF0000).withOpacity(0.15) : _kField,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => setState(() => _gender = val.toLowerCase()),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: sel ? const Color(0xFFFF0000) : _kBorder),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18,
                color: sel ? const Color(0xFFFF0000) : Colors.white54),
            const SizedBox(width: 6),
            Text(val, style: TextStyle(
              color: sel ? const Color(0xFFFF0000) : Colors.white70,
              fontSize: 13,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
            )),
          ]),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(color: Colors.white54,
        fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
  );

  Widget _textField(TextEditingController ctrl,
      {String hint = '', int maxLines = 1, int? maxLength}) =>
      TextField(controller: ctrl, maxLines: maxLines, maxLength: maxLength,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
          counterStyle: const TextStyle(color: Colors.white38, fontSize: 10),
          filled: true, fillColor: _kField,
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kAccent)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
        ),
      );

  Widget _dropdown({
    required String? value, required List<String> items,
    required String hint, required ValueChanged<String?> onChanged,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(color: _kField,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder)),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        hint: Text(hint, style: const TextStyle(
            color: Colors.white38, fontSize: 14)),
        isExpanded: true,
        dropdownColor: const Color(0xFF2A2A2A),
        icon: const Icon(Icons.keyboard_arrow_down,
            color: Colors.white54, size: 20),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        items: items.map((e) => DropdownMenuItem(value: e,
            child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    ),
  );
}
