import 'dart:async';
import '../media_cache.dart';
import '../ads/ad_widgets.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import '../app_config.dart';
import '../app_lang.dart';
import '../brand.dart';
import '../local_store.dart';
import '../motion_kit.dart';
import '../official_account.dart';
import '../feed/official_posts_grid.dart';
import '../ugc/ugc_profile_section.dart';
import '../home/home_page.dart' show HomeActions;
import 'profile_trophies.dart';
import 'profile_ambient.dart';
import '../settings/help_support_page.dart' show HelpSupportPage;
import 'visitor_profile_sheet.dart';

SupabaseClient get _sb => Supabase.instance.client;

// ── Colors ────────────────────────────────────────────────────────────────────
const _kAccent  = Color(0xFFFF0000);
const _kCard    = Color(0xFF1A1A1A);
const _kBorder  = Color(0xFF2A2A2A);
const _kField   = Color(0xFF242424);
const _kGray    = Color(0xFF6B7280);
const _kBg      = Brand.background;

// ── Social SVG brand icons ────────────────────────────────────────────────────
const String _kGoogleSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<path fill="#EA4335" d="M12 5c1.6 0 3 .6 4.1 1.6l3.1-3.1C17.3 1.8 14.8 1 12 1 7.5 1 3.7 3.6 1.9 7.4l3.7 2.9C6.5 7.3 9 5 12 5z"/>
<path fill="#4285F4" d="M23.5 12.3c0-.8-.1-1.6-.2-2.3H12v4.5h6.5c-.3 1.5-1.1 2.8-2.4 3.7l3.7 2.9c2.2-2 3.7-5 3.7-8.8z"/>
<path fill="#FBBC05" d="M5.6 14.7c-.2-.7-.4-1.5-.4-2.7s.2-2 .4-2.7L1.9 6.4C.7 8.8 0 10.4 0 12s.7 3.2 1.9 5.6l3.7-2.9z"/>
<path fill="#34A853" d="M12 23c3.2 0 6-1.1 8-3l-3.7-2.9c-1.1-.7-2.5-1.2-4.3-1.2-3 0-5.5-2.3-6.4-5.3L1.9 15.6C3.7 19.4 7.5 23 12 23z"/>
</svg>''';

const String _kFacebookSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#1877F2">
<path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/>
</svg>''';

const String _kTiktokSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#ffffff">
<path d="M12.525.02c1.31-.02 2.61-.01 3.91-.02.08 1.53.63 3.09 1.75 4.17 1.12 1.11 2.7 1.62 4.24 1.79v4.03c-1.44-.05-2.89-.35-4.2-.97-.57-.26-1.1-.59-1.62-.93-.01 2.92.01 5.84-.02 8.75-.08 1.4-.54 2.79-1.35 3.94-1.31 1.92-3.58 3.17-5.91 3.21-1.43.08-2.86-.31-4.08-1.03-2.02-1.19-3.44-3.37-3.65-5.71-.02-.5-.03-1-.01-1.49.18-1.9 1.12-3.72 2.58-4.96 1.66-1.44 3.98-2.13 6.15-1.72.02 1.48-.04 2.96-.04 4.44-.99-.32-2.15-.23-3.02.37-.63.41-1.11 1.04-1.36 1.75-.21.51-.15 1.07-.14 1.61.24 1.64 1.82 3.02 3.5 2.87 1.12-.01 2.19-.66 2.77-1.61.19-.33.4-.67.41-1.06.1-1.79.06-3.57.07-5.36.01-4.03-.01-8.05.02-12.07z"/>
</svg>''';

const String _kXSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#ffffff">
<path d="M18.901 1.153h3.68l-8.04 9.19L24 22.846h-7.406l-5.8-7.584-6.638 7.584H.474l8.6-9.83L0 1.154h7.594l5.243 6.932ZM17.61 20.644h2.039L6.486 3.24H4.298Z"/>
</svg>''';

const String _kInstagramSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<defs><linearGradient id="ig" x1="0%" y1="100%" x2="100%" y2="0%"><stop offset="0%" style="stop-color:#f09433"/><stop offset="25%" style="stop-color:#e6683c"/><stop offset="50%" style="stop-color:#dc2743"/><stop offset="75%" style="stop-color:#cc2366"/><stop offset="100%" style="stop-color:#bc1888"/></linearGradient></defs>
<path fill="url(#ig)" d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z"/>
</svg>''';

const String _kYoutubeSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<path fill="#FF0000" d="M23.498 6.186a3.016 3.016 0 00-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 00.502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 002.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 002.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z"/>
</svg>''';

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

// ── الموقع المتأكد منه (GPS) ─────────────────────────────────────
/// بيطلب إذن الموقع، يجيب المكان، يحوّله لبلد/محافظة/مدينة، ويحفظه كموقع متأكد منه.
/// بيرجّع {governorate, city, governorate_ar} أو null لو اليوزر رفض أو حصل مشكلة.
Future<Map<String, dynamic>?> captureVerifiedLocation(BuildContext context) async {
  final sb = Supabase.instance.client;
  void snack(String en, String ar) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.t(en, ar))));
  }
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      snack('Turn on location (GPS) and try again.', 'شغّل الموقع (GPS) وجرّب تاني.');
      return null;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.unableToDetermine) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      snack('Location is blocked for BDGR. You can allow it from Settings.', 'الموقع مقفول لـ BDGR. تقدر تفتحه من الإعدادات.');
      await Geolocator.openAppSettings();
      return null;
    }
    if (perm == LocationPermission.denied) return null;   // رفض: مش هنزنّ عليه
    final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
    String country = '', gov = '', city = '', district = '', street = '', postal = '';
    Map<String, dynamic>? raw;
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse'
          '?format=json&accept-language=en&lat=${pos.latitude}&lon=${pos.longitude}');
      final resp = await http.get(uri, headers: {'User-Agent': 'BDGR-App/1.0'}).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        raw = jsonDecode(resp.body) as Map<String, dynamic>;
        final addr = (raw['address'] as Map<String, dynamic>?) ?? {};
        final rawCountry = addr['country']?.toString() ?? '';
        final rawState = (addr['state'] ?? addr['county'] ?? '').toString();
        final rawCity = (addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['municipality'] ?? '').toString();
        country = _kCountries.firstWhere((c) => c.toLowerCase() == rawCountry.toLowerCase(), orElse: () => rawCountry);
        gov = (_kGovernorates[country] ?? const <String>[]).firstWhere(
            (g) => rawState.toLowerCase().contains(g.toLowerCase()),
            orElse: () => rawState.replaceAll(RegExp(r'\s*Governorate$', caseSensitive: false), '').trim());
        city = (_kCities[gov] ?? const <String>[]).firstWhere(
            (c) => rawCity.toLowerCase().contains(c.toLowerCase()), orElse: () => rawCity);
        district = (addr['suburb'] ?? addr['neighbourhood'] ?? addr['quarter'] ?? '').toString();
        street = addr['road']?.toString() ?? '';
        postal = addr['postcode']?.toString() ?? '';
      }
    } catch (e) {
      debugPrint('reverse geocode error: $e');
    }
    final res = await sb.rpc('save_my_gps_location', params: {
      'p_lat': pos.latitude, 'p_lng': pos.longitude, 'p_accuracy': pos.accuracy,
      'p_country': country, 'p_governorate': gov, 'p_city': city,
      'p_district': district, 'p_street': street, 'p_postal': postal, 'p_raw': raw,
    });
    final out = Map<String, dynamic>.from(res as Map);
    if (out['governorate'] == null) {
      snack("We couldn't read your area. Try again outdoors.", 'مقدرناش نعرف منطقتك. جرّب تاني وانت في مكان مفتوح.');
      return null;
    }
    return out;
  } catch (e) {
    debugPrint('captureVerifiedLocation error: $e');
    snack("Couldn't get your location. Try again.", 'مقدرناش نجيب موقعك. جرّب تاني.');
    return null;
  }
}

// ── Moment model ──────────────────────────────────────────────────────────────
class _MomentItem {
  _MomentItem({
    required this.id,
    required this.storagePath,
    required this.mediaType,
    this.caption,
    required this.createdAt,
    this.likesCount    = 0,
    this.viewsCount    = 0,
    this.commentsCount = 0,
    this.isLiked       = false,
    this.isSaved       = false,
    this.durationSeconds,
  });
  final String   id;
  final String   storagePath;
  final String   mediaType; // 'image' | 'video'
  final String?  caption;
  final DateTime createdAt;
  int            likesCount;
  int            viewsCount;
  int            commentsCount;
  bool           isLiked;
  bool           isSaved;
  final double?  durationSeconds;

  bool get isVideo => mediaType == 'video';

  String publicUrl() =>
      _sb.storage.from('users').getPublicUrl(storagePath);
}

// ── ProfileVisitTarget ────────────────────────────────────────────────────────
class ProfileVisitTarget {
  const ProfileVisitTarget({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.isFollowing = false,
  });
  final String  userId;
  final String  username;
  final String  displayName;
  final String? avatarUrl;
  final bool    isFollowing;
}

// ── ProfilePage ───────────────────────────────────────────────────────────────
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.visitTarget, this.onBuildTeam, this.openMomentId});
  final ProfileVisitTarget? visitTarget;
  final VoidCallback?        onBuildTeam;
  /// لو جاي من لينك مشاركة: افتح المومنت ده أول ما المومنتس تتحمل
  final String?              openMomentId;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {

  // ── Profile data ──
  int?    _userId;
  int     _cupTitles = 0;   // 🏆 كاس بادجر اللي كسبها
  ProfileTrophies? _trophies; // كارت الفانتازي + الإنجازات + التصنيف
  int _ptab = 0;              // 0 بوستات · 1 إنجازات · 2 فانتازي · 3 المشوار · 4 الإحصائيات
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
  List<String> _sportIds        = [];
  List<String> _sportNames      = [];
  String?      _primarySportId;
  String?      _primarySportName;
  bool    _isLoading      = true;

  // ── Connected social identities ──
  Map<String, dynamic>? _socialGoogle;
  Map<String, dynamic>? _socialFacebook;
  Map<String, dynamic>? _socialTiktok;
  Map<String, dynamic>? _socialX;

  // ── Social profile URLs ──
  String? _facebookUrl;
  String? _xUrl;
  String? _tiktokUrl;
  String? _instagramUrl;
  String? _youtubeUrl;

  // ── Direct OAuth connect from profile icons ──
  String? _linkingProvider;
  StreamSubscription<AuthState>? _profileAuthSub;

  // ── Local images ──
  Uint8List? _localAvatar;
  Uint8List? _localCover;
  bool _avatarUploading = false;
  bool _coverUploading  = false;

  // ── Moments ──
  List<_MomentItem> _moments         = [];
  bool              _momentsLoading  = false;
  bool              _momentsError    = false;
  bool              _uploading       = false;

  // ── Soft error overlay ──
  OverlayEntry? _limitErrorOverlay;
  Timer?        _limitErrorTimer;

  // ── Block state (وضع الزائر) ──
  bool _iBlocked  = false;   // أنا عامل بلوك للشخص ده
  bool _blockedMe = false;   // هو عامل لي بلوك
  bool _blockBusy = false;

  // ── Visitor follow state ──
  bool _visitorIsFollowing   = false;
  bool _visitorFollowLoading = false;
  // البروفايل "للمتابعين بس" (require_follow_to_view)
  bool _followersOnly        = false;
  bool get _lockedForMe =>
      !_isOwner && !_isPreviewingOwnProfile && _followersOnly && !_visitorIsFollowing;

  // ── Language toggle ──
  // اللغة = لغة التطبيق دايماً (مش نسخة متخزنة وقت فتح الصفحة)
  bool get _isArabic => AppLang.isArabic;
  String _s(String en, String ar) => _isArabic ? ar : en;
  void _onLangChanged() { if (mounted) setState(() {}); }

  bool get _isOwner => widget.visitTarget == null;
  int? get _ugcOwnerId => _isOwner ? _myUserId : int.tryParse(widget.visitTarget!.userId);

  // حساب BDGR الرسمي (شكل مختلف: علامة دهبي، من غير بلوك ولا بيانات شخصية)
  bool _isOfficial = false;

  // true when owner is previewing their own profile as a visitor
  // اليوزر اللي عامل لوجن (بنقارن بيه علشان نعرف هو بيشوف بروفايله ولا لأ)
  int? _myUserId;

  bool get _isPreviewingOwnProfile =>
      !_isOwner &&
      _myUserId != null &&
      widget.visitTarget?.userId == _myUserId.toString();

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
    WidgetsBinding.instance.addObserver(this);
    if (!_isOwner) _visitorIsFollowing = widget.visitTarget!.isFollowing;
    _loadProfile();
    AppLang.changes.addListener(_onLangChanged);
    ProfileUi.changes.addListener(_onLangChanged);
    ProfileUi.warm();
    _profileAuthSub = _sb.auth.onAuthStateChange.listen(_onProfileAuthChange);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppLang.changes.removeListener(_onLangChanged);
    ProfileUi.changes.removeListener(_onLangChanged);
    _profileAuthSub?.cancel();
    _limitErrorTimer?.cancel();
    _limitErrorOverlay?.remove();
    super.dispose();
  }

  /// Fires when the app comes back to foreground — catches OAuth callbacks
  /// that return via deep link (external browser).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _linkingProvider != null) {
      _syncProfileIdentities();
    }
  }

  // ── Direct OAuth connect (from profile icons, no edit sheet needed) ─────────

  Future<void> _onProfileAuthChange(AuthState state) async {
    if (!mounted) return;
    if (state.event == AuthChangeEvent.userUpdated ||
        state.event == AuthChangeEvent.signedIn) {
      await _syncProfileIdentities();
    }
  }

  Future<void> _syncProfileIdentities() async {
    // Refresh session to get the latest identity list from the server
    try { await _sb.auth.refreshSession(); } catch (_) {}
    final user = _sb.auth.currentUser;
    if (user == null || !mounted) return;
    for (final identity in user.identities ?? <UserIdentity>[]) {
      final provider = identity.provider;
      final key = provider == 'twitter' ? 'x' : provider;
      if (!{'google', 'facebook', 'tiktok', 'x'}.contains(key)) continue;
      final idata = identity.identityData ?? <String, dynamic>{};
      final Map<String, dynamic> jsonData = {
        'provider_id': identity.id,
        if (idata['email']     != null) 'email':      idata['email'],
        if ((idata['name'] ?? idata['full_name'] ?? idata['user_name']) != null)
          'name': idata['name'] ?? idata['full_name'] ?? idata['user_name'],
        if (idata['user_name'] != null) 'user_name':  idata['user_name'],
        if ((idata['avatar_url'] ?? idata['picture']) != null)
          'avatar_url': idata['avatar_url'] ?? idata['picture'],
        'linked_at': DateTime.now().toIso8601String(),
      };
      try {
        await _sb.rpc('save_social_identity', params: {
          'p_provider': key,
          'p_data':     jsonData,
        });
      } catch (e) {
        debugPrint('save_social_identity error ($key): $e');
      }
      if (mounted) setState(() {
        switch (key) {
          case 'google':   _socialGoogle   = jsonData; break;
          case 'facebook': _socialFacebook = jsonData; break;
          case 'tiktok':   _socialTiktok   = jsonData; break;
          case 'x':        _socialX        = jsonData; break;
        }
      });
    }
    if (mounted) setState(() => _linkingProvider = null);
  }

  Future<void> _connectProviderDirect(String provKey) async {
    if (_linkingProvider != null) return;
    if (mounted) setState(() => _linkingProvider = provKey);
    try {
      if (provKey == 'tiktok') {
        final jwt = _sb.auth.currentSession?.accessToken;
        if (jwt == null) {
          if (mounted) setState(() => _linkingProvider = null);
          return;
        }
        String? linkToken;
        try {
          final tokenRes = await http.post(
            Uri.parse(
                '${AppConfig.supabaseUrl}/auth/v1/token'
                '?grant_type=link_identity'),
            headers: {
              'Authorization': 'Bearer $jwt',
              'apikey':        AppConfig.supabaseKey,
              'Content-Type':  'application/json',
            },
          );
          final body = jsonDecode(tokenRes.body) as Map<String, dynamic>;
          linkToken = body['link_token'] as String?;
        } catch (e) {
          debugPrint('link_token fetch error: $e');
        }
        final extra = linkToken != null
            ? '&link_token=${Uri.encodeComponent(linkToken)}'
            : '';
        final uri = Uri.parse(
          '${AppConfig.supabaseUrl}/auth/v1/authorize'
          '?provider=custom.tiktok'
          '$extra'
          '&redirect_to=${Uri.encodeComponent(AppConfig.redirectUrl)}',
        );
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Google / Facebook / X — same link_token approach as TikTok so
        // Supabase links to the existing account instead of creating a new one.
        final jwt = _sb.auth.currentSession?.accessToken;
        if (jwt == null) {
          if (mounted) setState(() => _linkingProvider = null);
          return;
        }
        String? linkToken;
        try {
          final tokenRes = await http.post(
            Uri.parse(
                '${AppConfig.supabaseUrl}/auth/v1/token'
                '?grant_type=link_identity'),
            headers: {
              'Authorization': 'Bearer $jwt',
              'apikey':        AppConfig.supabaseKey,
              'Content-Type':  'application/json',
            },
          );
          final body = jsonDecode(tokenRes.body) as Map<String, dynamic>;
          linkToken = body['link_token'] as String?;
        } catch (e) {
          debugPrint('link_token fetch error ($provKey): $e');
        }
        String? providerStr;
        switch (provKey) {
          case 'google':   providerStr = 'google';   break;
          case 'facebook': providerStr = 'facebook'; break;
          case 'x':        providerStr = 'twitter';  break;
        }
        if (providerStr == null) {
          if (mounted) setState(() => _linkingProvider = null);
          return;
        }
        final extra = linkToken != null
            ? '&link_token=${Uri.encodeComponent(linkToken)}'
            : '';
        final uri = Uri.parse(
          '${AppConfig.supabaseUrl}/auth/v1/authorize'
          '?provider=$providerStr'
          '$extra'
          '&redirect_to=${Uri.encodeComponent(AppConfig.redirectUrl)}',
        );
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('_connectProviderDirect error ($provKey): $e');
      if (mounted) {
        setState(() => _linkingProvider = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Connection failed: $e'),
          backgroundColor: Colors.red.shade700,
        ));
      }
    }
  }

  // ── Load profile ──────────────────────────────────────────────────────────

  /// زائر: نشوف الأول فيه بلوك بينّا ولا لأ
  Future<bool> _checkBlocked() async {
    if (_isOwner) return false;
    final target = int.tryParse(widget.visitTarget!.userId);
    if (target == null) return false;
    try {
      final res = await _sb.rpc('get_block_status', params: {'p_target_user_id': target});
      final row = res is List && res.isNotEmpty ? res.first as Map : null;
      _iBlocked  = row?['i_blocked']  == true;
      _blockedMe = row?['blocked_me'] == true;
    } catch (e) {
      debugPrint('get_block_status error: $e');
    }
    if (_iBlocked || _blockedMe) {
      if (mounted) setState(() => _isLoading = false);
      return true;
    }
    return false;
  }

  /// زائر: مين اللي عامل لوجن؟ وهل بيتابع البروفايل ده؟ (من السيرفر)
  Future<void> _loadVisitorContext() async {
    // رقم اليوزر بتاعي مطلوب لصاحب البروفايل كمان (البوستات بتتجاب بيه)
    try {
      final me = await _sb.rpc('get_my_iplay_user_id');
      _myUserId = (me as num?)?.toInt();
    } catch (e) {
      debugPrint('get_my_iplay_user_id error: $e');
    }
    if (_isOwner) return;
    final target = int.tryParse(widget.visitTarget!.userId);
    if (target == null || target == _myUserId) return;
    try {
      final res = await _sb.rpc('get_visitor_profile_card',
          params: {'p_target_user_id': target});
      final row = res is List && res.isNotEmpty ? res.first as Map : null;
      if (row != null) {
        _visitorIsFollowing = row['is_following'] == true;
        _followersOnly      = row['require_follow_to_view'] == true;
      }
    } catch (e) {
      debugPrint('follow state error: $e');
    }
  }

  Future<void> _loadCupTitles(int? id) async {
    if (id == null) return;
    try {
      final r = await _sb.rpc('badger_cup_titles', params: {'p_user_id': id});
      final n = (r as List?)?.length ?? 0;
      if (mounted && n != _cupTitles) setState(() => _cupTitles = n);
    } catch (_) {}
  }

  Future<void> _loadTrophies(int? id) async {
    if (id == null) return;
    final t = await ProfileTrophies.load(id);
    if (mounted) setState(() => _trophies = t);
    // لحظة الترقية: صاحب البروفايل بس، مرة واحدة لكل مستوى جديد
    if (mounted && t != null && _isOwner && !_isPreviewingOwnProfile) {
      Future.delayed(const Duration(milliseconds: 900), () { if (mounted) maybeShowTierUp(context, t); });
    }
  }

  /// كارت الفانتازي مكان دايرة الصورة (السويتش profile_card = card | circle)
  bool get _cardMode => !_isOfficial && ProfileTrophies.cardOn;

  /// visible tabs (DB switches, owner 27 Nov): Posts only when `profile_posts` = show,
  /// Career / Stats only when `profile_competitions` = show. Hidden tabs stay in the code.
  // `profile_tabs` = arena (launch): FANTASY title + Egypt (5) / World (6); classic = the tabs below
  bool get _arenaTabs => _cardMode && ProfileUi.arenaTabs;
  // `profile_bg_motion` = show: moving glow + sparks behind the page (only with no cover)
  bool get _ambient => _cardMode && !ProfileUi.cover && ProfileUi.bgMotion;
  List<int> get _tabIds => _arenaTabs ? const [5, 6] : [
        if (ProfileUi.posts) 0,
        if (ProfileUi.competitions) ...[3, 4],
        if (ProfileUi.competitions) ...[1, 2] else ...[2, 1],
      ];
  int get _tab => _tabIds.contains(_ptab) ? _ptab : _tabIds.first;

  /// page colour: launch (no cover) = soft graphite instead of near-black
  Color get _pageBg => _cardMode && !ProfileUi.cover ? const Color(0xFF17181D) : _kBg;

  Future<void> _loadProfile() async {
    if (await _checkBlocked()) return;
    await _loadVisitorContext();
    try {
      final res = await _sb.rpc(
        _isOwner ? 'get_my_profile_info' : 'get_public_profile',
        params: _isOwner
            ? null
            : {'p_user_id': int.parse(widget.visitTarget!.userId)},
      );
      if (res == null || (res as List).isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final d = res[0] as Map<String, dynamic>;
      final officialId = await OfficialAccount.load();
      if (!mounted) return;
      _loadCupTitles((d['user_id'] as num?)?.toInt());
      _loadTrophies((d['user_id'] as num?)?.toInt());
      setState(() {
        _userId         = (d['user_id'] as num?)?.toInt();
        _isOfficial     = officialId != null && _userId == officialId;
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
        _primarySportId   = d['primary_sport_id']?.toString();
        _primarySportName = d['primary_sport_name']?.toString();
        _socialGoogle   = d['social_google']   as Map<String, dynamic>?;
        _socialFacebook = d['social_facebook'] as Map<String, dynamic>?;
        _socialTiktok   = d['social_tiktok']   as Map<String, dynamic>?;
        _socialX        = d['social_x']        as Map<String, dynamic>?;
        _facebookUrl    = d['facebook_url']?.toString();
        _xUrl           = d['x_url']?.toString();
        _tiktokUrl      = d['tiktok_url']?.toString();
        _instagramUrl   = d['instagram_url']?.toString();
        _youtubeUrl     = d['youtube_url']?.toString();
        _isLoading = false;
      });
      await _loadMoments();
      // Sync any OAuth identities linked in auth but not yet saved to user_profile
      if (_isOwner) await _syncProfileIdentities();
    } catch (e) {
      debugPrint('profile error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Load moments ──────────────────────────────────────────────────────────

  Future<void> _loadMoments() async {
    if (!mounted) return;
    setState(() { _momentsLoading = true; _momentsError = false; });
    try {
      final res = ((await _sb.rpc(
        _isOwner ? 'get_my_moments' : 'get_public_moments',
        params: _isOwner
            ? null
            : {'p_user_id': int.parse(widget.visitTarget!.userId)},
      )) as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _moments = res.map((e) {
          final m = e as Map<String, dynamic>;
          return _MomentItem(
            id:            m['id'].toString(),
            storagePath:   m['storage_path'].toString(),
            mediaType:     m['media_type'].toString(),
            caption:       m['caption']?.toString(),
            createdAt:     DateTime.tryParse(m['created_at'].toString()) ?? DateTime.now(),
            likesCount:    (m['likes_count']    as num?)?.toInt() ?? 0,
            viewsCount:    (m['views_count']    as num?)?.toInt() ?? 0,
            commentsCount: (m['comments_count'] as num?)?.toInt() ?? 0,
            isLiked:         m['is_liked']  == true,
            isSaved:         m['is_saved']  == true,
            durationSeconds: (m['duration_seconds'] as num?)?.toDouble(),
          );
        }).toList();
        _momentsLoading = false;
      });
      _maybeOpenSharedMoment();
    } catch (e) {
      debugPrint('moments error: $e');
      if (mounted) setState(() { _momentsLoading = false; _momentsError = true; });
    }
  }

  bool _sharedMomentOpened = false;

  /// جاي من لينك مشاركة: افتح المومنت على طول (مرة واحدة)
  void _maybeOpenSharedMoment() {
    final id = widget.openMomentId;
    if (id == null || _sharedMomentOpened || !mounted) return;
    _sharedMomentOpened = true;
    final idx = _moments.indexWhere((m) => m.id.toLowerCase() == id);
    if (idx < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openMomentViewer(_moments[idx]);
    });
  }

  // ── Toggle like ──────────────────────────────────────────────────────────

  Future<void> _toggleLike(_MomentItem moment) async {
    // Optimistic update
    setState(() {
      if (moment.isLiked) {
        moment.isLiked = false;
        moment.likesCount = (moment.likesCount - 1).clamp(0, 999999);
      } else {
        moment.isLiked = true;
        moment.likesCount++;
      }
    });
    try {
      await _sb.rpc('toggle_like', params: {
        'p_content_id':   moment.id,
        'p_content_type': 'moment',
      });
    } catch (e) {
      // Revert on failure
      if (!mounted) return;
      setState(() {
        if (moment.isLiked) {
          moment.isLiked = false;
          moment.likesCount = (moment.likesCount - 1).clamp(0, 999999);
        } else {
          moment.isLiked = true;
          moment.likesCount++;
        }
      });
      debugPrint('toggle_like error: $e');
    }
  }

  // ── Extract video duration from local file ───────────────────────────────

  Future<double?> _extractVideoDuration(String filePath) async {
    VideoPlayerController? ctrl;
    try {
      ctrl = VideoPlayerController.file(File(filePath));
      await ctrl.initialize();
      final ms = ctrl.value.duration.inMilliseconds;
      return ms > 0 ? ms / 1000.0 : null;
    } catch (_) {
      return null;
    } finally {
      await ctrl?.dispose();
    }
  }

  // ── Upload moment ─────────────────────────────────────────────────────────

  Future<void> _addMoment({required bool isVideo, String? caption}) async {
    final authUid = _sb.auth.currentUser?.id;
    if (authUid == null) { _snack('Not authenticated.'); return; }

    // Quota check
    if (_moments.length >= 6) {
      _showLimitError('You\'ve reached the maximum of 6 moments.');
      return;
    }

    final picker = ImagePicker();
    final file   = isVideo
        ? await picker.pickVideo(source: ImageSource.gallery,
            maxDuration: const Duration(seconds: 60))
        : await picker.pickImage(source: ImageSource.gallery,
            imageQuality: 85);

    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      _showLimitError('File is too large. Maximum size is 5 MB.');
      return;
    }

    // Extract video duration before showing upload spinner
    double? durationSec;
    if (isVideo) durationSec = await _extractVideoDuration(file.path);

    setState(() => _uploading = true);
    try {
      final ext      = file.path.split('.').last.toLowerCase();
      final filename = '${const Uuid().v4()}.$ext';
      final path     = '$authUid/moments/$filename';
      final mime     = _mimeFromExt(ext, isVideo: isVideo);

      await _sb.storage.from('users').uploadBinary(
        path, bytes,
        fileOptions: FileOptions(contentType: mime, upsert: true),
      );

      final newId = await _sb.rpc('add_moment', params: {
        'p_storage_path': path,
        'p_media_type':   isVideo ? 'video' : 'image',
        'p_file_size':    bytes.length,
        if (caption != null && caption.isNotEmpty) 'p_caption': caption,
      });

      // مدة الفيديو: مهمة لقاعدة الـ 30% في الفيوز
      if (durationSec != null && durationSec > 0 && newId != null) {
        try {
          await _sb.rpc('set_moment_duration', params: {
            'p_moment_id': newId.toString(),
            'p_duration':  durationSec,
          });
        } catch (e) {
          debugPrint('set_moment_duration error: $e');
        }
      }

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
            maxDuration: const Duration(seconds: 60))
        : await picker.pickImage(source: ImageSource.gallery,
            imageQuality: 85);
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      _showLimitError('File is too large. Maximum size is 5 MB.');
      return;
    }

    // Extract video duration before showing upload spinner
    double? durationSec;
    if (isVideo) durationSec = await _extractVideoDuration(file.path);

    setState(() => _uploading = true);
    try {
      // Upload new file
      final ext      = file.path.split('.').last.toLowerCase();
      final filename = '${const Uuid().v4()}.$ext';
      final newPath  = '$authUid/moments/$filename';
      final mime     = _mimeFromExt(ext, isVideo: isVideo);

      await _sb.storage.from('users').uploadBinary(
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

      // مدة الفيديو الجديد
      if (durationSec != null && durationSec > 0) {
        try {
          await _sb.rpc('set_moment_duration', params: {
            'p_moment_id': m.id,
            'p_duration':  durationSec,
          });
        } catch (e) {
          debugPrint('set_moment_duration error: $e');
        }
      }

      // Delete old file from storage
      await _sb.storage.from('users').remove([m.storagePath]);

      await _loadMoments();
    } catch (e) {
      debugPrint('replace error: $e');
      _snack('Replace failed. Please try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── Delete moment ─────────────────────────────────────────────────────────

  Future<bool> _confirmDeleteMoment(BuildContext ctx) async {
    final res = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_s('Delete this moment?', 'تمسح المومنت ده؟'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(
          _s('It will be removed for everyone, with its Hypes, comments and views. This can\'t be undone.',
             'هيتمسح عند الكل، ومعاه الـ Hype والكومنتات والفيوز. ومش هتقدر ترجّعه.'),
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(_s('Cancel', 'إلغاء'),
                style: const TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(_s('Delete', 'امسح'),
                style: const TextStyle(color: _kAccent, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    return res == true;
  }

  Future<void> _deleteMoment(_MomentItem m) async {
    try {
      // الداتابيز الأول، وبعدين الملف: لو المسح فشل المومنت ما يفضلش من غير ملف
      await _sb.rpc('delete_moment', params: {'p_id': m.id});
      try {
        await _sb.storage.from('users').remove([m.storagePath]);
      } catch (e) {
        debugPrint('storage remove error: $e');
      }
      await _loadMoments();
    } catch (e) {
      debugPrint('delete error: $e');
      _snack('Could not delete moment.');
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

  /// بيمسح كل الصور القديمة في فولدر الأفاتار/الكفر بتاع اليوزر (ماعدا keep)
  /// علشان كل يوزر يفضل عنده صورة واحدة بس من كل نوع في الـ storage
  Future<void> _cleanImageFolder(String folder, {String? keep}) async {
    final authUid = _sb.auth.currentUser?.id;
    if (authUid == null) return;
    try {
      final files = await _sb.storage.from('users').list(path: '$authUid/$folder');
      final old = files.map((f) => f.name).where((n) => n != keep && n.isNotEmpty && !n.startsWith('.'))
          .map((n) => '$authUid/$folder/$n').toList();
      if (old.isNotEmpty) await _sb.storage.from('users').remove(old);
    } catch (e) {
      debugPrint('cleanImageFolder($folder) error: $e');
    }
  }

  Future<void> _uploadImage({
    required Uint8List bytes,
    required bool isCover,
    required String ext,
  }) async {
    final authUid = _sb.auth.currentUser?.id;
    if (authUid == null) {
      debugPrint('uploadImage: auth.currentUser is null');
      _snack('Not authenticated. Please log in again.');
      if (mounted) setState(() {
        if (isCover) _coverUploading = false;
        else         _avatarUploading = false;
      });
      return;
    }

    final folder   = isCover ? 'cover' : 'avatar';
    final filename = '${const Uuid().v4()}.$ext';
    final path     = '$authUid/$folder/$filename';
    final mime     = _mimeFromExt(ext, isVideo: false);
    debugPrint('uploadImage: uploading to Users/$path mime=$mime size=${bytes.length}');

    try {
      await _sb.storage.from('users').uploadBinary(
        path, bytes,
        fileOptions: FileOptions(contentType: mime, upsert: true),
      );
      debugPrint('uploadImage: storage upload success');
      final url = _sb.storage.from('users').getPublicUrl(path);
      debugPrint('uploadImage: public url = $url');
      if (isCover) {
        await _sb.rpc('update_my_profile', params: {'p_cover_url': url});
        if (mounted) setState(() { _coverUrl = url; _coverUploading = false; });
      } else {
        await _sb.rpc('update_my_profile', params: {'p_avatar_url': url});
        if (mounted) setState(() { _avatarUrl = url; _avatarUploading = false; });
      }
      // الصورة الجديدة اتحفظت ← نمسح القديمة
      _cleanImageFolder(folder, keep: filename);
      debugPrint('uploadImage: DB updated successfully');
    } catch (e) {
      debugPrint('uploadImage error: $e');
      if (mounted) setState(() {
        if (isCover) _coverUploading = false;
        else         _avatarUploading = false;
      });
      _snack('Upload error: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)));
  }

  void _showLimitError(String msg) {
    if (!mounted) return;
    // Remove any existing overlay
    _limitErrorTimer?.cancel();
    _limitErrorOverlay?.remove();
    _limitErrorOverlay = null;

    void dismiss() {
      _limitErrorTimer?.cancel();
      _limitErrorOverlay?.remove();
      _limitErrorOverlay = null;
    }

    _limitErrorOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 12,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3A3A3A)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4),
                  blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(children: [
              const Icon(Icons.info_outline,
                  color: Color(0xFFFF4444), size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(msg,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 13, height: 1.4))),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: dismiss,
                child: const Icon(Icons.close,
                    color: Colors.white38, size: 18),
              ),
            ]),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_limitErrorOverlay!);
    // Auto-dismiss after 5 seconds
    _limitErrorTimer = Timer(const Duration(seconds: 5), dismiss);
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
    if (_avatarUrl?.isNotEmpty == true) return MediaCache.image(_avatarUrl!);
    return null;
  }

  ImageProvider? get _coverImage {
    if (_localCover != null) return MemoryImage(_localCover!);
    if (_coverUrl?.isNotEmpty == true) return MediaCache.image(_coverUrl!);
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
    // الويب: path = blob url من غير امتداد، فالاسم هو اللي فيه الامتداد
    final fname = kIsWeb ? r.name : r.path;
    if (!_validExt(fname)) {
      _snack('Only jpg, png, and webp images are allowed.');
      return;
    }
    final bytes = await r.readAsBytes();
    if (!mounted) return;
    final ext = fname.split('.').last.toLowerCase();
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
      useRootNavigator: true,   // فوق شريط التابات، علشان زراير غيّر/شيل تبان
      useSafeArea: true,
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
          // مسح الصورة = مسح الملف من الـ storage كمان
          await _cleanImageFolder(isCover ? 'cover' : 'avatar');
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
      useRootNavigator: true,   // فوق شريط التابات وتحت الستاتس بار
      useSafeArea: true,
      builder: (_) => _EditProfileSheet(
        username: _username,
        displayName: _displayName, bio: _bio,
        country: _country, governorate: _governorate, city: _city,
        sportIds: _sportIds, birthDate: _birthDate, gender: _gender,
        primarySportId:   _primarySportId,
        primarySportName: _primarySportName,
        socialGoogle:   _socialGoogle,
        socialFacebook: _socialFacebook,
        socialTiktok:   _socialTiktok,
        socialX:        _socialX,
        onSave: ({required displayName, required bio, required country,
                  required governorate, required city,
                  required sportIds, Map<String,dynamic>? locationData,
                  DateTime? birthDate, String? gender,
                  String? primarySportId}) async {
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
            if (primarySportId != null) 'p_primary_sport_id': primarySportId,
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
    if (!_isOwner && (_iBlocked || _blockedMe)) return _buildBlockedScreen();
    final scroll = CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          // إعلان على بروفايلي أنا بس (مش على بروفايل حد تاني)
          if (_isOwner && !_isOfficial)
            const SliverToBoxAdapter(child: AdSlot('profile_own', padding: EdgeInsets.fromLTRB(16, 4, 16, 12))),
          if (_isOfficial)
            const SliverToBoxAdapter(child: OfficialPostsGrid())
          else ...[
            // تابات البروفايل (27 نوفمبر): بوستات · إنجازات · فانتازي
            // (المسيرة / الإحصائيات / الفيديوهات بتتضاف لما يبقى ليها داتا)
            SliverToBoxAdapter(child: _buildProfileTabs()),
            if (_tab == 5 || _tab == 6)
              SliverToBoxAdapter(child: FantasyProfileTab(
                key: ValueKey('arena-$_tab'),
                t: _trophies, isOwner: _isOwner, arena: _tab == 6 ? 'WORLD' : 'LOCAL',
                onPlay: _isOwner ? () => HomeActions.showFantasyTab?.call() : null))
            else if (_tab == 1)
              SliverToBoxAdapter(child: TrophiesTab(
                t: _trophies, isOwner: _isOwner,
                onPlay: _isOwner ? () => HomeActions.showFantasyTab?.call() : null))
            else if (_tab == 2)
              SliverToBoxAdapter(child: FantasyProfileTab(
                t: _trophies, isOwner: _isOwner,
                onPlay: _isOwner ? () => HomeActions.showFantasyTab?.call() : null))
            else if (_tab == 3 || _tab == 4)
              SliverToBoxAdapter(child: ProfileSoonTab(kind: _tab == 3 ? 'career' : 'stats', t: _trophies))
            else if (_lockedForMe)
              SliverToBoxAdapter(child: _buildLockedProfile())
            // بوستات اليوزر (UGC) — بدل المومنتس القديمة
            else if (_ugcOwnerId != null)
              SliverToBoxAdapter(child: UgcProfileSection(
                key: ValueKey('ugc-$_ugcOwnerId'),
                ownerId: _ugcOwnerId!,
                isOwner: _isOwner,
                ownerName: _displayName.isNotEmpty ? _displayName : (widget.visitTarget?.displayName ?? ''),
              )),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      );
    return Scaffold(
      backgroundColor: _pageBg,
      body: !_ambient ? scroll : Stack(children: [
        Positioned.fill(child: ProfileAmbient(tier: _trophies?.tier ?? 'new', base: _pageBg, fillNav: ProfileUi.navFill)),
        scroll,
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() => _isOfficial ? _buildOfficialHeader() : _cardMode ? _buildCardHeader() : Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildCover(),
      SizedBox(
        height: 60,
        child: Stack(children: [
          // Following / Followers / Fans يمين الأفاتار
          Positioned(
            left: 16 + 90 + 12, right: 12, top: 6,
            child: _buildStats(),
          ),
          OverflowBox(
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
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildNameRow(),
          const SizedBox(height: 14),
          if (_hasSocialLinks) ...[
            _buildSocialLinks(),
            const SizedBox(height: 14),
          ],
          Text(
            _bio.isNotEmpty ? _bio
                : _isOfficial ? _s('The official BDGR account', 'الحساب الرسمي لـ BDGR')
                : _s('Unranked. Unafraid.', 'غير مصنف. لا يهاب.'),
            style: TextStyle(
              color: (_bio.isNotEmpty || _isOfficial) ? Colors.white70 : Colors.white38,
              fontSize: 14, height: 1.5,
              fontStyle: (_bio.isNotEmpty || _isOfficial) ? FontStyle.normal : FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          if (!_isOfficial) ...[
            _buildMeta(),
            const SizedBox(height: 12),
          ],
          if (_sportNames.isNotEmpty && !_isOfficial) ...[
            _buildSportsSection(),
            const SizedBox(height: 12),
          ],
          if (_isOwner)                                        _buildOwnerButtons(),
          if (!_isOwner && !_isPreviewingOwnProfile)          _buildVisitorButtons(),
          const SizedBox(height: 8),
        ]),
      ),
    ],
  );

  // ── هيدر الكارت (27 نوفمبر): كارت الفانتازي مكان الدايرة، الاسم جنبه،
  // والأرقام سطر صغير تحت. باقي الهيدر زي ما هو.
  /// مكان سطر النقط تحت الكارت (لو فيه أكتر من كارت بس)
  double get _dotsH => ProfileCardCarousel.count(_trophies) > 1 ? ProfileCardCarousel.dotsH : 0;

  Widget _buildCardHeader() {
    // الكارت في نص الصفحة على حرف الغلاف، وكل اللي تحته في النص (الرسم اللي اتوافق عليه 27 نوفمبر)
    const cw = 108.0;
    const ch = cw * FantasyProfileCard.ratio; // ~147
    const lift = 84.0;
    final coverH = 160 + MediaQuery.of(context).padding.top;
    final sw = MediaQuery.of(context).size.width;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _buildCover(),
          SizedBox(height: ch - lift + 6 + _dotsH),
        ]),
        // كروت البروفايل بتتقلب (PROFILE v3): نفس مكان ومقاس الكارت، والكروت اللي جنبه باهتة
        Positioned(
          left: 0, right: 0, top: coverH - lift,
          child: ProfileCardCarousel(
            key: ValueKey('cards-${_trophies == null ? 0 : 1}-${_trophies?.cardSports.length ?? 0}'),
            width: cw, t: _trophies,
            name: _displayName.isNotEmpty ? _displayName : 'BDGR Athlete',
            isOwner: _isOwner, photo: _avatarImage,
            onChangePhoto: _isOwner ? _pickAvatar : null,
          ),
        ),
        // زرار الكاميرا بره طرف الكارت (ما يغطيش الكلام اللي جوه)
        if (_isOwner)
          Positioned(
            left: (sw + cw) / 2 - 10, top: coverH - lift + ch - 26,
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(color: _kAccent, shape: BoxShape.circle,
                    border: Border.all(color: _pageBg, width: 2.5)),
                child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
              ),
            ),
          ),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(child: Text(
              _displayName.isNotEmpty ? _displayName : 'BDGR Athlete',
              textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w800, letterSpacing: -0.5),
            )),
            if (_isVerified && Brand.showVerifiedBadge) ...[
              const SizedBox(width: 6),
              const Icon(Icons.verified, color: Brand.green, size: 18),
            ],
          ]),
          if (_username.isNotEmpty)
            Text('@$_username', style: const TextStyle(color: _kGray, fontSize: 13)),
          const SizedBox(height: 10),
          _buildStatsLine(),
          // social icons / bio / sports chips = DB switches (hidden on launch, code kept)
          if (_hasSocialLinks && ProfileUi.socials) ...[
            const SizedBox(height: 14),
            _buildSocialLinks(),
          ],
          if (ProfileUi.bio) ...[
            const SizedBox(height: 14),
            Text(
              _bio.isNotEmpty ? _bio : _s('Unranked. Unafraid.', 'غير مصنف. لا يهاب.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _bio.isNotEmpty ? Colors.white70 : Colors.white38,
                fontSize: 14, height: 1.5,
                fontStyle: _bio.isNotEmpty ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ],
          _buildMetaLine(),
          if (_sportNames.isNotEmpty && ProfileUi.competitions) ...[
            const SizedBox(height: 12),
            _buildSportsSection(),
          ],
          // `profile_owner_buttons` = hide (launch): no Change photo / View as Visitor (the camera badge changes the photo)
          if (_isOwner && ProfileUi.ownerButtons) ...[const SizedBox(height: 14), _buildOwnerButtons()],
          if (!_isOwner && !_isPreviewingOwnProfile) ...[const SizedBox(height: 14),
            ProfileUi.ownerButtons ? _buildVisitorButtons() : Center(child: SizedBox(width: 230, child: _buildVisitorButtons()))],
          const SizedBox(height: 4),
        ]),
      ),
    ]);
  }

  /// المكان · السن في سطر واحد في النص
  Widget _buildMetaLine() {
    final parts = <String>[];
    final loc = [_city, _governorate, _country].where((x) => x.isNotEmpty).toSet().join(', ');
    if (loc.isNotEmpty) parts.add('📍 $loc');
    if (_birthDate != null) {
      final age = DateTime.now().year - _birthDate!.year;
      parts.add(_s('🎂 $age', '🎂 $age سنة'));
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(parts.join('  ·  '), textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
    );
  }

  /// متابعين · بيتابع · إنجازات (سطر واحد في النص). الإنجازات = كل اللي كسبه في أي نشاط → تاب الإنجازات.
  Widget _buildStatsLine() {
    // الأرقام بتتعد لما الصفحة تفتح (موشن المرحلة ١)
    Widget one(String v, String label, VoidCallback? onTap) {
      const numStyle = TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800);
      final n = int.tryParse(v.replaceAll(',', ''));
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          n == null ? Text(v, style: numStyle)
              : CountBetween(from: 0, to: n, ms: 900, style: numStyle, format: (x) => '$x'),
          Text(' $label', style: const TextStyle(color: _kGray, fontSize: 13)),
        ]),
      );
    }
    const dot = Padding(padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text('·', style: TextStyle(color: _kGray, fontSize: 13)));
    return Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
      one(_followersCount, _s('Followers', 'متابعون'), _isOwner ? () => _openUserList('followers') : null), dot,
      one(_followingCount, _s('Following', 'يتابع'), _isOwner ? () => _openUserList('following') : null), dot,
      one('${_trophies?.trophies ?? 0}', _s('Trophies', 'إنجازات'), _tabIds.contains(1) ? () => setState(() => _ptab = 1) : null),
    ]);
  }

  /// صف التابات تحت الهيدر
  Widget _buildProfileTabs() {
    if (_arenaTabs) return _buildArenaTabs();
    // ترتيب العرض: بوستات · المشوار (قريب) · الإحصائيات (قريب) · إنجازات · فانتازي
    // (_ptab: 0 بوستات · 1 إنجازات · 2 فانتازي · 3 المشوار · 4 الإحصائيات)
    final all = <int, (String, bool)>{
      0: (_s('Posts', 'البوستات'), false),
      3: (_s('Career', 'المشوار'), true),
      4: (_s('Stats', 'الإحصائيات'), true),
      1: (_s('Trophies', 'الإنجازات'), false),
      2: (_s('Fantasy', 'الفانتازي'), false),
    };
    final tabs = <(int, String, bool)>[for (final i in _tabIds) (i, all[i]!.$1, all[i]!.$2)];
    final cur = _tab;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF)))),
      child: Row(children: [
        for (final (i, label, soon) in tabs)
          Expanded(child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _ptab = i),
            child: Column(children: [
              const SizedBox(height: 12),
              SizedBox(height: 20, child: FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(label, style: TextStyle(
                    color: cur == i ? Colors.white : _kGray, fontSize: 14,
                    fontWeight: cur == i ? FontWeight.w800 : FontWeight.w500)),
                if (soon) ...[
                  const SizedBox(width: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFF2A2A30), borderRadius: BorderRadius.circular(5)),
                    child: Text(_s('soon', 'قريب'), style: const TextStyle(color: Colors.white54, fontSize: 8.5)),
                  ),
                ],
              ]))),
              const SizedBox(height: 8),
              AnimatedContainer(duration: const Duration(milliseconds: 200),
                  height: 2.5, width: cur == i ? 40 : 0,
                  decoration: BoxDecoration(color: const Color(0xFFFF2B2B), borderRadius: BorderRadius.circular(2))),
            ]),
          )),
      ]),
    );
  }

  /// launch tabs (owner 27 Nov): FANTASY title in the middle + Egypt / World switch under it
  Widget _buildArenaTabs() {
    final cur = _tab;
    Widget seg(int i, String flag, String label) {
      final on = cur == i;
      return Expanded(child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () { if (!on) { Buzz.tap(); setState(() => _ptab = i); } },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: on ? const Color(0xFF2E2F37) : Colors.transparent,
              borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(flag, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: on ? Colors.white : _kGray, fontSize: 14,
                fontWeight: on ? FontWeight.w800 : FontWeight.w500)),
          ]),
        ),
      ));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(children: [
        Text(_s('FANTASY', 'الفانتازي'), style: TextStyle(color: Colors.white, fontSize: 15,
            fontWeight: FontWeight.w900, letterSpacing: _isArabic ? 0 : 4)),
        const SizedBox(height: 6),
        Container(width: 36, height: 3, decoration: BoxDecoration(
            color: const Color(0xFFFF2B2B), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: const Color(0xD9202127), borderRadius: BorderRadius.circular(13)),
          child: Row(children: [
            seg(5, '🇪🇬', _s('Egypt', 'محلي')),
            seg(6, '🌍', _s('World', 'دولي')),
          ]),
        ),
      ]),
    );
  }

  // ── صفحة BDGR الرسمية: شكل مختلف عن أي بروفايل ─────────────────────────
  // غلاف كبير والاسم عليه (من غير دايرة أفاتار ولا أرقام متابعين)،
  // والهوية أحمر BDGR؛ الدهبي بس في علامة التوثيق والغلاف.
  Widget _buildOfficialHeader() {
    final top = MediaQuery.of(context).padding.top;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 250 + top,
        child: Stack(fit: StackFit.expand, children: [
          if (_coverImage != null)
            Image(image: _coverImage!, fit: BoxFit.cover)
          else
            Stack(fit: StackFit.expand, children: [
              Container(color: Colors.black),
              Center(child: Opacity(opacity: 0.22,
                  child: Image.asset('assets/badger_white.png', color: OfficialAccount.gold, fit: BoxFit.contain))),
            ]),
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0x66000000), Colors.transparent, Color(0xF20B0B0F)],
            stops: [0, 0.35, 1],
          ))),
          Positioned(top: top + 10, left: 12, child: _backBtn()),
          Positioned(
            left: 16, right: 16, bottom: 14,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Flexible(child: Text(
                  _displayName.isNotEmpty ? _displayName : 'BDGR',
                  style: const TextStyle(color: Colors.white, fontSize: 30,
                      fontWeight: FontWeight.w900, letterSpacing: -0.5),
                )),
                const SizedBox(width: 8),
                const OfficialBadge(size: 24),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                if (_username.isNotEmpty) ...[
                  Text('@$_username', style: const TextStyle(color: Colors.white60, fontSize: 13)),
                  const SizedBox(width: 10),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kAccent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kAccent.withOpacity(0.55)),
                  ),
                  child: Text(_s('Official account', 'الحساب الرسمي'),
                      style: const TextStyle(color: Color(0xFFFF5A5A), fontSize: 11.5, fontWeight: FontWeight.w800)),
                ),
              ]),
            ]),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_hasSocialLinks) ...[
            _buildSocialLinks(),
            const SizedBox(height: 12),
          ],
          Text(
            _bio.isNotEmpty ? _bio : _s('The official BDGR account', 'الحساب الرسمي لـ BDGR'),
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const HelpSupportPage())),
              icon: const Icon(Icons.mail_outline_rounded, size: 19),
              label: Text(_s('Contact BDGR', 'تواصل مع BDGR'),
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  // ── بروفايل للمتابعين بس ────────────────────────────────────────────────
  Widget _buildLockedProfile() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(children: [
        Container(
          width: 54, height: 54,
          decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1.5)),
          child: const Icon(Icons.lock_outline_rounded, color: Colors.white70, size: 26),
        ),
        const SizedBox(height: 14),
        Text(_s('This profile is for followers only', 'البروفايل ده للمتابعين بس'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(_s('Follow to see their moments.', 'تابعه علشان تشوف المومنتس بتاعته.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5)),
      ]),
    ),
  );

  // ── Cover ─────────────────────────────────────────────────────────────────

  Widget _buildCover() {
    final top = MediaQuery.of(context).padding.top;
    // `profile_cover` = hide (launch): no cover photo, a soft graphite top with a red glow + the faint badger
    if (_cardMode && !ProfileUi.cover) {
      return SizedBox(
        height: 160 + top,
        child: Stack(children: [
          if (!_ambient)
          Positioned.fill(child: Container(decoration: BoxDecoration(gradient: RadialGradient(
            center: const Alignment(0, -1.1), radius: 1.25,
            colors: [const Color(0xFF3A1C1F), _pageBg], stops: const [0, 0.72])))),
          Positioned(left: 0, right: 0, top: top + 4, height: 96,
            child: Center(child: Opacity(opacity: 0.08,
                child: Image.asset('assets/badger_white.png', fit: BoxFit.contain)))),
          if (!_isOwner)
            Positioned(top: top + 10, left: 12, child: _backBtn()),
          if (!_isOwner && !_isPreviewingOwnProfile && !_isOfficial)
            Positioned(top: top + 10, right: 12, child: _iconBtn(Icons.more_horiz, _openVisitorMenu)),
        ]),
      );
    }
    final stack = SizedBox(
      height: 160 + top,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: _coverImage != null
              ? Image(image: _coverImage!, fit: BoxFit.cover)
              : Stack(fit: StackFit.expand, children: [
                  Container(color: _isOfficial ? Colors.black : const Color(0xFF0D0808)),
                  Center(child: Opacity(opacity: _isOfficial ? 0.22 : 0.12,
                    child: Image.asset('assets/badger_white.png',
                        color: _isOfficial ? OfficialAccount.gold : null,
                        fit: BoxFit.contain))),
                ]),
        ),
        // كروت البروفايل (27 نوفمبر): الكوفر بيغمق وبينزل لحد ما يبقى نفس لون الصفحة،
        // فالكروت تقعد على غامق والكوفر يبقى جو بس.
        Positioned.fill(child: Container(
          decoration: BoxDecoration(gradient: _cardMode
              ? LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.35), Colors.black.withOpacity(0.55), _kBg],
                  stops: const [0, 0.45, 1])
              : LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                )),
        )),
        if (_isOwner)
          Positioned(top: top + 10, right: 12,
            child: _iconBtn(Icons.camera_alt, _pickCover)),
        if (!_isOwner)
          Positioned(top: top + 10, left: 12,
            child: _backBtn()),
        if (!_isOwner && !_isPreviewingOwnProfile && !_isOfficial)
          Positioned(top: top + 10, right: 12,
            child: _iconBtn(Icons.more_horiz, _openVisitorMenu)),
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
          border: Border.all(
              color: _isOfficial ? OfficialAccount.gold : _kBg,
              width: _isOfficial ? 2.5 : 3),
          color: _isOfficial ? Colors.black : _kCard,
          image: _avatarImage != null
              ? DecorationImage(image: _avatarImage!, fit: BoxFit.cover)
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: _avatarImage == null
            ? (_isOfficial
                ? const OfficialAvatarFallback()
                : const Icon(Icons.person, color: Colors.white38, size: 40))
            : null,
      ),
      if (_isOwner)
        Positioned(bottom: 2, right: 2, child: Container(
          width: 26, height: 26,
          decoration: BoxDecoration(color: _kAccent, shape: BoxShape.circle,
              border: Border.all(color: _kBg, width: 2)),
          child: const Icon(Icons.camera_alt, size: 13, color: Colors.white),
        )),
    ]);
    if (!_isOwner) return GestureDetector(onTap: _viewAvatarFullscreen, child: circle);
    return GestureDetector(onTap: _pickAvatar, child: circle);
  }

  Widget _buildNameRow() => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      // Left: display name + @username
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Flexible(child: Text(
                _displayName.isNotEmpty ? _displayName : 'BDGR Athlete',
                style: const TextStyle(color: Colors.white, fontSize: 22,
                    fontWeight: FontWeight.w800, letterSpacing: -0.5),
              )),
              if (_isOfficial) ...[
                const SizedBox(width: 6),
                const OfficialBadge(size: 20),
              ] else if (_isVerified && Brand.showVerifiedBadge) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified, color: Brand.green, size: 18),
              ],
            ]),
            if (_username.isNotEmpty)
              Text('@$_username', style: const TextStyle(color: _kGray, fontSize: 13)),
            if (_cupTitles > 0 && !_cardMode) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x29FFB300),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x8CFFB300)),
                ),
                child: Text(
                  AppLang.t('🏆 Badger Cup champion', '🏆 بطل كاس بادجر') + (_cupTitles > 1 ? ' ×$_cupTitles' : ''),
                  style: const TextStyle(color: Color(0xFFFFB300), fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
            if (_isOfficial) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: OfficialAccount.goldSoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: OfficialAccount.gold.withOpacity(0.5)),
                ),
                child: Text(_s('Official account', 'الحساب الرسمي'),
                    style: const TextStyle(color: OfficialAccount.gold,
                        fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    ],
  );

  Widget _buildStats() => _isOfficial
      ? Row(children: [
          Expanded(child: _stat(_followersCount, _s('Followers', 'متابعون'), () {})),
        ])
      : Row(
    mainAxisSize: MainAxisSize.max,
    children: [
      Expanded(child: _stat(_followingCount, _s('Following', 'يتابع'),   () => _openUserList('following'))),
      Expanded(child: _stat(_followersCount, _s('Followers', 'متابعون'), () => _openUserList('followers'))),
      Expanded(child: GestureDetector(onTap: () => setState(() => _ptab = 1),
          child: _stat('${_trophies?.trophies ?? 0}', _s('Trophies', 'إنجازات'), () => setState(() => _ptab = 1)))),
    ],
  );

  // في وضع الزائر الأرقام للعرض بس: القوايم دي بتاعة صاحب الحساب
  Widget _stat(String val, String label, VoidCallback onTap) =>
    GestureDetector(
      onTap: _isOwner ? onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(val, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );

  Future<void> _openUserList(String type) async {
    final rpc = type == 'following' ? 'get_my_following'
              : type == 'followers' ? 'get_my_followers'
              : 'get_my_fans';
    final title = type == 'following' ? 'Following'
                : type == 'followers' ? 'Followers'
                : 'Fans';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UserListSheet(
          rpc: rpc, title: title, type: type, isOwner: _isOwner),
    );
  }

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
      items.add(_metaChip(Icons.cake_outlined, _s('Age $age', 'عمر $age')));
    }
    if (_joinedAt != null) {
      const monthsEn = ['Jan','Feb','Mar','Apr','May','Jun',
          'Jul','Aug','Sep','Oct','Nov','Dec'];
      const monthsAr = ['يناير','فبراير','مارس','أبريل','مايو','يونيو',
          'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
      final m = _joinedAt!.month - 1;
      items.add(_metaChip(Icons.calendar_today_outlined,
          _s('Joined ${monthsEn[m]} ${_joinedAt!.year}',
             'انضم ${monthsAr[m]} ${_joinedAt!.year}')));
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

  Widget _buildSportsSection() {
    final secondaryNames = _primarySportName != null
        ? _sportNames.where((n) => n != _primarySportName).toList()
        : _sportNames;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // "Passionate about [🔥 Football chip]"
      if (_primarySportName != null)
        Row(children: [
          Text(_s('Passionate about  ', 'شغوف بـ  '),
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kAccent.withOpacity(0.7)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('🔥', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              Text(_primarySportName!,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      // "Also loves [Padel chip] [MMA chip]"
      if (secondaryNames.isNotEmpty) ...[
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          if (_primarySportName != null)
            Text(_s('Also loves  ', 'يحب أيضاً  '),
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Wrap(spacing: 6, runSpacing: 6,
            children: secondaryNames.map((name) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kBorder),
              ),
              child: Text(name, style: const TextStyle(
                  color: Colors.white70, fontSize: 11)),
            )).toList()),
        ]),
      ],
    ]);
  }

  bool get _hasSocialLinks =>
      _isOwner ||
      _facebookUrl?.isNotEmpty  == true ||
      _xUrl?.isNotEmpty         == true ||
      _tiktokUrl?.isNotEmpty    == true ||
      _instagramUrl?.isNotEmpty == true ||
      _youtubeUrl?.isNotEmpty   == true;

  Widget _buildSocialLinks() {
    final providers = <Map<String, dynamic>>[
      {'key': 'facebook',  'svg': _kFacebookSvg,  'url': _facebookUrl},
      {'key': 'x',         'svg': _kXSvg,         'url': _xUrl},
      {'key': 'tiktok',    'svg': _kTiktokSvg,    'url': _tiktokUrl},
      {'key': 'instagram', 'svg': _kInstagramSvg, 'url': _instagramUrl},
      {'key': 'youtube',   'svg': _kYoutubeSvg,   'url': _youtubeUrl},
    ];
    // Visitors only see icons that have a URL; owner sees all 5
    final visible = _isOwner
        ? providers
        : providers.where((p) => (p['url'] as String?)?.isNotEmpty == true).toList();

    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (int i = 0; i < visible.length; i++) ...[
        if (i > 0) const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _onSocialIconTap(
            visible[i]['key'] as String,
            visible[i]['url'] as String?,
          ),
          child: _socialIcon(
            visible[i]['svg'] as String,
            connected: (visible[i]['url'] as String?)?.isNotEmpty == true,
          ),
        ),
      ],
    ]);
  }

  LaunchMode _launchModeFor(String url) {
    // Custom Tabs (Android) / SFSafariViewController (iOS):
    // opens inside app UI, handles fb:// redirects, user returns with X button.
    return LaunchMode.inAppBrowserView;
  }

  void _onSocialIconTap(String key, String? url) {
    final hasUrl = url != null && url.isNotEmpty;
    if (!_isOwner) {
      if (hasUrl) launchUrl(Uri.parse(url), mode: _launchModeFor(url));
      return;
    }
    if (hasUrl) {
      _showSocialOptions(key, url);
    } else {
      _showSocialInput(key, null);
    }
  }

  void _showSocialOptions(String key, String url) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.open_in_new, color: Colors.white70),
            title: const Text('Open', style: TextStyle(color: Colors.white)),
            onTap: () async {
              Navigator.pop(context);
              await launchUrl(Uri.parse(url), mode: _launchModeFor(url));
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: Colors.white70),
            title: const Text('Edit', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _showSocialInput(key, url);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showSocialInput(String key, String? currentUrl) {
    final ctrl = TextEditingController(text: currentUrl ?? '');
    final label = _socialLabel(key);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('$label Profile URL',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'https://...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.07),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Brand.green,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => _saveSocialUrl(ctx, key, ctrl.text.trim()),
                child: const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
          ]),
        );
      },
    );
  }

  Future<void> _saveSocialUrl(BuildContext ctx, String key, String urlStr) async {
    final uri = Uri.tryParse(urlStr);
    if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Please enter a valid URL'),
          backgroundColor: Colors.red.shade700));
      return;
    }
    try {
      // من خلال الدالة الآمنة بدل الكتابة في الجدول مباشرة
      await _sb.rpc('update_my_profile', params: {'p_${key}_url': urlStr});
      if (mounted) {
        Navigator.pop(ctx);
        setState(() {
          switch (key) {
            case 'facebook':  _facebookUrl  = urlStr; break;
            case 'x':         _xUrl         = urlStr; break;
            case 'tiktok':    _tiktokUrl    = urlStr; break;
            case 'instagram': _instagramUrl = urlStr; break;
            case 'youtube':   _youtubeUrl   = urlStr; break;
          }
        });
      }
    } catch (e) {
      debugPrint('saveSocialUrl error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red.shade700));
    }
  }

  String _socialLabel(String key) {
    switch (key) {
      case 'facebook':  return 'Facebook';
      case 'x':         return 'X';
      case 'tiktok':    return 'TikTok';
      case 'instagram': return 'Instagram';
      case 'youtube':   return 'YouTube';
      default:          return key;
    }
  }

  Widget _socialIcon(String svgStr, {bool connected = true, bool loading = false}) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: connected
            ? Colors.white.withOpacity(0.12)
            : Colors.white.withOpacity(0.04),
        shape: BoxShape.circle,
        border: Border.all(
          color: connected
              ? Colors.white.withOpacity(0.28)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white70))
            : Opacity(
                opacity: connected ? 1.0 : 0.30,
                child: SvgPicture.string(svgStr, width: 18, height: 18),
              ),
      ),
    );
  }

  Widget _buildOwnerButtons() => Row(children: [
    // `profile_edit` = photo (launch): the button only changes the photo; full = the old Edit Profile sheet
    Expanded(child: _cardMode && !ProfileUi.fullEdit
        ? _outlineBtn(Icons.photo_camera_outlined, _s('Change photo', 'غيّر الصورة'), _pickAvatar)
        : _outlineBtn(Icons.edit_outlined, _s('Edit Profile', 'تعديل البروفايل'), _openEdit)),
    const SizedBox(width: 10),
    Expanded(child: _outlineBtn(Icons.visibility_outlined,
        _s('View as Visitor', 'مشاهدة كزائر'), _openVisitorPreview)),
  ]);

  void _openVisitorPreview() {
    if (_userId == null) return;
    // أول شاشة للزائر (الصورة الكبيرة)، ومنها See Profile بيفتح البروفايل كامل
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisitorProfileSheet(
          userId: _userId!,
          isOwnPreview: true,
        ),
      ),
    );
  }

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

  // ── Back button (visitor mode) ───────────────────────────────────────────
  Widget _backBtn() =>
      Material(color: Colors.black45, borderRadius: BorderRadius.circular(10),
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
      );

  // ── Language toggle button ────────────────────────────────────────────────
  Widget _langBtn() => GestureDetector(
    onTap: () { AppLang.set(_isArabic ? 'en' : 'ar'); LocalStore.setLang(AppLang.isArabic ? 'ar' : 'en'); },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(
          _isArabic ? 'English' : 'عربي',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 5),
        const Icon(Icons.language, color: Colors.white70, size: 15),
      ]),
    ),
  );

  // ── Block / Unblock ──────────────────────────────────────────────────────
  void _openVisitorMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.block, color: Color(0xFFFF5C5C)),
          title: Text(_s('Block', 'بلوك'),
              style: const TextStyle(color: Color(0xFFFF5C5C), fontWeight: FontWeight.w700)),
          subtitle: Text(_s("You won't see each other's profiles",
                            'مش هتشوفوا بروفايلات بعض'),
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
          onTap: () { Navigator.pop(ctx); _blockUser(); },
        ),
      ),
    );
  }

  // البلوك: يختار سبب من قايمة (من غير كتابة) ← بلوك ← شكرًا ← يرجع لورا
  static const _blockReasons = [
    ('spam',          'Spam',                          'سبام'),
    ('harassment',    'Harassment or bullying',        'تحرش أو تنمّر'),
    ('inappropriate', 'Inappropriate content',         'محتوى مش لائق'),
    ('fake',          'Fake account',                  'حساب مزيّف'),
    ('other',         'Other',                         'سبب تاني'),
  ];

  Future<void> _blockUser() async {
    final name = _displayName.isNotEmpty ? _displayName : widget.visitTarget!.displayName;
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _kCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) {
        String? picked;
        return StatefulBuilder(builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(_s('Why are you blocking $name?', 'ليه بتعمل بلوك لـ $name؟'),
                  style: const TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(_s("You won't see each other anymore.", 'مش هتشوفوا بعض تاني.'),
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 14),
              for (final (key, en, ar) in _blockReasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => setSheet(() => picked = key),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: picked == key ? const Color(0x22FF5C5C) : _kField,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: picked == key
                            ? const Color(0xFFFF5C5C) : _kBorder),
                      ),
                      child: Row(children: [
                        Expanded(child: Text(_s(en, ar), style: TextStyle(
                            color: Colors.white,
                            fontWeight: picked == key ? FontWeight.w700 : FontWeight.w400))),
                        Icon(picked == key ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: picked == key ? const Color(0xFFFF5C5C) : Colors.white38, size: 20),
                      ]),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: picked == null ? null : () => Navigator.pop(ctx, picked),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5C5C),
                  disabledBackgroundColor: Colors.white12,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_s('Block', 'بلوك'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ]),
          ),
        ));
      },
    );
    if (reason == null || !mounted) return;

    setState(() => _blockBusy = true);
    final target = int.parse(widget.visitTarget!.userId);
    try {
      await _sb.rpc('block_user', params: {'p_target_user_id': target});
      try {
        await _sb.rpc('set_block_reason',
            params: {'p_target_user_id': target, 'p_reason': reason});
      } catch (e) {
        debugPrint('set_block_reason error: $e');   // السبب مش أساسي
      }
    } catch (e) {
      debugPrint('block_user error: $e');
      if (mounted) {
        setState(() => _blockBusy = false);
        _snack(_s('Could not block. Try again.', 'معرفناش نعمل بلوك، جرّب تاني.'));
      }
      return;
    }
    if (!mounted) return;
    setState(() { _iBlocked = true; _blockBusy = false; });

    // شكرًا ← ونرجّعه للشاشة اللي كان فيها
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.check_circle, color: Brand.green, size: 44),
        title: Text(_s('Thank you', 'شكرًا ليك'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(_s("$name is blocked. You won't see each other anymore.",
                         '$name اتعمله بلوك. مش هتشوفوا بعض تاني.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d),
              child: Text(_s('Done', 'تمام'),
                  style: const TextStyle(color: Brand.green, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  Future<void> _unblockUser() async {
    setState(() => _blockBusy = true);
    try {
      await _sb.rpc('unblock_user',
          params: {'p_target_user_id': int.parse(widget.visitTarget!.userId)});
      if (!mounted) return;
      setState(() { _iBlocked = false; _blockBusy = false; _isLoading = true; });
      await _loadProfile();
    } catch (e) {
      debugPrint('unblock_user error: $e');
      if (mounted) setState(() => _blockBusy = false);
    }
  }

  Widget _buildBlockedScreen() {
    final top = MediaQuery.of(context).padding.top;
    final name = widget.visitTarget?.displayName ?? '';
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.block, color: Colors.white24, size: 56),
              const SizedBox(height: 16),
              Text(
                _iBlocked
                    ? _s('You blocked $name', 'إنت عامل بلوك لـ $name')
                    : _s('This profile is not available', 'البروفايل ده مش متاح'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 17,
                    fontWeight: FontWeight.w800),
              ),
              if (_iBlocked) ...[
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: _blockBusy ? null : _unblockUser,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _blockBusy
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_s('Unblock', 'شيل البلوك'),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
          ),
        ),
        Positioned(top: top + 10, left: 12, child: _backBtn()),
      ]),
    );
  }

  // ── Visitor Follow / Unfollow button ─────────────────────────────────────
  Widget _buildVisitorButtons() {
    // الحساب الرسمي: كل الناس متابعينه تلقائي، فمكان Follow زرار تواصل مع الدعم
    if (_isOfficial) {
      return SizedBox(
        width: double.infinity,
        height: 44,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HelpSupportPage())),
          icon: const Icon(Icons.mail_outline_rounded, size: 18),
          label: Text(_s('Contact BDGR', 'تواصل مع BDGR'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          style: OutlinedButton.styleFrom(
            foregroundColor: OfficialAccount.gold,
            backgroundColor: OfficialAccount.gold.withOpacity(0.08),
            side: BorderSide(color: OfficialAccount.gold.withOpacity(0.55)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    }
    final following = _visitorIsFollowing;
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        // متابَع: الدوسة بتفتح خيار إلغاء المتابعة (بتأكيد) — مش بتلغيها على طول
        onPressed: _visitorFollowLoading
            ? null
            : (following ? _confirmUnfollow : _toggleVisitorFollow),
        style: ElevatedButton.styleFrom(
          backgroundColor: following ? _kCard : const Color(0xFFFF0000),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF2A2A2A),
          elevation: 0,
          side: following ? const BorderSide(color: _kBorder) : null,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        child: _visitorFollowLoading
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Row(mainAxisSize: MainAxisSize.min, children: [
                if (following) ...[
                  const Icon(Icons.check, size: 16),
                  const SizedBox(width: 6),
                ],
                Text(
                  following ? _s('Following', 'متابَع') : _s('Follow', 'تابِع'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                if (following) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 18),
                ],
              ]),
      ),
    );
  }

  void _confirmUnfollow() {
    final name = _displayName.isNotEmpty ? _displayName : widget.visitTarget!.displayName;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 14),
          Text(name, style: const TextStyle(color: Colors.white,
              fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ListTile(
            leading: const Icon(Icons.person_remove_outlined, color: Color(0xFFFF5C5C)),
            title: Text(_s('Unfollow', 'إلغاء المتابعة'),
                style: const TextStyle(color: Color(0xFFFF5C5C), fontWeight: FontWeight.w700)),
            onTap: () { Navigator.pop(ctx); _toggleVisitorFollow(); },
          ),
        ]),
      ),
    );
  }

  Future<void> _toggleVisitorFollow() async {
    if (_visitorFollowLoading || _userId == null) return;
    final wasFollowing = _visitorIsFollowing;
    setState(() {
      _visitorIsFollowing   = !wasFollowing;
      _visitorFollowLoading = true;
    });
    try {
      await _sb.rpc(
        wasFollowing ? 'unfollow_user' : 'follow_user',
        params: {'p_target_user_id': _userId},
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _visitorIsFollowing = wasFollowing);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _visitorFollowLoading = false);
    }
    // بروفايل للمتابعين بس: بعد المتابعة/إلغائها المومنتس تتفتح أو تتقفل
    if (_followersOnly && mounted) await _loadMoments();
  }

  // ── View-only avatar fullscreen (visitor mode) ────────────────────────────
  void _viewAvatarFullscreen() {
    final img = _avatarImage;
    if (img == null) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: Image(image: img),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                width: 36, height: 36,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                onPickImage: (caption) => _addMoment(isVideo: false, caption: caption),
                onPickVideo: (caption) => _addMoment(isVideo: true,  caption: caption),
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
        ownerName: _displayName,
        onDelete: () async {
          // تأكيد الأول: ممكن يكون داس بالغلط
          final sure = await _confirmDeleteMoment(ctx);
          if (!sure) return;
          if (ctx.mounted) Navigator.pop(ctx);
          await _deleteMoment(m);
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
    if (_momentsError) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: GestureDetector(
          onTap: _loadMoments,
          child: const Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.refresh, color: Colors.white38, size: 28),
            SizedBox(height: 8),
            Text('Tap to reload moments',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          ]),
        )),
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
            onLike: () => _toggleLike(_moments[i]),
          )),
          const SizedBox(width: 10),
          Expanded(child: i + 1 < _moments.length
              ? _MomentCard(
                  moment: _moments[i + 1],
                  isOwner: _isOwner,
                  onTap: () => _openMomentViewer(_moments[i + 1]),
                  onLike: () => _toggleLike(_moments[i + 1]),
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
        _addBtn('Add First Moment', Icons.add, () {
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (ctx) => _AddMomentDialog(
              onPickImage: (c) { Navigator.pop(ctx); _addMoment(isVideo: false, caption: c); },
              onPickVideo: (c) { Navigator.pop(ctx); _addMoment(isVideo: true,  caption: c); },
            ),
          );
        }),
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
  final bool                    uploading;
  final void Function(String?)  onPickImage;
  final void Function(String?)  onPickVideo;

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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AddMomentDialog(
        onPickImage: (caption) { Navigator.pop(ctx); onPickImage(caption); },
        onPickVideo: (caption) { Navigator.pop(ctx); onPickVideo(caption); },
      ),
    );
  }
}

// ── Add Moment Dialog ─────────────────────────────────────────────────────────

class _AddMomentDialog extends StatefulWidget {
  const _AddMomentDialog({
    required this.onPickImage,
    required this.onPickVideo,
  });
  final void Function(String?) onPickImage;
  final void Function(String?) onPickVideo;

  @override
  State<_AddMomentDialog> createState() => _AddMomentDialogState();
}

class _AddMomentDialogState extends State<_AddMomentDialog> {
  final _captionCtrl = TextEditingController();

  @override
  void dispose() { _captionCtrl.dispose(); super.dispose(); }

  String? get _caption {
    final t = _captionCtrl.text.trim();
    return t.isNotEmpty ? t : null;
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
      child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.white24,
              borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Row(children: [
          const Expanded(child: Text('Add Moment', style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))),
          Material(color: const Color(0xFF2A2A2A), shape: const CircleBorder(),
            child: InkWell(onTap: () => Navigator.pop(context),
              customBorder: const CircleBorder(),
              child: const SizedBox(width: 32, height: 32,
                child: Icon(Icons.close, color: Colors.white54, size: 16)))),
        ]),
        const SizedBox(height: 6),
        const Text('Share a new part of your sports story.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        const SizedBox(height: 20),
        // Caption
        const Text('CAPTION (OPTIONAL)', style: TextStyle(
            color: Colors.white54, fontSize: 10,
            fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        TextField(
          controller: _captionCtrl,
          maxLength: 100,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g. Training Mode',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
            counterStyle: const TextStyle(color: Colors.white38, fontSize: 10),
            filled: true, fillColor: const Color(0xFF242424),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF2A2A2A))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF2A2A2A))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFFF0000))),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 16),
        // Photo / Video buttons
        Row(children: [
          Expanded(child: _mediaBtn('Choose Photo',
              Icons.image_outlined, () => widget.onPickImage(_caption))),
          const SizedBox(width: 10),
          Expanded(child: _mediaBtn('Choose Video',
              Icons.videocam_outlined, () => widget.onPickVideo(_caption))),
        ]),
        const SizedBox(height: 10),
        Text('Photos: JPG, PNG or WebP · up to 5 MB\n'
            'Videos: MP4, MOV or WebM · up to 60s · up to 5 MB',
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10, height: 1.5)),
      ]),
    );
  }

  Widget _mediaBtn(String label, IconData icon, VoidCallback onTap) =>
      Material(color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10),
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

// ── Moment Circle (story) ─────────────────────────────────────────────────────

class _MomentCircle extends StatefulWidget {
  const _MomentCircle({
    required this.moment,
    required this.isOwner,
    required this.onTap,
  });
  final _MomentItem  moment;
  final bool         isOwner;
  final VoidCallback onTap;

  @override
  State<_MomentCircle> createState() => _MomentCircleState();
}

class _MomentCircleState extends State<_MomentCircle>
    with SingleTickerProviderStateMixin {
  AnimationController?    _ring;
  VideoPlayerController?  _vpc;
  bool                    _videoReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.moment.isVideo) {
      _ring = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2),
      )..repeat();
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    final ctrl = await MediaCache.video(widget.moment.publicUrl());
    if (!mounted) { ctrl.dispose(); return; }
    _vpc = ctrl;
    await ctrl.initialize();
    if (mounted) {
      setState(() => _videoReady = true);
      ctrl.setVolume(0);
      ctrl.setLooping(true);
      ctrl.play();
    }
  }

  @override
  void dispose() { _ring?.dispose(); _vpc?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.moment.isVideo;

    return GestureDetector(
      onTap: widget.onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 64, height: 64,
          child: Stack(alignment: Alignment.center, children: [
            // Animated ring for video
            if (isVideo && _ring != null)
              AnimatedBuilder(
                animation: _ring!,
                builder: (_, __) => CustomPaint(
                  size: const Size(64, 64),
                  painter: _RingPainter(_ring!.value),
                ),
              )
            else
              // Static border for image
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF2A2A2A),
                    width: 2,
                  ),
                ),
              ),
            // Content
            Container(
              width: 56, height: 56,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Color(0xFF1A1A1A)),
              child: ClipOval(
                child: isVideo
                    ? (_videoReady && _vpc != null
                        ? FittedBox(fit: BoxFit.cover,
                            child: SizedBox(
                              width:  _vpc!.value.size.width,
                              height: _vpc!.value.size.height,
                              child:  VideoPlayer(_vpc!),
                            ))
                        : Container(color: Colors.black))
                    : Image(image: MediaCache.image(widget.moment.publicUrl()),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image, color: Colors.white38)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 4),
        // Caption if available, else empty
        Text(
          widget.moment.caption?.isNotEmpty == true
              ? widget.moment.caption!
              : '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 10,
              fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }
}

// ── Ring Painter ──────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final rect   = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style        = PaintingStyle.stroke
      ..strokeWidth  = 2.5
      ..strokeCap    = StrokeCap.round
      ..shader       = SweepGradient(
          colors: const [
            Color(0xFFFF0000),
            Color(0xFFFF6B00),
            Color(0xFFFFD700),
            Color(0xFFFF0000),
          ],
          transform: GradientRotation(progress * 2 * 3.14159),
        ).createShader(rect);

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ── Moment Card (grid) ────────────────────────────────────────────────────────

class _MomentCard extends StatefulWidget {
  const _MomentCard({
    required this.moment,
    required this.isOwner,
    required this.onTap,
    required this.onLike,
  });
  final _MomentItem  moment;
  final bool         isOwner;
  final VoidCallback onTap;
  final VoidCallback onLike;

  @override
  State<_MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends State<_MomentCard> {
  VideoPlayerController? _vpc;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.moment.isVideo) _initVideo();
  }

  Future<void> _initVideo() async {
    final ctrl = await MediaCache.video(widget.moment.publicUrl());
    if (!mounted) { ctrl.dispose(); return; }
    _vpc = ctrl;
    await ctrl.initialize();
    if (mounted) {
      setState(() => _videoReady = true);
      ctrl.setVolume(0);    // silent
      ctrl.setLooping(true);
      ctrl.play();
    }
  }

  @override
  void dispose() {
    _vpc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
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
            widget.moment.isVideo
                ? (_videoReady && _vpc != null
                    ? FittedBox(fit: BoxFit.cover,
                        child: SizedBox(
                          width:  _vpc!.value.size.width,
                          height: _vpc!.value.size.height,
                          child:  VideoPlayer(_vpc!),
                        ))
                    : Stack(fit: StackFit.expand, children: [
                        Container(color: Colors.black),
                        const Center(child: CircularProgressIndicator(
                            color: Color(0xFFFF0000), strokeWidth: 2)),
                      ]))
                : Image(image: MediaCache.image(widget.moment.publicUrl()), fit: BoxFit.cover,
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
            // Bottom: caption + likes + comments
            Positioned(left: 10, right: 10, bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.moment.caption?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(widget.moment.caption!,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white,
                            fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  Row(children: [
                    GestureDetector(
                      onTap: widget.onLike,
                      behavior: HitTestBehavior.opaque,
                      child: Row(children: [
                        Icon(
                          widget.moment.isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 11,
                          color: widget.moment.isLiked
                              ? const Color(0xFFFF0000)
                              : const Color(0xFFD1D5DB),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${widget.moment.likesCount}',
                          style: const TextStyle(
                              color: Color(0xFFD1D5DB), fontSize: 10),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.chat_bubble_outline,
                        size: 11, color: Color(0xFFD1D5DB)),
                    const SizedBox(width: 3),
                    Text(
                      '${widget.moment.commentsCount}',
                      style: const TextStyle(
                          color: Color(0xFFD1D5DB), fontSize: 10),
                    ),
                  ]),
                ],
              ),
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
    required this.onReplace,
    this.ownerName = '',
  });
  final _MomentItem  moment;
  final bool         isOwner;
  final String       ownerName;
  final VoidCallback onDelete;
  final VoidCallback onReplace;

  @override
  State<_MomentViewerSheet> createState() => _MomentViewerSheetState();
}

class _MomentViewerSheetState extends State<_MomentViewerSheet> {
  VideoPlayerController? _vpc;
  bool _videoReady = false;

  // Engagement local state (optimistic)
  late bool _isLiked;
  late int  _likesCount;
  late bool _isSaved;
  late int  _viewsCount;
  late int  _commentsCount;

  // ── Watch-time tracking (السيرفر هو اللي بيقرر الفيو) ──────────────────────
  Timer?  _watchTimer;
  double  _watchSeconds  = 0;
  bool    _qualifiedSent = false;   // طلب الاحتساب شغال أو خلص
  bool    _viewCounted   = false;   // السيرفر وافق
  int     _qualifyTries  = 0;
  double  _nextTryAt     = 0;

  // ── Share ──
  bool _sharing = false;

  // ── Hype animation ──
  bool _hypeBump  = false;
  bool _showBurst = false;

  @override
  void initState() {
    super.initState();
    _isLiked       = widget.moment.isLiked;
    _likesCount    = widget.moment.likesCount;
    _isSaved       = widget.moment.isSaved;
    _viewsCount    = widget.moment.viewsCount;
    _commentsCount = widget.moment.commentsCount;
    if (widget.moment.isVideo) _initVideo();
    _recordView();
    _startWatchTimer();
  }

  // ── فتح المومنت: السيرفر بيسجل وقت البداية ───────────────────────────────
  Future<void> _recordView() async {
    if (widget.isOwner) return;            // صاحب المومنت ما يتحسبش
    try {
      await _sb.rpc('start_view', params: {
        'p_content_id':   widget.moment.id,
        'p_content_type': 'moment',
      });
    } catch (_) {}
  }

  // ── Watch-time helpers ────────────────────────────────────────────────────

  /// نفس قاعدة السيرفر: فيديو = 30% من مدته (أقل حاجة 3 ثواني)، صورة = ثانيتين.
  /// بنزود ثانية احتياطي علشان فرق الوقت بين الموبايل والسيرفر.
  double get _requiredSeconds {
    if (!widget.moment.isVideo) return 3;
    final dur = widget.moment.durationSeconds ??
        (_vpc?.value.duration.inMilliseconds ?? 0) / 1000.0;
    final need = dur > 0 ? dur * 0.3 : 3.0;
    return (need < 3 ? 3.0 : need) + 1;
  }

  void _startWatchTimer() {
    if (widget.isOwner) return;
    // كل ثانية: الفيديو بيتحسب بس وهو شغال فعلًا، والصورة طول ما هي مفتوحة
    _watchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_viewCounted) return;
      final counting = widget.moment.isVideo
          ? (_vpc != null && _vpc!.value.isPlaying)
          : true;
      if (!counting) return;
      _watchSeconds++;
      if (!_qualifiedSent &&
          _watchSeconds >= _requiredSeconds &&
          _watchSeconds >= _nextTryAt) {
        _tryQualify();
      }
    });
  }

  /// بنطلب من السيرفر يحسب الفيو. لو رفض (بدري) نحاول تاني بعد شوية.
  Future<void> _tryQualify() async {
    if (_qualifiedSent || _viewCounted || _qualifyTries >= 6) return;
    _qualifiedSent = true;
    _qualifyTries++;
    bool ok = false;
    try {
      final res = await _sb.rpc('qualify_view', params: {
        'p_content_id':   widget.moment.id,
        'p_content_type': 'moment',
      });
      ok = res == true;
    } catch (_) {}
    if (ok) {
      _viewCounted = true;
      _watchTimer?.cancel();
    } else {
      _qualifiedSent = false;
      _nextTryAt = _watchSeconds + 3;
    }
  }

  Future<void> _toggleLike() async {
    if (!_isLiked) {
      _hypeBump = true;
      Future<void>.delayed(const Duration(milliseconds: 160), () {
        if (mounted) setState(() => _hypeBump = false);
      });
    }
    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likesCount = (_likesCount - 1).clamp(0, 999999);
      } else {
        _isLiked = true;
        _likesCount++;
      }
    });
    widget.moment.isLiked    = _isLiked;
    widget.moment.likesCount = _likesCount;
    try {
      await _sb.rpc('toggle_like', params: {
        'p_content_id':   widget.moment.id,
        'p_content_type': 'moment',
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLiked    = !_isLiked;
        _likesCount = _isLiked
            ? _likesCount + 1
            : (_likesCount - 1).clamp(0, 999999);
      });
      widget.moment.isLiked    = _isLiked;
      widget.moment.likesCount = _likesCount;
    }
  }

  Future<void> _toggleSave() async {
    setState(() => _isSaved = !_isSaved);
    widget.moment.isSaved = _isSaved;
    try {
      await _sb.rpc('toggle_save', params: {
        'p_content_id':   widget.moment.id,
        'p_content_type': 'moment',
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaved = !_isSaved);
      widget.moment.isSaved = _isSaved;
    }
  }

  void _openComments() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CommentsSheet(
        momentId:      widget.moment.id,
        isMomentOwner: widget.isOwner,
        onCountChanged: (n) {
          if (mounted) setState(() => _commentsCount = n);
          widget.moment.commentsCount = n;
        },
      ),
    );
  }

  void _openReport() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReportSheet(
        contentId:   widget.moment.id,
        contentType: 'moment',
      ),
    );
  }

  Future<void> _initVideo() async {
    final ctrl = await MediaCache.video(widget.moment.publicUrl());
    if (!mounted) { ctrl.dispose(); return; }
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
    _watchTimer?.cancel();
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
          // 1. Media content
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
              : Image(image: MediaCache.image(widget.moment.publicUrl()), fit: BoxFit.contain)),
          // 2. Tap = play/pause (فيديو) — Double tap = Hype
          Positioned.fill(child: GestureDetector(
            onTap: widget.moment.isVideo && _videoReady
                ? () => setState(() {
                      _vpc!.value.isPlaying ? _vpc!.pause() : _vpc!.play();
                    })
                : null,
            onDoubleTap: _doubleTapHype,
            behavior: HitTestBehavior.opaque,
          )),
          // 2b. نار كبيرة في النص لما يعمل Hype بالدبل تاب
          Positioned.fill(child: IgnorePointer(
            child: Center(
              child: AnimatedOpacity(
                opacity: _showBurst ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: AnimatedScale(
                  scale: _showBurst ? 1.0 : 0.6,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  child: const Icon(Icons.local_fire_department,
                      color: Brand.green, size: 120,
                      shadows: [Shadow(color: Color(0x9900FF87), blurRadius: 30)]),
                ),
              ),
            ),
          )),
          // 3a. ⋯ (ريبورت) — للزائر بس
          if (!widget.isOwner)
            Positioned(top: 12, right: 56,
              child: Material(color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _openMoreMenu,
                  customBorder: const CircleBorder(),
                  child: Container(width: 36, height: 36,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24)),
                    child: const Icon(Icons.more_horiz, color: Colors.white, size: 20)),
                ),
              ),
            ),
          // 3. X button on top — always receives tap
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
          // 4. Right-side engagement bar: Hype / Comment / Share
          Positioned(
            right: 12,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: _hypeBump ? 1.25 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: _engBtn(
                    icon: _isLiked
                        ? Icons.local_fire_department
                        : Icons.local_fire_department_outlined,
                    label: _likesCount > 0 ? _short(_likesCount) : 'Hype',
                    active: _isLiked,
                    onTap: _toggleLike,
                  ),
                ),
                const SizedBox(height: 18),
                _engBtn(
                  icon: Icons.mode_comment_outlined,
                  label: _commentsCount > 0 ? _short(_commentsCount) : AppLang.t('Comment', 'تعليق'),
                  onTap: _openComments,
                ),
                const SizedBox(height: 18),
                _engBtn(
                  icon: _sharing ? Icons.hourglass_top : Icons.ios_share,
                  label: _sharing ? '...' : AppLang.t('Share', 'شارك'),
                  onTap: _share,
                ),
              ],
            ),
          ),
          // 5. الفيوز تحت على الشمال (معلومة مش زرار)
          Positioned(
            left: 14,
            bottom: 28,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.remove_red_eye_outlined,
                  color: Colors.white70, size: 16,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
              const SizedBox(width: 6),
              Text(AppLang.t('${_short(_viewsCount)} views', '${_short(_viewsCount)} مشاهدة'),
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
            ]),
          ),
        ]),
      ),
      // Actions bar
      if (widget.isOwner)
        Container(
          color: const Color(0xFF1A1A1A),
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
          child: Row(children: [
            Expanded(child: _actionBtn(
              Icons.swap_horiz, AppLang.t('Replace', 'استبدال'),
              Colors.white60, widget.onReplace,
            )),
            const SizedBox(width: 8),
            Expanded(child: _actionBtn(
              Icons.delete_outline, AppLang.t('Delete', 'مسح'),
              Colors.white38, widget.onDelete,
            )),
          ]),
        ),
    ]);
  }

  // ── زرار التفاعل: مربع مايل شفاف (من روح لوجو BDGR) ─────────────────────
  static const double _skew = -0.18;

  Widget _engBtn({
    required IconData icon,
    required String   label,
    VoidCallback?     onTap,
    bool              active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.skewX(_skew),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: active ? const Color(0x2600FF87) : const Color(0x59000000),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? Brand.green : Colors.white24,
                width: active ? 1.5 : 1,
              ),
              boxShadow: active
                  ? const [BoxShadow(color: Color(0x5500FF87), blurRadius: 14)]
                  : null,
            ),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.skewX(-_skew),
              child: Icon(icon,
                  color: active ? Brand.green : Colors.white, size: 23),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(
            color: active ? Brand.green : Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            shadows: const [Shadow(color: Colors.black87, blurRadius: 4)])),
      ]),
    );
  }

  String _short(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
    return '$n';
  }

  /// Double tap: Hype بس (مش بيشيله لو موجود) + نار كبيرة
  void _doubleTapHype() {
    setState(() => _showBurst = true);
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _showBurst = false);
    });
    if (!_isLiked) _toggleLike();
  }

  /// قايمة ⋯ للزائر
  void _openMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.flag_outlined, color: Colors.white70),
          title: Text(AppLang.t('Report', 'إبلاغ'), style: const TextStyle(color: Colors.white)),
          onTap: () {
            Navigator.pop(ctx);
            _openReport();
          },
        ),
      ),
    );
  }

  /// الشير: بيفتح قايمة المشاركة، ولو اتشارك بيتسجل في الداتابيز
  /// الشير: لينك بس (من غير الفيديو/الصورة). اللينك بيفتح المومنت جوه
  /// التطبيق، ولو التطبيق مش موجود بيعرض زرار التحميل. المحتوى ما بيطلعش برّه.
  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final name = widget.ownerName.trim().isNotEmpty
        ? widget.ownerName.trim() : 'BDGR Athlete';
    final text = '🔥 Watch $name\'s moment on BDGR\n'
        '${Brand.momentShareLink(widget.moment.id)}';
    ShareResult result;
    try {
      result = await Share.share(text);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
    if (result.status != ShareResultStatus.success) return;
    final raw = result.raw.toLowerCase();
    String? platform;
    if (raw.contains('whatsapp'))                               platform = 'whatsapp';
    else if (raw.contains('facebook'))                          platform = 'facebook';
    else if (raw.contains('instagram'))                         platform = 'instagram';
    else if (raw.contains('twitter') || raw.contains('x.com'))  platform = 'x';
    else if (raw.contains('telegram'))                          platform = 'telegram';
    else if (raw.contains('tiktok'))                            platform = 'tiktok';
    else if (raw.isNotEmpty)                                    platform = raw;
    try {
      await _sb.rpc('record_share', params: {
        'p_content_id':   widget.moment.id,
        'p_content_type': 'moment',
        'p_platform':     platform,
      });
    } catch (_) {}
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
    final mq     = MediaQuery.of(context);
    final bottom = mq.padding.bottom;
    final imgH   = (mq.size.height * 0.62).clamp(220.0, 760.0).toDouble();
    final ar     = AppLang.isArabic;
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
          Expanded(child: _btn(Icons.edit_outlined, ar ? 'غيّر الصورة' : 'Change',
              const Color(0xFFFF0000), onEdit)),
          const SizedBox(width: 10),
          Expanded(child: _btn(Icons.delete_outline, ar ? 'شيل الصورة' : 'Remove',
              Colors.white70, onRemove)),
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
    required this.username,
    required this.displayName, required this.bio,
    required this.country,     required this.governorate,
    required this.city,        required this.sportIds,
    this.birthDate,            this.gender,
    this.primarySportId,       this.primarySportName,
    this.socialGoogle,  this.socialFacebook,
    this.socialTiktok,  this.socialX,
    required this.onSave,
  });
  final String              username;
  final String              displayName;
  final String              bio;
  final String              country;
  final String              governorate;
  final String              city;
  final List<String>        sportIds;
  final DateTime?           birthDate;
  final String?             gender;
  final String?             primarySportId;
  final String?             primarySportName;
  final Map<String,dynamic>? socialGoogle;
  final Map<String,dynamic>? socialFacebook;
  final Map<String,dynamic>? socialTiktok;
  final Map<String,dynamic>? socialX;
  final Future<void> Function({
    required String displayName, required String bio,
    required String country,     required String governorate,
    required String city,        required List<String> sportIds,
    Map<String,dynamic>? locationData,
    DateTime? birthDate, String? gender,
    String? primarySportId,
  }) onSave;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> with WidgetsBindingObserver {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _usernameCtrl;
  bool  _checkingUsername = false;
  bool? _usernameAvailable;   // null = same as original / not checked
  Timer? _usernameDebounce;
  String? _country;
  String? _governorate;
  String? _city;
  bool _countryManual = false;
  bool _governorateManual = false;
  bool _cityManual = false;
  late List<String> _selectedSportIds;
  String?   _primarySportId;
  DateTime? _birthDate;
  String?   _gender;
  List<Map<String,String>> _sports = [];
  bool _loadingSports = true;
  bool _loadingGps    = false;
  bool _saving        = false;
  Map<String,dynamic>? _locationData;

  // ── Connected social identities ──
  Map<String,dynamic>? _connectedGoogle;
  Map<String,dynamic>? _connectedFacebook;
  Map<String,dynamic>? _connectedTikTok;
  Map<String,dynamic>? _connectedX;
  String? _linkingProvider; // non-null while OAuth is in progress
  bool _isArabic = false;

  // Auth-state listener that fires when identity is linked
  late final StreamSubscription<AuthState> _authSub;

  List<String> get _govList  => _kGovernorates[_country ?? ''] ?? [];
  List<String> get _cityList => _kCities[_governorate ?? ''] ?? [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nameCtrl         = TextEditingController(text: widget.displayName);
    _bioCtrl          = TextEditingController(text: widget.bio);
    _usernameCtrl     = TextEditingController(text: widget.username);
    _usernameCtrl.addListener(_onUsernameChanged);
    _country          = widget.country.isNotEmpty     ? widget.country     : null;
    _governorate      = widget.governorate.isNotEmpty ? widget.governorate : null;
    _city             = widget.city.isNotEmpty         ? widget.city         : null;
    _selectedSportIds = List.from(widget.sportIds);
    _birthDate        = widget.birthDate;
    _gender           = widget.gender;
    _primarySportId   = widget.primarySportId;
    // Social identity initial state from parent
    _connectedGoogle   = widget.socialGoogle;
    _connectedFacebook = widget.socialFacebook;
    _connectedTikTok   = widget.socialTiktok;
    _connectedX        = widget.socialX;
    // Listen for identityLinked events
    _authSub = _sb.auth.onAuthStateChange.listen(_onAuthStateChange);
    _loadSports();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _usernameDebounce?.cancel();
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _usernameCtrl.dispose();
    _authSub.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _linkingProvider != null) {
      _syncIdentities();
    }
  }

  // ── OAuth helpers ─────────────────────────────────────────────────────────

  /// Called whenever Supabase fires an auth state change.
  /// `userUpdated` fires when an identity is linked in supabase_flutter ^2.x.
  Future<void> _onAuthStateChange(AuthState state) async {
    if (!mounted) return;
    if (state.event == AuthChangeEvent.userUpdated ||
        state.event == AuthChangeEvent.signedIn) {
      await _syncIdentities();
    }
  }

  /// Reads the current user's identities, saves any new social ones to DB,
  /// and updates the UI state.
  Future<void> _syncIdentities() async {
    // Refresh session to get the latest identity list from the server.
    try { await _sb.auth.refreshSession(); } catch (_) {}
    final user = _sb.auth.currentUser;
    if (user == null || !mounted) return;

    for (final identity in user.identities ?? <UserIdentity>[]) {
      final provider = identity.provider;
      // Supabase uses 'twitter' internally; we store it as 'x'.
      final key = provider == 'twitter' ? 'x' : provider;
      if (!{'google', 'facebook', 'tiktok', 'x'}.contains(key)) continue;

      final idata = identity.identityData ?? <String, dynamic>{};
      final Map<String, dynamic> jsonData = {
        'provider_id': identity.id,
        if (idata['email']    != null) 'email':      idata['email'],
        if ((idata['name'] ?? idata['full_name'] ?? idata['user_name']) != null)
          'name': idata['name'] ?? idata['full_name'] ?? idata['user_name'],
        if (idata['user_name']  != null) 'user_name':  idata['user_name'],
        if ((idata['avatar_url'] ?? idata['picture']) != null)
          'avatar_url': idata['avatar_url'] ?? idata['picture'],
        if (idata['phone']    != null) 'phone':      idata['phone'],
        'linked_at': DateTime.now().toIso8601String(),
      };

      try {
        await _sb.rpc('save_social_identity', params: {
          'p_provider': key,
          'p_data':     jsonData,
        });
      } catch (e) {
        debugPrint('save_social_identity error ($key): $e');
      }

      if (mounted) setState(() {
        switch (key) {
          case 'google':   _connectedGoogle   = jsonData; break;
          case 'facebook': _connectedFacebook = jsonData; break;
          case 'tiktok':   _connectedTikTok   = jsonData; break;
          case 'x':        _connectedX        = jsonData; break;
        }
      });
    }

    if (mounted) setState(() => _linkingProvider = null);
  }

  /// Opens the OAuth browser to link [provKey] to the current account.
  Future<void> _connectProvider(String provKey) async {
    if (_linkingProvider != null) return;
    setState(() => _linkingProvider = provKey);
    try {
      if (provKey == 'tiktok') {
        // TikTok is a custom Supabase provider — get a link_token first so
        // Supabase links to the existing account instead of creating a new one.
        final jwt = _sb.auth.currentSession?.accessToken;
        if (jwt == null) {
          if (mounted) setState(() => _linkingProvider = null);
          return;
        }
        String? linkToken;
        try {
          final tokenRes = await http.post(
            Uri.parse(
                '${AppConfig.supabaseUrl}/auth/v1/token'
                '?grant_type=link_identity'),
            headers: {
              'Authorization': 'Bearer $jwt',
              'apikey':        AppConfig.supabaseKey,
              'Content-Type':  'application/json',
            },
          );
          final body = jsonDecode(tokenRes.body) as Map<String, dynamic>;
          linkToken = body['link_token'] as String?;
        } catch (e) {
          debugPrint('link_token fetch error: $e');
          // Proceed without token — Supabase may still link correctly.
        }
        final extra = linkToken != null
            ? '&link_token=${Uri.encodeComponent(linkToken)}'
            : '';
        final uri = Uri.parse(
          '${AppConfig.supabaseUrl}/auth/v1/authorize'
          '?provider=custom.tiktok'
          '$extra'
          '&redirect_to=${Uri.encodeComponent(AppConfig.redirectUrl)}',
        );
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Google / Facebook / X — same link_token approach as TikTok so
        // Supabase links to the existing account instead of creating a new one.
        final jwt = _sb.auth.currentSession?.accessToken;
        if (jwt == null) {
          if (mounted) setState(() => _linkingProvider = null);
          return;
        }
        String? linkToken;
        try {
          final tokenRes = await http.post(
            Uri.parse(
                '${AppConfig.supabaseUrl}/auth/v1/token'
                '?grant_type=link_identity'),
            headers: {
              'Authorization': 'Bearer $jwt',
              'apikey':        AppConfig.supabaseKey,
              'Content-Type':  'application/json',
            },
          );
          final body = jsonDecode(tokenRes.body) as Map<String, dynamic>;
          linkToken = body['link_token'] as String?;
        } catch (e) {
          debugPrint('link_token fetch error ($provKey): $e');
        }
        String? providerStr;
        switch (provKey) {
          case 'google':   providerStr = 'google';   break;
          case 'facebook': providerStr = 'facebook'; break;
          case 'x':        providerStr = 'twitter';  break;
        }
        if (providerStr == null) {
          if (mounted) setState(() => _linkingProvider = null);
          return;
        }
        final extra = linkToken != null
            ? '&link_token=${Uri.encodeComponent(linkToken)}'
            : '';
        final uri = Uri.parse(
          '${AppConfig.supabaseUrl}/auth/v1/authorize'
          '?provider=$providerStr'
          '$extra'
          '&redirect_to=${Uri.encodeComponent(AppConfig.redirectUrl)}',
        );
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('_connectProvider error ($provKey): $e');
      if (mounted) {
        setState(() => _linkingProvider = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Connection failed: $e'),
          backgroundColor: Colors.red.shade700,
        ));
      }
    }
  }

  /// Removes [provKey] from our DB and clears the local connected state.
  Future<void> _disconnectProvider(String provKey) async {
    try {
      await _sb.rpc('unlink_social_identity', params: {'p_provider': provKey});
      if (mounted) setState(() {
        switch (provKey) {
          case 'google':   _connectedGoogle   = null; break;
          case 'facebook': _connectedFacebook = null; break;
          case 'tiktok':   _connectedTikTok   = null; break;
          case 'x':        _connectedX        = null; break;
        }
      });
    } catch (e) {
      debugPrint('_disconnectProvider error ($provKey): $e');
    }
  }

  Future<void> _loadSports() async {
    try {
      final res = await _sb.rpc('get_sports_list') as List;
      if (!mounted) return;
      setState(() {
        _sports = res.map((e) => {
          'id':      e['id'].toString(),
          'name_en': e['name_en'].toString(),
          'name_ar': e['name_ar']?.toString() ?? e['name_en'].toString(),
        }).toList();
        _loadingSports = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSports = false);
    }
  }

  // ── Username availability check ───────────────────────────────────────────

  void _onUsernameChanged() {
    _usernameDebounce?.cancel();
    final val = _usernameCtrl.text.trim().toLowerCase();
    if (val == widget.username.toLowerCase()) {
      if (mounted) setState(() { _usernameAvailable = null; _checkingUsername = false; });
      return;
    }
    if (val.length < 3) {
      if (mounted) setState(() { _usernameAvailable = null; _checkingUsername = false; });
      return;
    }
    if (mounted) setState(() => _checkingUsername = true);
    _usernameDebounce = Timer(
      const Duration(milliseconds: 600),
      () => _checkUsernameAvailable(val),
    );
  }

  Future<void> _checkUsernameAvailable(String username) async {
    try {
      final res = await _sb.from('user_profile')
          .select('user_id')
          .eq('username', username)
          .maybeSingle();
      if (mounted) setState(() {
        _usernameAvailable = res == null;
        _checkingUsername  = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _usernameAvailable = null;
        _checkingUsername  = false;
      });
    }
  }

  Future<void> _getGps() async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.location_on, color: Color(0xFFFF0000), size: 20),
          const SizedBox(width: 8),
          Text(_s('Enable Location', 'تفعيل الموقع'),
              style: const TextStyle(color: Colors.white,
                  fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: Text(
          _s('Know about new competitions in your area first,\n'
             'and see your ranking across your city and governorate.',
             'اعرف أول بأول عن المسابقات الجديدة في منطقتك،\n'
             'وشوف ترتيبك في مدينتك ومحافظتك.'),
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(_s('Not now', 'مش دلوقتي'),
                  style: const TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(_s('Enable', 'تفعيل'),
                  style: const TextStyle(
                      color: Color(0xFFFF0000), fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (agreed != true || !mounted) return;
    setState(() => _loadingGps = true);
    try {
      // Check if location services are enabled at all
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _loadingGps = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location services are disabled. Please enable GPS.'),
            duration: Duration(seconds: 3),
          ));
        }
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.unableToDetermine)
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
        if (mounted) {
          setState(() => _loadingGps = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location permission denied. Please allow location access.'),
            duration: Duration(seconds: 3),
          ));
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 15)));
      // Save coordinates immediately to Supabase — before Nominatim
      _locationData = {
        'gps': {'lat': pos.latitude, 'lng': pos.longitude},
      };
      try {
        await _sb.rpc('update_my_profile', params: {
          'p_location_data': _locationData,
        });
      } catch (e) {
        debugPrint('GPS coords save error: $e');
      }

      // Try reverse geocoding — if it fails, we still keep the coordinates
      String detCountry = '', detGov = '', detCity = '';
      try {
        final uri = Uri.parse(
            'https://nominatim.openstreetmap.org/reverse'
            '?format=json&lat=${pos.latitude}&lon=${pos.longitude}');
        final resp = await http.get(uri,
            headers: {'User-Agent': 'BDGR-App/1.0'},
        ).timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final addr = (data['address'] as Map<String, dynamic>?) ?? {};
          final rawCountry = addr['country']?.toString() ?? '';
          final rawState   = (addr['state'] ?? addr['county'] ?? '').toString();
          final rawCity    = (addr['city'] ?? addr['town'] ?? addr['village'] ?? '').toString();
          detCountry = _kCountries.firstWhere(
              (c) => c.toLowerCase() == rawCountry.toLowerCase(), orElse: () => '');
          detGov = (_kGovernorates[detCountry] ?? []).firstWhere(
              (g) => rawState.toLowerCase().contains(g.toLowerCase()), orElse: () => '');
          detCity = (_kCities[detGov] ?? []).firstWhere(
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
          // نفس الموقع بيتسجل كموقع متأكد منه (GPS) لترتيب وجوايز المحافظة
          try {
            await _sb.rpc('save_my_gps_location', params: {
              'p_lat': pos.latitude, 'p_lng': pos.longitude, 'p_accuracy': pos.accuracy,
              'p_country': detCountry.isNotEmpty ? detCountry : rawCountry,
              'p_governorate': detGov.isNotEmpty ? detGov : rawState,
              'p_city': detCity.isNotEmpty ? detCity : rawCity,
              'p_district': (addr['suburb'] ?? addr['neighbourhood'] ?? '').toString(),
              'p_street': addr['road']?.toString() ?? '', 'p_postal': addr['postcode']?.toString() ?? '',
              'p_raw': data,
            });
          } catch (e) {
            debugPrint('save_my_gps_location error: $e');
          }
          // Update Supabase with full address details
          try {
            await _sb.rpc('update_my_profile', params: {
              if (detCountry.isNotEmpty) 'p_country':     detCountry,
              if (detGov.isNotEmpty)     'p_governorate': detGov,
              if (detCity.isNotEmpty)    'p_city':        detCity,
              'p_location_data':         _locationData,
            });
          } catch (e) {
            debugPrint('GPS address save error: $e');
          }
        }
      } catch (e) {
        debugPrint('Nominatim error (non-fatal): $e');
      }

      if (!mounted) return;
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
      if (mounted) {
        setState(() => _loadingGps = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not determine location. Please try again.'),
          duration: Duration(seconds: 3),
        ));
      }
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
      // Update username if changed
      final newUsername = _usernameCtrl.text.trim().toLowerCase();
      if (newUsername != widget.username.toLowerCase() && newUsername.length >= 3) {
        try {
          await _sb.rpc('update_username', params: {'p_username': newUsername});
        } catch (e) {
          if (mounted) {
            setState(() => _saving = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(e.toString().contains('USERNAME_TAKEN')
                  ? 'Username already taken. Please choose another.'
                  : 'Failed to update username.'),
              backgroundColor: Colors.red.shade700,
            ));
          }
          return;
        }
      }
      await widget.onSave(
        displayName:    _nameCtrl.text.trim(),
        bio:            _bioCtrl.text.trim(),
        country:        _country     ?? '',
        governorate:    _governorate ?? '',
        city:           _city        ?? '',
        sportIds:       _selectedSportIds,
        locationData:   locData.isNotEmpty ? locData : null,
        birthDate:      _birthDate,
        gender:         _gender,
        primarySportId: _primarySportId,
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
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.88,
      child: Container(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(_s('Edit Profile', 'تعديل البروفايل'), style: const TextStyle(color: Colors.white,
                    fontSize: 17, fontWeight: FontWeight.w800))),
                GestureDetector(
                  onTap: () => setState(() => _isArabic = !_isArabic),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_isArabic ? 'English' : 'عربي',
                          style: const TextStyle(color: Colors.white,
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      const Icon(Icons.language, color: Colors.white70, size: 16),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                // ✕ = اقفل من غير حفظ
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24)),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _label(_s('Display Name', 'الاسم')),
            _textField(_nameCtrl, hint: _s('Your name', 'اسمك'), maxLength: 50),
            const SizedBox(height: 14),
            _label(_s('Username', 'اسم المستخدم')),
            Stack(children: [
              _textField(_usernameCtrl, hint: 'username', maxLength: 20),
              Positioned(right: 12, top: 0, bottom: 0,
                child: Center(child: _checkingUsername
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white38))
                  : _usernameAvailable == null
                      ? const SizedBox.shrink()
                      : Icon(
                          _usernameAvailable! ? Icons.check_circle : Icons.cancel,
                          color: _usernameAvailable! ? Colors.green : Colors.red,
                          size: 18))),
            ]),
            if (_usernameAvailable == false)
              Padding(padding: const EdgeInsets.only(top: 4),
                child: Text(_s('Username already taken', 'اسم المستخدم مأخوذ'),
                    style: const TextStyle(color: Colors.red, fontSize: 11))),
            if (_usernameAvailable == true)
              Padding(padding: const EdgeInsets.only(top: 4),
                child: Text(_s('Available ✓', 'متاح ✓'),
                    style: const TextStyle(color: Colors.green, fontSize: 11))),
            const SizedBox(height: 14),
            _label(_s('Bio', 'نبذة عني')),
            _textField(_bioCtrl, hint: _s('Tell your story...', 'احكي قصتك...'),
                maxLines: 3, maxLength: 150),
            const SizedBox(height: 14),
            // GPS big button — hidden until MVP+
            if (false) Material(color: const Color(0xFFFF0000).withOpacity(0.1),
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
                    Text(_loadingGps
                        ? _s('Detecting location...', 'جاري تحديد الموقع...')
                        : _s('Use my location', 'استخدم موقعي'),
                      style: const TextStyle(color: Color(0xFFFF0000),
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
            // "or set manually" divider — hidden until MVP+
            if (false) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Expanded(child: Divider(color: Color(0xFF2A2A2A))),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(_s('or set manually', 'أو اختر يدوياً'),
                      style: const TextStyle(color: Colors.white38, fontSize: 11))),
                const Expanded(child: Divider(color: Color(0xFF2A2A2A))),
              ]),
            ],
            const SizedBox(height: 10),
            _label(_s('Country', 'الدولة')),
            _dropdown(value: _country, items: _kCountries,
              hint: _s('Select country', 'اختر الدولة'),
              onChanged: (v) => setState(() {
                _country = v; _governorate = null; _city = null;
                _countryManual = true;
                _governorateManual = false; _cityManual = false;
              }),
            ),
            if (_country != null && _govList.isNotEmpty) ...[
              const SizedBox(height: 14),
              _label(_s('Governorate / Region', 'المحافظة / المنطقة')),
              _dropdown(value: _governorate, items: _govList,
                hint: _s('Select governorate', 'اختر المحافظة'),
                onChanged: (v) => setState(() {
                  _governorate = v; _city = null;
                  _governorateManual = true; _cityManual = false;
                }),
              ),
            ],
            if (_governorate != null && _cityList.isNotEmpty) ...[
              const SizedBox(height: 14),
              _label(_s('City', 'المدينة')),
              _dropdown(value: _city, items: _cityList,
                hint: _s('Select city', 'اختر المدينة'),
                onChanged: (v) => setState(() {
                  _city = v; _cityManual = true;
                }),
              ),
            ],
            const SizedBox(height: 14),
            _label(_s('Date of Birth', 'تاريخ الميلاد')),
            Material(color: _kField, borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _birthDate ?? DateTime(2000),
                    firstDate: DateTime(1950),
                    lastDate:  DateTime(DateTime.now().year - 13),
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
                          : _s('Select date of birth', 'اختر تاريخ الميلاد'),
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
            _label(_s('Gender', 'الجنس')),
            Row(children: [
              Expanded(child: _genderBtn('Male',   Icons.male,   label: _s('Male',   'ذكر'))),
              const SizedBox(width: 10),
              Expanded(child: _genderBtn('Female', Icons.female, label: _s('Female', 'أنثى'))),
            ]),
            const SizedBox(height: 14),
            _label(_s('Sports', 'الرياضات')),
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
                            child: Text(_isArabic ? s['name_ar']! : s['name_en']!, style: TextStyle(
                              color: sel ? const Color(0xFFFF0000) : Colors.white70,
                              fontSize: 12,
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                            )),
                          ),
                        ),
                      );
                    }).toList()),

            // Primary Sport selector
            if (_selectedSportIds.isNotEmpty) ...[
              const SizedBox(height: 14),
              _label(_s('PRIMARY SPORT (Your Passion)', 'الرياضة الأساسية (شغفك)')),
              Wrap(spacing: 8, runSpacing: 8,
                children: _sports
                  .where((s) => _selectedSportIds.contains(s['id']))
                  .map((s) {
                    final isPrimary = _primarySportId == s['id'];
                    return Material(
                      color: isPrimary
                          ? const Color(0xFFFF0000)
                          : _kField,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () => setState(() =>
                            _primarySportId = isPrimary ? null : s['id']),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isPrimary
                                ? const Color(0xFFFF0000) : _kBorder),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (isPrimary) ...[
                              const Text('🔥 ', style: TextStyle(fontSize: 11)),
                            ],
                            Text(_isArabic ? s['name_ar']! : s['name_en']!, style: TextStyle(
                              color: isPrimary ? Colors.white : Colors.white70,
                              fontSize: 12,
                              fontWeight: isPrimary
                                  ? FontWeight.w700 : FontWeight.w400,
                            )),
                          ]),
                        ),
                      ),
                    );
                  }).toList()),
            ],

            // ── Primary sport reminder banner ─────────────────────────────
            if (_selectedSportIds.isNotEmpty && _primarySportId == null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFFF0000).withOpacity(0.5)),
                ),
                child: Row(children: [
                  const Text('🔥', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    _s('Pick your main sport above — tap the one you\'re most passionate about',
                       'اختر رياضتك الأساسية — اضغط على اللي بتحبها أكتر'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  )),
                ]),
              ),
            ],

            // Backup Login section — hidden until MVP+
            if (false) ...[
              const SizedBox(height: 20),
              _label(_s('Backup Login', 'تسجيل دخول احتياطي')),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Text(
                  _s('Link Google or Facebook so you can recover your account if you lose access to your phone number.',
                     'اربط Google أو Facebook عشان تقدر تسترجع حسابك لو فقدت رقم موبايلك.'),
                  style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
                ),
              ),
              const SizedBox(height: 10),
              _oauthRow('google',   'Google',   _kGoogleSvg,   _connectedGoogle),
              const SizedBox(height: 8),
              _oauthRow('facebook', 'Facebook', _kFacebookSvg, _connectedFacebook),
            ],

            const SizedBox(height: 16),
            // Save button — disabled until primary sport is chosen
            // (only when sports are selected)
            Builder(builder: (ctx) {
              final blocked = (_selectedSportIds.isNotEmpty &&
                  _primarySportId == null) ||
                  _usernameAvailable == false;
              return Material(
                color: blocked
                    ? Colors.white12
                    : const Color(0xFFFF0000),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: (blocked || _saving) ? null : _save,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(child: _saving
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            blocked ? _s('Select your passion first 🔥', 'اختر شغفك الأول 🔥') : _s('Save', 'حفظ'),
                            style: TextStyle(
                              color: blocked
                                  ? Colors.white38
                                  : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ))),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    ));
  }

  Widget _genderBtn(String val, IconData icon, {String? label}) {
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
            Text(label ?? val, style: TextStyle(
              color: sel ? const Color(0xFFFF0000) : Colors.white70,
              fontSize: 13,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
            )),
          ]),
        ),
      ),
    );
  }

  /// One row in the Connected Accounts section of the edit sheet.
  Widget _oauthRow(
    String provKey,
    String name,
    String svgStr,
    Map<String, dynamic>? data,
  ) {
    final connected = data != null;
    final busy      = _linkingProvider == provKey;
    final subtitle  = connected
        ? (data['email'] as String? ??
           data['name']  as String? ??
           'Connected')
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kField,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: connected
              ? Colors.white.withOpacity(0.18)
              : _kBorder,
        ),
      ),
      child: Row(children: [
        // Brand icon
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: connected
                ? Colors.white.withOpacity(0.12)
                : Colors.white.withOpacity(0.04),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Opacity(
              opacity: connected ? 1.0 : 0.35,
              child: SvgPicture.string(svgStr, width: 16, height: 16),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Name + subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                )),
              if (subtitle != null)
                Text(subtitle,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Action button
        if (connected)
          GestureDetector(
            onTap: _linkingProvider != null ? null
                : () => _disconnectProvider(provKey),
            child: Text(_s('Disconnect', 'فك الربط'),
              style: TextStyle(
                color: _linkingProvider != null
                    ? Colors.white24
                    : const Color(0xFFFF5555),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              )),
          )
        else
          GestureDetector(
            onTap: _linkingProvider != null ? null
                : () => _connectProvider(provKey),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _linkingProvider != null
                      ? Colors.white12
                      : const Color(0xFF1A73E8).withOpacity(0.5),
                ),
              ),
              child: busy
                  ? const SizedBox(width: 12, height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Color(0xFF1A73E8),
                      ))
                  : Text(_s('Connect', 'ربط'),
                      style: TextStyle(
                        color: _linkingProvider != null
                            ? Colors.white24
                            : const Color(0xFF1A73E8),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      )),
            ),
          ),
      ]),
    );
  }

  /// Returns [ar] when Arabic mode is on, [en] otherwise.
  String _s(String en, String ar) => _isArabic ? ar : en;

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

// ── User List Sheet (Followers / Following / Fans) ────────────────────────────

class _UserListSheet extends StatefulWidget {
  const _UserListSheet({
    required this.rpc,
    required this.title,
    required this.type,
    required this.isOwner,
  });
  final String rpc;
  final String title;
  final String type;    // 'following' | 'followers' | 'fans'
  final bool   isOwner;
  @override
  State<_UserListSheet> createState() => _UserListSheetState();
}

class _UserListSheetState extends State<_UserListSheet> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  String get _emptyMessage {
    if (widget.isOwner) {
      switch (widget.type) {
        case 'following': return "You're not following anyone yet";
        case 'followers': return "No one is following you yet";
        case 'fans':      return "No fans yet — keep grinding 🔥";
        default:          return "Nothing here yet";
      }
    } else {
      switch (widget.type) {
        case 'following': return "Not following anyone yet";
        case 'followers': return "Be the first to follow";
        case 'fans':      return "Be the first fan";
        default:          return "Nothing here yet";
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _sb.rpc(widget.rpc);
      if (!mounted) return;
      final list = res as List? ?? [];
      setState(() {
        _users = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('user list error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.75;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(widget.title, style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          const Divider(color: Color(0xFF2A2A2A), height: 1),
          // List
          Flexible(
            child: _loading
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(
                        color: Color(0xFFFF0000), strokeWidth: 2)))
                : _users.isEmpty
                    ? Center(child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(_emptyMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 14))))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _users.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Color(0xFF242424), height: 1,
                                indent: 68),
                        itemBuilder: (_, i) {
                          final u = _users[i];
                          final avatar = u['avatar_url']?.toString();
                          final display = u['display_name']?.toString() ?? '';
                          final username = u['username']?.toString() ?? '';
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 4),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xFF2A2A2A),
                              backgroundImage: avatar != null && avatar.isNotEmpty
                                  ? MediaCache.image(avatar) : null,
                              child: avatar == null || avatar.isEmpty
                                  ? const Icon(Icons.person,
                                      color: Colors.white38, size: 20) : null,
                            ),
                            title: Text(display,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                            subtitle: Text('@$username',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12)),
                          );
                        },
                      ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

// ── Comments Sheet ────────────────────────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({
    required this.momentId,
    required this.isMomentOwner,
    required this.onCountChanged,
  });
  final String            momentId;
  final bool              isMomentOwner;   // صاحب المومنت يقدر يمسح أي كومنت عليه
  final ValueChanged<int> onCountChanged;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _ctrl   = TextEditingController();
  final _focus  = FocusNode();
  List<Map<String, dynamic>> _comments = [];
  bool _loading  = true;
  bool _sending  = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final res = await _sb.rpc('get_comments_v2', params: {
        'p_content_id':   widget.momentId,
        'p_content_type': 'moment',
        'p_limit':        100,
        'p_offset':       0,
      }) as List;
      if (!mounted) return;
      setState(() {
        _comments = res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading  = false;
      });
      widget.onCountChanged(_comments.length);
    } catch (e) {
      debugPrint('get_comments_v2 error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _sb.rpc('add_comment', params: {
        'p_content_id':   widget.momentId,
        'p_content_type': 'moment',
        'p_body':         body,
      });
      _ctrl.clear();
      _focus.unfocus();
      await _loadComments();
    } catch (e) {
      debugPrint('add_comment error: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── 🔥 / 👎 (بنحدث الشاشة على طول، وبعدين ناخد الرقم الصح من السيرفر) ─────
  Future<void> _react(Map<String, dynamic> c, int reaction) async {
    final oldMine  = (c['my_reaction'] as num?)?.toInt() ?? 0;
    final oldLikes = (c['likes_count'] as num?)?.toInt() ?? 0;
    final newMine  = oldMine == reaction ? 0 : reaction;
    var   newLikes = oldLikes;
    if (oldMine == 1) newLikes--;
    if (newMine == 1) newLikes++;
    setState(() {
      c['my_reaction'] = newMine;
      c['likes_count'] = newLikes < 0 ? 0 : newLikes;
    });
    try {
      final res = await _sb.rpc('react_comment', params: {
        'p_comment_id': c['id'].toString(),
        'p_reaction':   reaction,
      });
      final row = res is List && res.isNotEmpty ? res.first as Map : null;
      if (row != null && mounted) {
        setState(() {
          c['likes_count'] = (row['likes_count'] as num?)?.toInt() ?? c['likes_count'];
          c['my_reaction'] = (row['my_reaction'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (e) {
      debugPrint('react_comment error: $e');
      if (mounted) setState(() { c['my_reaction'] = oldMine; c['likes_count'] = oldLikes; });
    }
  }

  // ── ضغطة طويلة: ريبورت أو مسح ───────────────────────────────────────────
  void _openCommentMenu(Map<String, dynamic> c) {
    final mine      = c['is_mine'] == true;
    final canDelete = mine || widget.isMomentOwner;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (canDelete)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFFF5C5C)),
              title: Text(AppLang.t('Delete', 'مسح'), style: const TextStyle(color: Color(0xFFFF5C5C))),
              onTap: () { Navigator.pop(ctx); _deleteComment(c); },
            ),
          if (!mine)
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.white70),
              title: Text(AppLang.t('Report', 'إبلاغ'), style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => _ReportSheet(
                    contentId:   c['id'].toString(),
                    contentType: 'comment',
                  ),
                );
              },
            ),
        ]),
      ),
    );
  }

  Future<void> _deleteComment(Map<String, dynamic> c) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(AppLang.t('Delete comment?', 'تمسح التعليق ده؟'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false),
              child: Text(AppLang.t('Cancel', 'إلغاء'), style: const TextStyle(color: Colors.white70))),
          TextButton(onPressed: () => Navigator.pop(d, true),
              child: Text(AppLang.t('Delete', 'امسح'), style: const TextStyle(
                  color: Color(0xFFFF5C5C), fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await _sb.rpc('remove_comment', params: {'p_comment_id': c['id'].toString()});
      await _loadComments();
    } catch (e) {
      debugPrint('remove_comment error: $e');
    }
  }

  String _ago(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    if (d == null) return '';
    final s = DateTime.now().difference(d.toLocal());
    if (s.inMinutes < 1)  return 'now';
    if (s.inHours   < 1)  return '${s.inMinutes}m';
    if (s.inDays    < 1)  return '${s.inHours}h';
    if (s.inDays    < 7)  return '${s.inDays}d';
    if (s.inDays    < 365) return '${s.inDays ~/ 7}w';
    return '${s.inDays ~/ 365}y';
  }

  String _short(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
    return '$n';
  }

  Widget _commentTile(Map<String, dynamic> c) {
    final name   = (c['display_name']?.toString().trim().isNotEmpty == true)
        ? c['display_name'].toString() : (c['username']?.toString() ?? 'User');
    final avatar = c['avatar_url']?.toString();
    final likes  = (c['likes_count'] as num?)?.toInt() ?? 0;
    final mine   = (c['my_reaction'] as num?)?.toInt() ?? 0;

    return InkWell(
      onLongPress: () => _openCommentMenu(c),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: const Color(0xFF2A2A2A),
            backgroundImage: (avatar != null && avatar.isNotEmpty) ? MediaCache.image(avatar) : null,
            child: (avatar == null || avatar.isEmpty)
                ? const Icon(Icons.person, size: 18, color: Colors.white38) : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(
                color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(c['body']?.toString() ?? '', style: const TextStyle(
                color: Colors.white, fontSize: 14.5, height: 1.35)),
            const SizedBox(height: 6),
            Row(children: [
              Text(_ago(c['created_at']), style: const TextStyle(
                  color: Colors.white38, fontSize: 12)),
              const Spacer(),
              // 🔥 لايك بعدد
              InkWell(
                onTap: () => _react(c, 1),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(children: [
                    Icon(mine == 1 ? Icons.local_fire_department
                                   : Icons.local_fire_department_outlined,
                        size: 19, color: mine == 1 ? Brand.green : Colors.white54),
                    if (likes > 0) ...[
                      const SizedBox(width: 4),
                      Text(_short(likes), style: TextStyle(
                          color: mine == 1 ? Brand.green : Colors.white54,
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ],
                  ]),
                ),
              ),
              const SizedBox(width: 6),
              // 👎 من غير عدد
              InkWell(
                onTap: () => _react(c, -1),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Icon(mine == -1 ? Icons.thumb_down : Icons.thumb_down_outlined,
                      size: 17, color: mine == -1 ? Colors.white : Colors.white54),
                ),
              ),
            ]),
          ])),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media  = MediaQuery.of(context);
    final bottom = media.padding.bottom;
    final kbH    = media.viewInsets.bottom;
    final n      = _comments.length;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF151518),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottom + kbH),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
        // العدد فوق في النص + X
        SizedBox(
          height: 46,
          child: Stack(alignment: Alignment.center, children: [
            Text(
              _loading ? AppLang.t('Comments', 'التعليقات')
                  : AppLang.t(n == 1 ? '1 comment' : '${_short(n)} comments',
                              '${_short(n)} تعليق'),
              style: const TextStyle(color: Colors.white, fontSize: 15.5,
                  fontWeight: FontWeight.w800),
            ),
            Positioned(right: 4, child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 22),
              onPressed: () => Navigator.pop(context),
            )),
          ]),
        ),
        const Divider(color: Colors.white10, height: 1),
        SizedBox(
          height: (media.size.height * 0.55).clamp(260.0, 520.0),
          child: _loading
              ? const Center(child: CircularProgressIndicator(
                  color: Brand.green, strokeWidth: 2))
              : n == 0
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.mode_comment_outlined, color: Colors.white24, size: 40),
                      const SizedBox(height: 10),
                      Text(AppLang.t('No comments yet. Be the first!', 'مفيش تعليقات لسه. خليك أول واحد!'),
                          style: const TextStyle(color: Colors.white38, fontSize: 13.5)),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: n,
                      itemBuilder: (_, i) => _commentTile(_comments[i]),
                    ),
        ),
        const Divider(color: Colors.white10, height: 1),
        // كتابة كومنت
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF26262B),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  maxLength:  500,
                  maxLines:   3,
                  minLines:   1,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: AppLang.t('Add a comment…', 'اكتب تعليق…'),
                    hintStyle: const TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    counterText: '',
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 42, height: 42,
                decoration: const BoxDecoration(
                  color: Brand.green,
                  shape: BoxShape.circle,
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2))
                    : const Icon(Icons.arrow_upward_rounded,
                        color: Colors.black, size: 22),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Report Sheet ──────────────────────────────────────────────────────────────

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.contentId,
    required this.contentType,
  });
  final String contentId;
  final String contentType;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _selected;
  bool    _sending  = false;
  bool    _done     = false;

  static const _reasons = [
    ('nudity',       '🔞', 'Nudity or sexual content|عُري أو محتوى جنسي'),
    ('violence',     '⚠️', 'Violence or harmful content|عنف أو محتوى مؤذي'),
    ('harassment',   '💬', 'Harassment or bullying|تحرش أو تنمّر'),
    ('spam',         '🚫', 'Spam or misleading|سبام أو محتوى مضلل'),
    ('child_safety', '👶', 'Child safety|سلامة الأطفال'),
    ('other',        '📋', 'Other|حاجة تانية'),
  ];

  Future<void> _submit() async {
    if (_selected == null || _sending) return;
    setState(() => _sending = true);
    try {
      await _sb.rpc('report_content', params: {
        'p_content_id':   widget.contentId,
        'p_content_type': widget.contentType,
        'p_reason':       _selected,
      });
      if (mounted) setState(() => _done = true);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('report_content error: $e');
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),

        if (_done) ...[
          const SizedBox(height: 20),
          const Icon(Icons.check_circle_outline,
              color: Color(0xFFFF0000), size: 48),
          const SizedBox(height: 12),
          Text(AppLang.t('Report submitted', 'البلاغ اتبعت'),
              style: const TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(AppLang.t("We'll review this content shortly.", 'هنراجع المحتوى ده قريب.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 20),
        ] else ...[
          Text(AppLang.t('Report Content', 'إبلاغ عن محتوى'),
              style: const TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(AppLang.t('Why are you reporting this?', 'ليه بتبلّغ عن ده؟'),
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 16),
          // Reasons list
          ...(_reasons.map((r) {
            final (key, emoji, label) = r;
            final isSelected = _selected == key;
            return GestureDetector(
              onTap: () => setState(() => _selected = key),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFFF0000).withOpacity(0.12)
                      : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFF0000)
                        : Colors.white12,
                  ),
                ),
                child: Row(children: [
                  Text(emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(AppLang.t(label.split('|').first, label.split('|').last),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w700 : FontWeight.w400,
                      ))),
                  if (isSelected)
                    const Icon(Icons.check_circle,
                        color: Color(0xFFFF0000), size: 18),
                ]),
              ),
            );
          })),
          const SizedBox(height: 8),
          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selected == null ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF0000),
                disabledBackgroundColor: Colors.white12,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _sending
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(AppLang.t('Submit Report', 'ابعت البلاغ'),
                      style: const TextStyle(fontWeight: FontWeight.w700,
                          fontSize: 15)),
            ),
          ),
        ],
      ]),
    );
  }
}
