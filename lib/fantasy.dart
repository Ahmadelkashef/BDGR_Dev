import 'dart:async';
import 'package:mobile_app/motion_kit.dart';
import 'media_cache.dart';
import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageByteFormat;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ads/ad_widgets.dart';
import 'ads/ad_takeover.dart' show showAdModal, onAdBannerTap;
import 'app_lang.dart';
import 'brand.dart';
import 'local_store.dart';
import 'location_prompt.dart';
import 'web/web_layout.dart' show WebStage;
import 'profile/visitor_profile_sheet.dart';
import 'profile/complete_profile.dart' show maybePromptCompleteProfile;
import 'profile/level_looks.dart' show maybeLevelUpAfterSave;
import 'profile/first_achievement.dart' show maybeFirstAchievement;
import 'home/home_page.dart' show HomeActions;
import 'fantasy_stadium.dart';
import 'fantasy_motion.dart';
import 'diag.dart';
import 'safe_svg.dart';
import 'team_initials_crest.dart';
import 'social/comments_sheet.dart' show showCommentsSheet;

part 'fantasy_rank.dart';
part 'fantasy_leagues.dart';
part 'fantasy_highlights.dart';
part 'fantasy_players.dart';
part 'fantasy_mystats.dart';
part 'fantasy_matches.dart';
part 'fantasy_builder_v2.dart';
part 'fantasy_social.dart';
part 'fantasy_cup.dart';
part 'fantasy_launch.dart';
part 'fantasy_bleague.dart';
part 'fantasy_recap.dart';
part 'fantasy_bench.dart';

// ─── Supabase client shortcut ─────────────────────────────────────────────
SupabaseClient get _sb => Supabase.instance.client;

/// الفانتازي شغالة بـ auth uuid، والبروفايل شغال بـ user_id الرقمي.
/// بنحوّل الـ uuid للرقم (get_user_id_by_auth) وبعدين نفتح البروفايل كزائر.
Future<void> _openVisitorProfile(
  BuildContext context, {
  required String userId,
  required String username,
  required String displayName,
  String? avatarUrl,
}) async {
  int? numericId = int.tryParse(userId);
  if (numericId == null) {
    try {
      final id = await _sb.rpc('get_user_id_by_auth', params: {'p_auth_user_id': userId});
      numericId = (id as num?)?.toInt();
    } catch (e) {
      debugPrint('resolve profile id error: $e');
    }
  }
  if (!context.mounted) return;
  if (numericId == null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLang.t('Profile unavailable right now', 'البروفايل مش متاح دلوقتي'))));
    return;
  }
  // نفس شاشة الزائر اللي في كل التطبيق: الصورة الكبيرة + Follow + See profile
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => VisitorProfileSheet(userId: numericId!),
  ));
}

// ─── Value formatter (player price: 5M, 5.5M — no .0) ────────────────────
String _fmtVal(double val) {
  if (val == val.roundToDouble()) return '${val.round()}M';
  return '${val.toStringAsFixed(1)}M';
}

// ─── Budget formatter ─────────────────────────────────────────────────────
String _fmtBudget(double val) {
  final n = val.round();
  if (n >= 1000) {
    final b = (n / 1000.0);
    final bStr = b == b.roundToDouble() ? b.round().toString() : b.toStringAsFixed(1);
    return '${n}M (${bStr}B)';
  }
  return '${n}M';
}

// ─── Smart image widget (SVG / JPG / PNG / any) ───────────────────────────
Widget _netImage(String url, {double? width, double? height, BoxFit fit = BoxFit.cover, Widget? fallback}) {
  final isSvg = url.toLowerCase().contains('.svg');
  if (isSvg) {
    // safe: gradients without colours (Man United crest) crashed the engine, see safe_svg.dart
    return SafeSvgNet(url, width: width, height: height, fit: fit,
      placeholder: fallback ?? const SizedBox.shrink());
  }
  return Image(image: MediaCache.image(url), width: width, height: height, fit: fit,
    loadingBuilder: (_, child, progress) =>
      progress == null ? child : (fallback ?? const SizedBox.shrink()),
    errorBuilder: (_, __, ___) => fallback ?? const SizedBox.shrink());
}

/// Shirt photo on the pitch: decoded SMALL (a big photo decoded at full size ×11 cards = out of memory → crash).
Widget _kitPhoto(String url, double w, double h, Widget fallback) {
  final px = (w * 3).round().clamp(96, 240).toInt();
  return Image(image: ResizeImage(MediaCache.image(url), width: px, allowUpscaling: false),
    width: w, height: h, fit: BoxFit.contain, gaplessPlayback: true,
    loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
    errorBuilder: (_, __, ___) => fallback);
}

/// Player photo in the player dialogs. No photo (or it fails) → the team shirt
/// (shirt photo, else the drawn shirt), like on the pitch (owner, 24 Nov). Never a big grey person icon.
Widget _playerShirtHero(FancyPlayer p, {double shirtW = 120, Color bg = const Color(0xFF1B1B20)}) {
  final kit = _FancyPageState._kits[p.teamId];
  final drawn = KitShirt(c1: kit?.c1 ?? const Color(0xFF8A8F98), c2: kit?.c2 ?? Colors.white,
      pattern: kit?.pattern ?? 'plain', width: shirtW);
  return Container(color: bg, alignment: Alignment.center,
    child: kit?.img != null ? _kitPhoto(kit!.img!, shirtW * 1.25, shirtW * 1.25, drawn) : drawn);
}

/// Team crest on the pitch cards (same safe SVG path as everywhere: safe_svg.dart).
class _SafeCrest extends StatelessWidget {
  final String url;
  final double size;
  const _SafeCrest(this.url, {required this.size});
  @override
  Widget build(BuildContext context) =>
      _netImage(url, width: size, height: size, fit: BoxFit.contain, fallback: const SizedBox.shrink());
}

// ─── Colors ───────────────────────────────────────────────────────────────
const Color bg           = Brand.background;   // هوية BDGR
const Color cardBg       = Color(0xFF1A1A1A);
const Color brandRed     = Color(0xFFFF1A1A);
const Color surface2     = Color(0xFF2A2A2A);
const Color mint         = Color(0xFFFFFFFF);
const Color sage         = brandRed;
const Color muted        = Color(0xFF9A9A9A);
const Color line         = Color(0xFF2C2C2C);
const Color captainColor = Color(0xFFFFD54F);

// ─── Models ───────────────────────────────────────────────────────────────

class FantasyMatch {
  final String   matchId;
  final DateTime kickoffAt;
  final String   homeTeamId, homeNameEn, homeNameAr;
  final String?  homeLogoUrl;
  final String   awayTeamId, awayNameEn, awayNameAr;
  final String?  awayLogoUrl;
  final bool     finished;          // النتيجة اتدخلت من الداشبورد
  final int?     homeScore, awayScore;

  FantasyMatch({
    required this.matchId, required this.kickoffAt,
    required this.homeTeamId, required this.homeNameEn, required this.homeNameAr,
    this.homeLogoUrl,
    required this.awayTeamId, required this.awayNameEn, required this.awayNameAr,
    this.awayLogoUrl,
    this.finished = false, this.homeScore, this.awayScore,
  });

  factory FantasyMatch.fromJson(Map<String, dynamic> j) => FantasyMatch(
    matchId:     j['match_id'] as String,
    kickoffAt:   DateTime.parse(j['kickoff_at'] as String).toLocal(),
    homeTeamId:  (j['home'] as Map)['team_id'] as String,
    homeNameEn:  (j['home'] as Map)['name_en'] as String,
    homeNameAr:  (j['home'] as Map)['name_ar'] as String,
    homeLogoUrl: (j['home'] as Map)['logo_url'] as String?,
    awayTeamId:  (j['away'] as Map)['team_id'] as String,
    awayNameEn:  (j['away'] as Map)['name_en'] as String,
    awayNameAr:  (j['away'] as Map)['name_ar'] as String,
    awayLogoUrl: (j['away'] as Map)['logo_url'] as String?,
    finished:    j['finished'] == true,
    homeScore:   (j['home_score'] as num?)?.toInt(),
    awayScore:   (j['away_score'] as num?)?.toInt(),
  );
}

class FantasyPrize {
  final int rank;
  final String labelAr, labelEn, prizeAr, prizeEn;
  /// أيقونة نوع الجايزة (💵 كاش، 👕 ميرش، 🎁 فاوتشر…) من `prize_categories` — ممكن تبقى null
  final String? icon;
  const FantasyPrize({required this.rank, required this.labelAr, required this.labelEn,
      required this.prizeAr, required this.prizeEn, this.icon});
  factory FantasyPrize.fromJson(Map<String, dynamic> j) => FantasyPrize(
    rank:    (j['rank'] as num?)?.toInt() ?? 0,
    labelAr: '${j['label_ar'] ?? ''}', labelEn: '${j['label_en'] ?? j['label_ar'] ?? ''}',
    prizeAr: '${j['prize_ar'] ?? ''}', prizeEn: '${j['prize_en'] ?? j['prize_ar'] ?? ''}',
    icon:    prizeIconOf(j),
  );
  /// النص مع أيقونة النوع قبله: "💵 1000 جنيه"
  String text(bool ar) => withPrizeIcon(icon, ar ? prizeAr : prizeEn);
}

/// أيقونة نوع الجايزة من JSON السيرفر (`x.icon`)، أو null
String? prizeIconOf(Map j) {
  final x = j['x'];
  final i = x is Map ? x['icon'] : null;
  return (i is String && i.trim().isNotEmpty) ? i.trim() : null;
}

String withPrizeIcon(String? icon, String text) => icon == null ? text : '$icon $text';

class FantasyEvent {
  final String        eventId, eventCode, nameAr, nameEn, status;
  /// open / live / finished — بيتحسب في السيرفر (نفس الساعة عند كل الناس)
  final String        phase;
  final List<FantasyPrize> prizes;
  final DateTime      deadlineAt, startAt;
  final double        playerBudget;
  final List<FantasyMatch> matches;
  final List<String>  teamPool;
  final String?       fantasyType;
  /// أقصى عدد لاعيبة من نفس الفريق (null = من غير حد)
  final int?          maxPerTeam;
  /// the draft (a SECOND squad: 7 spots, no captain, "surprise" × surpriseMult) is open in this round
  final bool          draftOn;
  final int           draftMaxPerTeam;
  final double        surpriseMult;
  /// draft size of this round (4..7, default 7) + its shape [(key, pitch group, how many)] from the server
  final int           draftSize;
  final List<(String, String, int)> draftShape;
  /// WORLD bench (owner 26 Nov): optional GK sub + up to 3 outfield subs (one DEF, one MID, one ATT), in order
  final bool          draftSubs;
  /// draft tie-break: the matches whose score users predict (chosen in the dashboard, max 2)
  final List<String>  draftPredict;

  FantasyEvent({
    required this.eventId, required this.eventCode,
    required this.nameAr, required this.nameEn, required this.status,
    this.phase = 'open', this.prizes = const [],
    required this.deadlineAt, required this.startAt,
    required this.playerBudget, required this.matches, required this.teamPool,
    this.fantasyType, this.maxPerTeam, this.draftOn = false, this.draftMaxPerTeam = 4, this.surpriseMult = 2, this.draftPredict = const [], this.draftSize = 7, this.draftShape = const [], this.draftSubs = false,
  });

  factory FantasyEvent.fromJson(Map<String, dynamic> j) {
    final rawMatches = (j['matches'] as List?) ?? [];
    final rawPool    = (j['team_pool'] as List?) ?? [];
    return FantasyEvent(
      eventId:      j['event_id'] as String,
      eventCode:    j['event_code'] as String,
      nameAr:       j['name_ar'] as String,
      nameEn:       j['name_en'] as String,
      status:       j['status'] as String,
      phase:        (j['phase'] as String?) ?? 'open',
      prizes:       ((j['prizes'] as List?) ?? [])
                      .map((e) => FantasyPrize.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      deadlineAt:   DateTime.parse(j['deadline_at'] as String).toLocal(),
      startAt:      DateTime.parse(j['start_at'] as String).toLocal(),
      playerBudget: ((j['player_budget'] ?? 100) as num).toDouble(),
      matches:      rawMatches.map((m) => FantasyMatch.fromJson(m as Map<String, dynamic>)).toList()
                              ..sort((a, b) => a.kickoffAt.compareTo(b.kickoffAt)),
      teamPool:     rawPool.map((e) => e.toString()).toList(),
      fantasyType:  j['fantasy_type'] as String?,
      maxPerTeam:   (j['max_per_team'] as num?)?.toInt(),
      draftOn:      j['draft_on'] == true,
      draftMaxPerTeam: (j['draft_max_per_team'] as num?)?.toInt() ?? 4,
      surpriseMult: ((j['surprise_mult'] ?? 2) as num).toDouble(),
      draftPredict: ((j['draft_predict'] as List?) ?? []).map((e) => e.toString()).toList(),
      draftSize:    (j['draft_size'] as num?)?.toInt() ?? 7,
      draftSubs:    j['draft_subs'] == true,
      draftShape:   [for (final x in (j['draft_shape'] as List?) ?? const [])
                      ('${(x as Map)['key']}', '${x['grp']}', (x['n'] as num?)?.toInt() ?? 1)],
    );
  }
}

class _Kit {
  final Color c1, c2;
  final String pattern;
  final String? img; // optional real shirt photo (outside https link); the drawn shirt is the fallback
  const _Kit(this.c1, this.c2, this.pattern, [this.img]);
  static Color? _hex(dynamic v) {
    final m = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch('${v ?? ''}');
    return m == null ? null : Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
  }
  static _Kit? fromJson(dynamic j) {
    if (j is! Map) return null;
    final a = _hex(j['c1']), b = _hex(j['c2']);
    if (a == null || b == null) return null;
    final img = '${j['img'] ?? ''}';
    return _Kit(a, b, '${j['p'] ?? 'plain'}', img.startsWith('https://') ? img : null);
  }
}

class FancyPlayer {
  final String  id, nameEn, nameAr, position, teamNameEn, teamNameAr;
  final double  price;
  final String? photoUrl;      // headshot → في القوايم والملعب
  final String? fullImageUrl;  // full body → في الموديل لوحده
  final num?    ownership;
  final String? teamId;
  final num     lastPts, totalPts;
  final int     played;
  final double? marketValue;   // € (player_seasons.market_value_euro), null = unknown
  final String? exactPos;      // Transfermarkt position: GK CB LB RB DM CM AM LM RM LW RW SS CF
  final String? imageUrl;      // full image only (no headshot fallback) → v2 card picture
  final bool    surprise;      // draft rounds: "surprise" player → points × the event's surpriseMult
  final num?    draftPct;      // % of draft squads that picked him (shown after the deadline)

  FancyPlayer({
    required this.id, required this.nameEn, required this.nameAr,
    required this.position, required this.teamNameEn, required this.teamNameAr,
    required this.price, this.photoUrl, this.fullImageUrl, this.ownership,
    this.teamId, this.lastPts = 0, this.totalPts = 0, this.played = 0,
    this.marketValue, this.exactPos, this.imageUrl, this.surprise = false, this.draftPct,
  });

  /// نقط لكل مليون (أحسن قيمة)
  double get value => price > 0 ? totalPts / price : 0;

  /// نفس اللاعب بسعر تاني (سعر الشرا في تشكيلة محفوظة)
  FancyPlayer withPrice(double p) => FancyPlayer(
    id: id, nameEn: nameEn, nameAr: nameAr, position: position, teamNameEn: teamNameEn, teamNameAr: teamNameAr,
    price: p, photoUrl: photoUrl, fullImageUrl: fullImageUrl, ownership: ownership,
    teamId: teamId, lastPts: lastPts, totalPts: totalPts, played: played,
    marketValue: marketValue, exactPos: exactPos, imageUrl: imageUrl, surprise: surprise, draftPct: draftPct);

  factory FancyPlayer.fromJson(Map<String, dynamic> j) => FancyPlayer(
    id:           j['player_id'] as String,
    nameEn:       j['name_en'] as String,
    nameAr:       j['name_ar'] as String,
    position:     j['position'] as String,
    teamNameEn:   j['team_name_en'] as String,
    teamNameAr:   j['team_name_ar'] as String,
    price:        ((j['fantasy_price'] ?? 5) as num).toDouble(),
    photoUrl:     j['headshot_url'] as String? ?? j['photo_url'] as String?,
    fullImageUrl: j['full_image_url'] as String? ?? j['photo_url'] as String?,
    ownership:    j['ownership_pct'] as num?,
    teamId:       j['team_id'] as String?,
    lastPts:      (j['last_pts'] as num?) ?? 0,
    totalPts:     (j['total_pts'] as num?) ?? 0,
    played:       (j['played'] as num?)?.toInt() ?? 0,
    marketValue:  (j['market_value_euro'] as num?)?.toDouble(),
    exactPos:     j['exact_position'] as String?,
    imageUrl:     j['image_url'] as String?,
    surprise:     false,   // launch: no ⭐/🎲 (owner, 26 Nov)
    draftPct:     j['draft_pct'] as num?,
  );
}

class TourCard {
  final int screen;
  final String titleEn, titleAr;
  final List<String> linesEn, linesAr;
  const TourCard({required this.screen, required this.titleEn, required this.titleAr,
    required this.linesEn, required this.linesAr});
}

// ─── App wrapper (standalone) ─────────────────────────────────────────────
// When imported into MainShell, only FancyPage is used.

class FancyDartApp extends StatelessWidget {
  const FancyDartApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: bg,
      fontFamily: 'Roboto', useMaterial3: true,
      colorScheme: const ColorScheme.dark(primary: sage, surface: bg)),
    home: const FancyPage(),
  );
}

// ─── Main Page ─────────────────────────────────────────────────────────────

class FancyPage extends StatefulWidget {
  final bool isArabicOverride;
  final VoidCallback? onLanguageToggle;
  final bool showTopButtons;
  /// بيتنادى لما اليوزر يدخل أرينا (true) أو يرجع لاختيار الأرينا (false)
  final ValueChanged<bool>? onInArena;
  const FancyPage({super.key, this.isArabicOverride = false, this.onLanguageToggle, this.showTopButtons = true, this.onInArena});
  @override
  State<FancyPage> createState() => _FancyPageState();
}

class _FancyPageState extends State<FancyPage> {

  // ── Navigation ──────────────────────────────────────────────────────────
  int    step          = 0;   // 0=arena 1=lobby 2=squad
  String arena         = 'EGYPT';
  bool   isArabic      = false;
  bool   tourActive    = false;   // الجولة الطويلة اتلغت: النصايح بقت خفيفة ووقت ما تلزم
  @override void didUpdateWidget(FancyPage old) {
    super.didUpdateWidget(old);
    if (widget.isArabicOverride != isArabic) setState(() => isArabic = widget.isArabicOverride);
  }
  int    tourIndex     = 0;
  // نصيحة الملعب: بتظهر أول مرة بس، وبتختفي لما يختار أول لاعب أو يقفلها
  bool   _showPitchTip = false;
  // صباع بيشاور على "؟" وزرار اللغة: أول مرة بس، ومش بيقفل الصفحة
  bool   _showHelpHint = false;
  void _dismissHelpHint() {
    if (!_showHelpHint) return;
    setState(() => _showHelpHint = false);
    LocalStore.setFlag('fantasy_help_hint');
  }

  Widget _helpHint() => Positioned(
    top: 52, right: 12,
    child: GestureDetector(
      onTap: _dismissHelpHint,
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Padding(
          padding: EdgeInsets.only(right: 22),
          child: Icon(Icons.north, color: Brand.green, size: 22),
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 230),
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: const Color(0xF2141418),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x8800FF87)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(
              t('New here? Tap ? to see how it works — and switch the language from here.',
                'أول مرة؟ دوس ؟ عشان تعرف إزاي بتلعب، وغيّر اللغة من هنا.'),
              style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.35))),
            const SizedBox(width: 4),
            const Icon(Icons.close, color: Colors.white54, size: 16),
          ]),
        ),
      ]),
    ),
  );
  void _dismissPitchTip() {
    if (!_showPitchTip) return;
    setState(() => _showPitchTip = false);
    LocalStore.setFlag('fantasy_pitch_tip');
  }
  String expandedArena = 'EGYPT';

  // ── حركة اللوبي: مصر ↔ العالم بيتبادلوا لوحدهم ─────────────────────────────
  // للرجوع للشكل القديم: خلّي السويتش ده false (أو رجّع الـ commit بتاع الحركة دي)
  static const bool arenaAutoSwap = true;
  static const Duration _swapEvery = Duration(seconds: 4);
  static const int _swapMax = 6;              // 3 لفّات وبعدين تقف وترجع لمصر
  Timer? _swapTimer;
  int _swapCount = 0;
  bool _swapStopped = false;                  // أول لمسة من اليوزر = تقف خالص

  void _ensureAutoSwap() {
    if (!arenaAutoSwap || _swapStopped || _swapTimer != null) return;
    if (_localEvent == null || _worldEvent == null) return;
    _swapTimer = Timer.periodic(_swapEvery, (_) {
      if (!mounted || step != 0 || _swapStopped || _swapCount >= _swapMax) { _stopAutoSwap(); return; }
      setState(() { expandedArena = expandedArena == 'EGYPT' ? 'WORLD' : 'EGYPT'; _swapCount++; });
    });
  }

  void _stopAutoSwap() {
    _swapStopped = true;
    _swapTimer?.cancel();
    _swapTimer = null;
  }

  // ── Data ────────────────────────────────────────────────────────────────
  bool          _lobbyLoading   = true;
  String?       _lobbyError;
  FantasyEvent? _localEvent;
  FantasyEvent? _worldEvent;

  bool              _playersLoading = false;
  String?           _playersError;
  List<FancyPlayer> players         = [];

  // ── Squad ────────────────────────────────────────────────────────────────
  String formation = '4-3-3';
  static const List<String> formations = ['4-4-2','5-3-2','4-3-3','5-4-1','3-5-2','3-4-3','4-5-1'];

  final Map<String, List<FancyPlayer?>> squad = {
    'GK': List.filled(1, null), 'DEF': List.filled(5, null),
    'MID': List.filled(5, null), 'FWD': List.filled(3, null),
  };
  FancyPlayer? captain;
  // ── v2 step-by-step builder (branch fantasy-v2, fantasy_builder_v2.dart) ──
  int _gStage = -1;                          // -1 start · 0 formation · 1 picking (an empty team only; else worked out)
  final Map<String, GlobalKey> _slotKeys = {}; // 'DEF_2' → the slot on the pitch (flight target)
  final Set<String> _flown = {};             // players that flew in (no extra drop-in on the slot)
  String? _landedId;                         // last player that landed (landing ring)
  bool _flying = false;
  bool _draftView = false;                   // showing / building the DRAFT squad (second squad) of this round
  // draft "duel" picker: holder vs rival, the winner stays (fantasy_builder_v2.dart)
  String? _duelKey;
  List<FancyPlayer> _duelQueue = [];
  FancyPlayer? _duelHold, _duelRival;
  bool _duelHoldLeft = true, _duelPicked = false;   // the kept card stays on its side; picked = the user tapped one
  // WORLD bench: GK sub + outfield subs in order 1..3 (fantasy_bench.dart)
  FancyPlayer? _benchGk;
  final List<FancyPlayer?> _benchOut = [null, null, null];
  int _duelTotal = 0;
  final List<List<Object?>> _duelHist = [];
  /// draft score predictions (tie-break only): match id → [home, away] (null = not picked yet)
  final Map<String, List<int?>> _preds = {};
  List<FantasyMatch> get _predMatches {
    final ev = currentEvent;
    if (ev == null) return const [];
    return [for (final id in ev.draftPredict) ...ev.matches.where((m) => m.matchId == id)];
  }
  bool get _predsDone => _predMatches.every((m) { final v = _preds[m.matchId]; return v != null && v[0] != null && v[1] != null; });
  List<Map<String, dynamic>> get _predsPayload => [for (final m in _predMatches)
    {'match_id': m.matchId, 'home': _preds[m.matchId]![0], 'away': _preds[m.matchId]![1]}];  // undo: [hold, rival, queue] before each tap
  BuildContext? _duelHoldCtx;               // the holder card (flight start)
  String _layout = '4-3-3';                  // v2 midfield layout: 4-1-4-1 | 4-2-3-1 | 4-3-3 (server formation stays 4-5-1)
  void _v2Set(VoidCallback f) => setState(f);
  bool saved     = false;
  bool _hasSquad = false, _squadChecked = false;   // launch lobby: does he have a saved draft squad in this round
  bool _saving   = false;
  String? _saveError;

  // ── Countdown ────────────────────────────────────────────────────────────
  Timer?   _countdownTimer;
  Duration _timeLeft = Duration.zero;

  // ── Computed ─────────────────────────────────────────────────────────────
  FantasyEvent? get currentEvent => arena == 'EGYPT' ? _localEvent : _worldEvent;
  double get initialBudget => currentEvent?.playerBudget ?? 100.0;

  static const List<String> posOrder = ['GK','DEF','MID','FWD'];

  List<int> get fmtCounts => formation.split('-').map(int.parse).toList();
  int slotCount(String pos) {
    final c = fmtCounts;
    switch (pos) {
      case 'GK': return 1;
      case 'DEF': return c[0];
      case 'MID': return c[1];
      default: return c[2];
    }
  }

  List<FancyPlayer> get pickedPlayers {
    final res = <FancyPlayer>[];
    for (final pos in posOrder) {
      for (var i = 0; i < slotCount(pos); i++) {
        final p = squad[pos]![i];
        if (p != null) res.add(p);
      }
    }
    return res;
  }

  int    get selectedCount => pickedPlayers.length;
  double get spent         => pickedPlayers.fold(0.0, (s, p) => s + p.price);
  double get remaining     => initialBudget - spent;
  bool   get deadlinePassed => _timeLeft == Duration.zero;

  /// حالة الجولة اللي اليوزر بيشوفها: open / live / finished
  String phaseOf(FantasyEvent? ev) {
    if (ev == null) return 'none';
    if (ev.phase == 'open' && !ev.deadlineAt.isAfter(DateTime.now())) return 'live';
    return ev.phase;
  }

  // ترتيبي في الجولة (لما تخلص)
  Map<String, dynamic>? _myRank;
  Future<void> _loadMyRank(String eventId) async {
    try {
      final r = await _sb.rpc(isDraft ? 'get_my_draft_rank' : 'get_my_event_rank', params: {'p_event_id': eventId});
      if (mounted) setState(() => _myRank = r is Map ? Map<String, dynamic>.from(r) : null);
    } catch (_) {}
  }
  bool   get canSave => selectedCount == 11 && remaining >= 0 && !deadlinePassed && captain != null;
  bool   get canSaveV2 => selectedCount == squadSize && !deadlinePassed && (isDraft || captain != null); // v2: no budget; draft predictions come AFTER the save (launch)
  /// draft-7 round (owner 25 Nov): 7 spots, no captain, "surprise" players score × surpriseMult
  bool   get isDraft => _draftView && (currentEvent?.draftOn ?? false);
  int    get squadSize => isDraft ? draftSize : 11;
  /// draft size of the current round (4..7; 7 = the full shape with wingers)
  int    get draftSize => (currentEvent?.draftSize ?? 7).clamp(4, 7).toInt();
  /// the server formation the v2 builder saves (draft: DEF-MID-FWD counts of the round's shape)
  String get v2Formation => isDraft ? const {4: '1-1-1', 5: '1-2-1', 6: '2-2-1'}[draftSize] ?? '2-3-1' : '4-5-1';

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    isArabic = widget.isArabicOverride;
    LocalStore.getFlag('fantasy_pitch_tip').then((seen) {
      if (mounted && !seen) setState(() => _showPitchTip = true);
    });
    LocalStore.getFlag('fantasy_help_hint').then((seen) {
      if (mounted && !seen) setState(() => _showHelpHint = true);
    });
    _loadLobby();
    _loadKits();
    _loadAppConfig();
  }

  // ── v2: EUR→EGP rate + card picture mode (fantasy_app_config, changed in the DB, no build) ──
  static double _eurEgp = 55;
  static String _cardImage = 'photo';
  static String _pitchImage = 'shirt';      // pitch spot picture: photo | shirt
  static String _pitchName = 'short_club';  // pitch strips: split | full_club | short_club
  static bool _limitPills = true;        // club-limit pills on the START / bench step (fantasy_limit_pills = show | hide)
  static int _subsMax = 2;               // bench: max subs from the same club (fantasy_draft_subs_max_per_team), apart from the 7
  static String _arenaInfo = 'show';      // arena page info box: show | hide (fantasy_arena_info)
  /// round page look (owner 28 Nov): show = "Current GW" in the top bar + arena switch circle + deadline / prize cards,
  /// no recap / nudge lines (they live in My Fantasy); hide = the old page (fantasy_lobby_compact)
  static bool _lobbyCompact = true;
  static bool _cfgLoaded = false;
  /// which squads the app offers (DB `fantasy_modes`): draft | normal | both (launch default draft)
  static String _modes = 'draft';
  bool get _draftOnly => _modes == 'draft';
  bool get _normalOnly => _modes == 'normal';
  Future<void> _loadAppConfig() async {
    if (_cfgLoaded) return;
    try {
      final r = await _sb.rpc('fantasy_app_config');
      if (r is Map) {
        final rate = (r['eur_egp_rate'] as num?)?.toDouble();
        if (rate != null && rate > 0) _eurEgp = rate;
        _cardImage = r['card_image'] == 'shirt' ? 'shirt' : 'photo';
        _pitchImage = r['pitch_image'] == 'photo' ? 'photo' : 'shirt';
        final pn = r['pitch_name'];
        _pitchName = (pn == 'split' || pn == 'full_club') ? pn as String : 'short_club';
        _arenaInfo = r['arena_info'] == 'hide' ? 'hide' : 'show';
        _lobbyCompact = r['lobby_compact'] != 'hide';
        final md = r['modes'];
        _modes = (md == 'normal' || md == 'both') ? md as String : 'draft';
        final sm = (r['subs_max_per_team'] as num?)?.toInt();
        if (sm != null && sm > 0) _subsMax = sm;
        _limitPills = r['limit_pills'] != 'hide';
      }
      _cfgLoaded = true;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  // ── team shirts on the pitch (fantasy_team_kits: tiny JSON, once per app run) ──
  static Map<String, _Kit> _kits = {};
  static bool _kitsLoaded = false;
  Future<void> _loadKits() async {
    if (_kitsLoaded) return;
    try {
      final r = await _sb.rpc('fantasy_team_kits');
      final m = <String, _Kit>{};
      if (r is Map) {
        r.forEach((k, v) { final kit = _Kit.fromJson(v); if (kit != null) m['$k'] = kit; });
      }
      _kits = m; _kitsLoaded = true;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _swapTimer?.cancel();
    squadTick.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DATA LOADING
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _loadLobby() async {
    setState(() { _lobbyLoading = true; _lobbyError = null; });
    try {
      try { await _sb.rpc('fantasy_tick'); } catch (_) {}
      await _loadAppConfig();   // the modes decide which rounds count
      final res = await _sb.rpc('get_fantasy_lobby');
      final data = res as Map<String, dynamic>;
      setState(() {
        // modes = draft: a round without the draft open counts as "no round"; normal / both: every round
        FantasyEvent? ev(dynamic j) { if (j == null) return null; final e = FantasyEvent.fromJson(j as Map<String, dynamic>); return (e.draftOn || !_draftOnly) ? e : null; }
        _localEvent = ev(data['LOCAL']);
        _worldEvent = ev(data['WORLD']);
        _lobbyLoading = false;
      });
    } catch (e) {
      setState(() { _lobbyLoading = false; _lobbyError = e.toString(); });
    }
  }

  Future<void> _loadPlayers(String eventId) async {
    setState(() { _playersLoading = true; _playersError = null; players = []; });
    try {
      dynamic res;
      try {
        res = await _sb.rpc('fantasy_players_list', params: {'p_event_id': eventId});
      } catch (_) {
        res = await _sb.rpc('get_fantasy_players', params: {'p_event_id': eventId});
      }
      final list = res as List;
      Diag.crumb('players loaded ${list.length}');
      setState(() {
        players = list.map((e) => FancyPlayer.fromJson(e as Map<String, dynamic>)).toList();
        _playersLoading = false;
      });
      squadTick.value++;
    } catch (e) {
      Diag.crumb('players error $e');
      setState(() { _playersLoading = false; _playersError = e.toString(); });
      squadTick.value++;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SAVE SQUAD
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> saveSquad({bool noBudget = false}) async {
    if (!(noBudget ? canSaveV2 : canSave)) return;
    if (selectedCount < squadSize) { _showSnack(t('Select all $squadSize players.','اختار $squadSize لاعيبة.')); return; }
    if (!noBudget && remaining < 0) { _showSnack(t('Budget exceeded.','تجاوزت الميزانية.')); return; }
    if (captain == null && !isDraft) { _showSnack(t('Pick a captain.','اختار كابتن.')); return; }

    setState(() { _saving = true; _saveError = null; });
    try {
      final slots = <Map<String, dynamic>>[];
      for (final pos in posOrder) {
        for (var i = 0; i < slotCount(pos); i++) {
          final p = squad[pos]![i];
          if (p != null) slots.add({'position': pos, 'slot_index': i, 'player_id': p.id});
        }
      }
      if (isDraft) {
        await _sb.rpc('save_fantasy_draft', params: {'p_event_id': currentEvent!.eventId, 'p_slots': slots});
        if (this._benchOn) {
          await _sb.rpc('save_fantasy_draft_subs', params: {'p_event_id': currentEvent!.eventId, 'p_subs': this._benchPayload});
        }
        if (_predMatches.isNotEmpty && _predsDone) {
          await _sb.rpc('save_draft_predictions', params: {'p_event_id': currentEvent!.eventId, 'p_preds': _predsPayload});
        }
      } else {
        await _sb.rpc('save_fantasy_squad', params: {
          'p_event_id':         currentEvent!.eventId,
          'p_formation':        formation,
          'p_captain_player_id': captain!.id,
          'p_slots':            slots,
        });
      }
      setState(() { _saving = false; saved = true; _hasSquad = true; });
      if (mounted) showStadiumConfetti(context);
      final evId = currentEvent!.eventId;
      final askPreds = isDraft && _predMatches.isNotEmpty && !_predsDone;
      Future.delayed(const Duration(milliseconds: 1200), () async {
        if (!mounted) return;
        if (askPreds) { await this._d7EditPreds(afterSave: true); if (!mounted) return; }
        // owner 28 Nov: the very first squad ever → "first achievement" → his cabinet (no profile sheet that time)
        if (await maybeFirstAchievement(context, onSeeCabinet: () => HomeActions.showProfileTab?.call())) {
          await LocalStore.setStr('cp_prompt_$evId', '1');
          return;
        }
        if (!mounted) return;
        // owner 28 Nov: once per round, a small "complete your profile (+30 pts)" sheet when something is missing
        await maybePromptCompleteProfile(context, evId);
        if (!mounted) return;
        // the 2 "round played" points count at save → a new level is celebrated right here (owner 28 Nov)
        await maybeLevelUpAfterSave(context, onSeeProfile: () => HomeActions.showProfileTab?.call());
        if (!mounted) return;
        final shown = await showLaunchSavedNudge(context, isArabic, evId);
        if (!shown && mounted) _showSavedAd();
      });
    } catch (e) {
      setState(() { _saving = false; _saveError = e.toString(); });
      _showSnack(_saveErrorText(e.toString()));
    }
  }

  /// بعد "تم حفظ الفريق": كارت إعلان واحد هادي بيتقفل (مرة في الجلسة لكل جولة)
  static final Set<String> _savedAdShown = {};
  void _showSavedAd() {
    final ev = currentEvent;
    if (ev == null || !_savedAdShown.add(ev.eventId)) return;
    final ad = Ads.pick('fantasy_squad_saved', eventId: ev.eventId);
    if (ad == null || !mounted) return;
    showModalBottomSheet<void>(
      context: context, backgroundColor: bg, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20), const SizedBox(width: 8),
            Text(t('Team saved! ✓', 'تم حفظ الفريق! ✓'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          ]),
          const SizedBox(height: 12),
          AdImpression(ad: ad, child: AdNativeCard(ad, compact: true)),
          const SizedBox(height: 10),
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text(t('Close', 'تمام'), style: const TextStyle(color: muted, fontWeight: FontWeight.w700))),
        ]),
      )),
    );
  }

  /// رسالة واضحة لكل سبب رفض من السيرفر (السيرفر هو اللي بيقرر)
  String _saveErrorText(String err) {
    if (err.contains('predictions_incomplete') || err.contains('no_predictions'))
      return t('Score predictions changed. Refresh and predict again.', 'ماتشات التوقع اتغيّرت. حدّث وتوقّع تاني.');
    if (err.contains('no_draft_squad'))     return t('Save your draft team first.', 'احفظ تشكيلة الدرافت الأول.');
    if (err.contains('draft_closed'))       return t('The draft is closed in this round.', 'الدرافت مقفول في الجولة دي.');
    if (err.contains('event_closed'))       return t('This round is closed. The deadline has passed.', 'الجولة اتقفلت، الديدلاين عدّى.');
    if (err.contains('budget_exceeded'))    return t('Budget exceeded.', 'تجاوزت الميزانية.');
    if (err.contains('formation_mismatch')) return t('Your players don\'t match the formation.', 'اللاعيبة مش مطابقة للتشكيل.');
    if (err.contains('invalid_squad_size')) return t('Pick $squadSize different players.', 'اختار $squadSize لاعيبة مختلفين.');
    if (err.contains('invalid_player'))     return t('One of the players is not available in this round. Refresh and try again.', 'فيه لاعب مش متاح في الجولة دي. حدّث وجرّب تاني.');
    if (err.contains('invalid_captain'))    return t('Pick a captain from your team.', 'اختار كابتن من فريقك.');
    if (err.contains('team_limit'))         return t('Max ${maxPerTeam ?? 3} players from the same team.', 'أقصى ${maxPerTeam ?? 3} لاعيبة من نفس الفريق.');
    if (err.contains('invalid_formation'))  return t('Pick a valid formation.', 'اختار تشكيل صحيح.');
    return t('Save failed. Try again.', 'فشل الحفظ. حاول تاني.');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ARENA / SQUAD HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  void enterArena(String value) {
    Diag.crumb('enterArena $value event=${currentEvent?.eventId}');
    setState(() { arena = value; step = 1; clearSquad(); saved = false; _hasSquad = false; _squadChecked = false; _draftView = !_normalOnly && (currentEvent?.draftOn ?? false); _duelKey = null; _startCountdown(); });
    if (currentEvent != null) {
      _myRank = null;
      _loadPlayers(currentEvent!.eventId);
      _loadSavedSquad(currentEvent!.eventId);
      if (phaseOf(currentEvent) == 'finished') _loadMyRank(currentEvent!.eventId);
    }
    this._loadRecap();   // last finished round of this arena (opens once per round)
  }

  Future<void> _loadSavedSquad(String eventId) async {
    try {
      final draft = isDraft;
      final res = await _sb.rpc(draft ? 'get_my_fantasy_draft' : 'get_my_fantasy_squad', params: {'p_event_id': eventId});
      if (draft != isDraft) return;   // the user switched normal / draft meanwhile
      final has = res is Map ? ((res['slots'] as List?) ?? const []).isNotEmpty : (res is List && res.isNotEmpty);
      if (mounted) setState(() { _hasSquad = has; _squadChecked = true; });
      // الدالة بترجع object (مش list) — نقبل الشكلين
      final Map<String, dynamic>? data = res is Map
          ? Map<String, dynamic>.from(res)
          : (res is List && res.isNotEmpty && res.first is Map)
              ? Map<String, dynamic>.from(res.first as Map)
              : null;
      if (data == null) return;
      if (draft) {
        _preds.clear();
        for (final x in (data['predictions'] as List?) ?? const []) {
          final m = Map<String, dynamic>.from(x as Map);
          _preds['${m['match_id']}'] = [(m['home'] as num?)?.toInt(), (m['away'] as num?)?.toInt()];
        }
      }
      final slots = (data['slots'] as List?) ?? [];
      if (slots.isEmpty) return;
      // ولوع التشكيلة
      final fmt = data['formation'] as String? ?? formation;
      final capId = data['captain_player_id'] as String?;
      // انتظر اللاعبين يتحملوا
      var tries = 0;
      while ((players.isEmpty || _playersLoading) && tries < 80) { await Future.delayed(const Duration(milliseconds: 150)); tries++; }
      if (!mounted || draft != isDraft) return;
      setState(() {
        formation = fmt;
        clearSquad();
        for (final slot in slots) {
          final m = slot as Map<String, dynamic>;
          final pos = m['position'] as String;
          final idx = (m['slot_index'] as int);
          final pid = m['player_id'] as String?;
          if (pid == null) continue;
          final _filtered2 = players.where((p) => p.id == pid);
          // اللاعيبة اللي في فريقه بتفضل بسعر الشرا (حتى لو سعرهم اتغيّر بعد ما حفظ)
          final paid = (m['fantasy_price'] as num?)?.toDouble();
          final base = _filtered2.isEmpty ? null : _filtered2.first;
          final player = base == null ? null : (paid != null && paid != base.price ? base.withPrice(paid) : base);
          if (player != null && squad[pos] != null && idx < squad[pos]!.length) {
            squad[pos]![idx] = player;
            if (capId != null && pid == capId) captain = player;
          }
        }
        if (draft) this._benchLoad(data['subs']);
        saved = true;
        _hasSquad = true;
      });
      if (formation == '4-5-1') this._v2RestoreLayout(eventId);
    } catch (_) {}
  }

  void clearSquad() {
    for (final l in squad.values) { for (var i = 0; i < l.length; i++) l[i] = null; }
    captain = null;
    _benchGk = null;
    for (var i = 0; i < _benchOut.length; i++) _benchOut[i] = null;
  }

  void changeFormation(String value) {
    setState(() {
      formation = value;
      for (final pos in posOrder) {
        final l = squad[pos]!;
        for (var i = slotCount(pos); i < l.length; i++) l[i] = null;
      }
      if (captain != null && !pickedPlayers.contains(captain)) captain = null;
      saved = false;
    });
  }

  // ── شاشة كل اللاعيبة ─────────────────────────────────────────────────────
  /// بيتغير كل ما الفريق أو قايمة اللاعيبة تتغير (علشان شاشة اللاعيبة تتحدّث)
  final ValueNotifier<int> squadTick = ValueNotifier(0);

  int? get maxPerTeam => isDraft ? currentEvent?.draftMaxPerTeam : (currentEvent?.maxPerTeam ?? (arena == 'WORLD' ? 3 : null));
  bool inSquad(FancyPlayer p) => pickedPlayers.any((c) => c.id == p.id);
  int teamCount(String? teamId) => teamId == null ? 0 : pickedPlayers.where((c) => c.teamId == teamId).length;

  Map<String, String> get teamLogos {
    final m = <String, String>{};
    for (final x in currentEvent?.matches ?? const <FantasyMatch>[]) {
      if (x.homeLogoUrl != null) m[x.homeTeamId] = x.homeLogoUrl!;
      if (x.awayLogoUrl != null) m[x.awayTeamId] = x.awayLogoUrl!;
    }
    return m;
  }

  /// بيحط اللاعب في الفريق. بيرجع سبب الرفض، أو null لو اتحط
  String? placePlayer(FancyPlayer p, {String? pos, int? index, bool noBudget = false}) {
    if (inSquad(p)) return t('Already in your team.', 'موجود في فريقك.');
    final slotPos = pos ?? p.position;
    // small drafts (4/5/6): a winger (MID in players.position) may stand in the attacker spot
    if (slotPos != p.position && !(isDraft && draftSize < 7)) return t('Wrong position.', 'المركز مش مناسب.');
    var idx = index;
    if (idx == null) {
      for (var i = 0; i < slotCount(slotPos); i++) {
        if (squad[slotPos]![i] == null) { idx = i; break; }
      }
    }
    if (idx == null) {
      return t('Your ${p.position} spots are full. Tap a player on the pitch to swap.',
               'أماكن الـ ${p.position} مليانة. دوس على لاعب في الملعب علشان تبدّله.');
    }
    final current = squad[slotPos]![idx];
    if (!noBudget && p.price > remaining + (current?.price ?? 0) + 1e-9) return t('Not enough budget.', 'الميزانية مش مكفية.');
    final lim = maxPerTeam;
    if (lim != null && p.teamId != null) {
      final n = teamCount(p.teamId) - (current?.teamId == p.teamId ? 1 : 0);
      if (n >= lim) return t('Max $lim players from the same team.', 'أقصى $lim لاعيبة من نفس الفريق.');
    }
    setState(() {
      if (current != null && captain == current) captain = null;
      squad[slotPos]![idx!] = p;
      saved = false;
    });
    squadTick.value++;
    return null;
  }

  void removePlayer(FancyPlayer p) {
    setState(() {
      for (final pos in posOrder) {
        final l = squad[pos]!;
        for (var i = 0; i < l.length; i++) { if (l[i]?.id == p.id) l[i] = null; }
      }
      if (captain?.id == p.id) captain = null;
      saved = false;
    });
    squadTick.value++;
  }

  void _openPlayersPage({String? pos, int? index, bool browse = false}) {
    if (players.isEmpty && !_playersLoading && currentEvent != null) _loadPlayers(currentEvent!.eventId);
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _PlayersPage(host: this, lockPos: pos, slotIndex: index, browse: browse)));
  }

  List<FancyPlayer> availableFor(String pos) => players
      .where((p) => p.position == pos && !pickedPlayers.any((c) => c.id == p.id))
      .toList();

  void autoPick() {
    setState(() {
      // ابدأ من الصفر لضمان تشكيلة كاملة ضمن الميزانية
      clearSquad();
      final picked = <FancyPlayer>[];
      var budgetLeft = initialBudget;

      for (final pos in posOrder) {
        for (var i = 0; i < slotCount(pos); i++) {
          // احسب الحد الأدنى المطلوب للخانات الجاية
          var minForRest = 0.0;
          for (final otherPos in posOrder) {
            final startIdx = otherPos == pos ? i + 1 : 0;
            final slotsLeft = otherPos == pos
                ? slotCount(pos) - i - 1
                : slotCount(otherPos);
            final available = players
                .where((p) => p.position == otherPos && !picked.any((c) => c.id == p.id))
                .toList()
              ..sort((a, b) => a.price.compareTo(b.price));
            for (var j = 0; j < slotsLeft && j < available.length; j++) {
              minForRest += available[j].price;
            }
          }

          // اختار أفضل لاعب بيفضّل فلوس كافية للباقي
          final lim = maxPerTeam;
          final pool = players
              .where((p) => p.position == pos && !picked.any((c) => c.id == p.id)
                  && (lim == null || p.teamId == null || picked.where((c) => c.teamId == p.teamId).length < lim))
              .toList()
            ..sort((a, b) => b.price.compareTo(a.price));

          FancyPlayer? choice;
          for (final p in pool) {
            if (p.price + minForRest <= budgetLeft) {
              choice = p;
              break;
            }
          }
          // لو ما فيش خيار مناسب، خد الأرخص
          if (choice == null && pool.isNotEmpty) {
            pool.sort((a, b) => a.price.compareTo(b.price));
            if (pool.first.price <= budgetLeft) choice = pool.first;
          }

          if (choice != null) {
            squad[pos]![i] = choice;
            picked.add(choice);
            budgetLeft -= choice.price;
          }
        }
      }

      // الكابتن = الأغلى
      if (picked.isNotEmpty) {
        captain = (picked..sort((a, b) => b.price.compareTo(a.price))).first;
      }
      saved = false;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COUNTDOWN
  // ─────────────────────────────────────────────────────────────────────────
  void _startCountdown() {
    _countdownTimer?.cancel();
    _updateTimeLeft();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTimeLeft());
  }

  void _updateTimeLeft() {
    final deadline = currentEvent?.deadlineAt;
    if (deadline == null) return;
    final now = DateTime.now();
    setState(() { _timeLeft = deadline.isAfter(now) ? deadline.difference(now) : Duration.zero; });
  }

  String get countdownText {
    if (deadlinePassed) return t('Deadline passed', 'انتهى الديدلاين');
    final d = _timeLeft.inDays;
    final h = _timeLeft.inHours.remainder(24);
    final m = _timeLeft.inMinutes.remainder(60);
    final s = _timeLeft.inSeconds.remainder(60);
    final pad = (int n) => n.toString().padLeft(2, '0');
    if (d > 0) return t('${d}d ${h}h ${pad(m)}m', '$d يوم $h س ${pad(m)} د');
    return h > 0 ? '${h}h ${pad(m)}m ${pad(s)}s' : '${pad(m)}:${pad(s)}';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TRANSLATIONS
  // ─────────────────────────────────────────────────────────────────────────
  String t(String en, String ar) => isArabic ? ar : en;
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: surface2, behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      content: Text(msg, style: const TextStyle(color: Colors.white)),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TOUR
  // ─────────────────────────────────────────────────────────────────────────
  List<TourCard> get tourCards => [
    TourCard(screen: 0, titleEn: 'Pick your arena', titleAr: 'اختار الأرينا',
      linesEn: ['EGYPT — Ahly & Zamalek','WORLD — World Stars','Pick to start.'],
      linesAr: ['مصر — الأهلي والزمالك','عالمي — نجوم العالم','اختار للبدء.']),
    TourCard(screen: 1, titleEn: "This round's matches", titleAr: 'ماتشات الجولة',
      linesEn: ['Your players score in these matches.','Make your team before the deadline.'],
      linesAr: ['لعيبتك بتجمع نقط في الماتشات دي.','كمّل فريقك قبل الديدلاين.']),
    TourCard(screen: 2, titleEn: 'Build your team', titleAr: 'ابني فريقك',
      linesEn: ['You have ${_fmtBudget(initialBudget)} budget.','Tap an empty spot to pick a player.','Use AUTO PICK to fill the team.','Change formation anytime.'],
      linesAr: ['معاك ميزانية ${_fmtBudget(initialBudget)}.','ادوس على خانة فاضية تختار لاعب.','AUTO PICK لتعبئة الفريق تلقائي.','غيّر التشكيلة في أي وقت.']),
    TourCard(screen: 2, titleEn: 'Captain & points', titleAr: 'الكابتن والنقاط',
      linesEn: ['Tap a player to swap or make him Captain.','Goals, assists & clean sheets earn points.','Tap ? for the full scoring table.'],
      linesAr: ['ادوس على لاعب تبدّله أو تعينه كابتن.','الجول والأسيست والشباك النظيفة بتجيب نقط.','ادوس ? لشوف جدول النقاط.']),
  ];

  bool get tourVisible => tourActive && tourCards[tourIndex].screen == step;
  void nextTour() => setState(() { if (tourIndex + 1 >= tourCards.length) tourActive = false; else tourIndex++; });
  void skipTour() => setState(() => tourActive = false);

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  String? _reportedInArena;

  /// top bar helpers (launch): back to the arena picker / jump straight to the other arena
  void goArenaPicker() => setState(() { step = 0; saved = false; });
  void switchArena() {
    if (_flying) return;
    enterArena(arena == 'EGYPT' ? 'WORLD' : 'EGYPT');
  }

  @override
  Widget build(BuildContext context) {
    final inArena = step > 0;
    // the shell's top bar follows the step + arena (title, switch circle)
    final key = '$inArena|$step|$arena|$_cfgLoaded';
    if (_reportedInArena != key) {
      _reportedInArena = key;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onInArena?.call(inArena));
    }
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Brand.background, Color(0xFF0D0D12)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: Stack(children: [
          // البادجر باهت في الخلفية (هوية BDGR)
          Positioned.fill(child: IgnorePointer(child: Center(
            child: FractionallySizedBox(widthFactor: 0.9,
              child: Opacity(opacity: 0.06,
                child: Image.asset(Brand.badger, fit: BoxFit.contain)))))),
          Positioned.fill(child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            // launch motion: the next page comes forward (fade + a small zoom), the old one steps back
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim,
              child: ScaleTransition(scale: Tween<double>(begin: 0.94, end: 1.0)
                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)), child: child)),
            // بعد الديدلاين: التشكيلة للعرض بس (مفيش بناء ولا تعديل)
            child: step == 0 ? buildArenaScreen()
                : step == 1 ? buildLobbyScreen()
                : (saved || phaseOf(currentEvent) != 'open') ? buildMySquadView()
                : this.buildSquadScreenV2(), // v2 step-by-step builder (fantasy_builder_v2.dart)
          )),
          if (tourVisible) buildTourOverlay(),
          if (widget.showTopButtons) _buildTopButtons(),

        ])),
    );
  }

  Widget _buildTopButtons() => Positioned(
    top: 10, right: 16,
    child: Row(children: [
      // عربي / English — آخر اختيار بيمشي على الفانتازي كلها
      FantasyLangToggle(isArabic: isArabic, onTap: () {
        _dismissHelpHint();
        widget.onLanguageToggle?.call();
      }),
      const SizedBox(width: 8),
      _HelpPulse(active: _showHelpHint && step == 0,
        child: _circleBtn('?', openHelpSheet, isText: true)),
    ]),
  );

  Widget _circleBtn(String label, VoidCallback onTap, {bool isText = false}) =>
    GestureDetector(onTap: onTap, child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: cardBg, shape: BoxShape.circle, border: Border.all(color: line)),
      child: Center(child: Text(label, style: const TextStyle(color: mint, fontSize: 13, fontWeight: FontWeight.w900, height: 1))),
    ));

  // ─────────────────────────────────────────────────────────────────────────
  // ARENA SCREEN
  // ─────────────────────────────────────────────────────────────────────────
  static const String egyptArenaImage = 'https://huggingface.co/datasets/Meekkii/IPLAY/resolve/main/Images/Fantasy/Local.jpg';
  static const String worldArenaImage = 'https://huggingface.co/datasets/Meekkii/IPLAY/resolve/main/Images/Fantasy/World.jpg';
  static const Color  egyptTint  = Color(0xFF4A0808);
  static const Color  worldTint  = Color(0xFF1E1E1E);
  static const Duration arenaAnim  = Duration(milliseconds: 320);
  static const Curve    arenaCurve = Curves.easeOutCubic;

  Widget buildArenaScreen() {
    if (arenaAutoSwap && !_swapStopped && _swapTimer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _ensureAutoSwap(); });
    }
    return LayoutBuilder(key: const ValueKey('arena'), builder: (context, constraints) {
      final compact = constraints.maxHeight < 640;
      return Listener(
        // أول ما اليوزر يلمس أي حاجة: الحركة تقف خالص
        onPointerDown: (_) { if (_swapTimer != null) _stopAutoSwap(); },
        child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          StaggerIn(index: 0, child: FantasyHighlightsStrip(isArabic: isArabic)),
          StaggerIn(index: 1, child: _arenaTitle(compact)),
          // راعي الفانتازي كلها: "FANTASY برعاية X"
          const AdSlot('fantasy_title', center: true, padding: EdgeInsets.only(top: 6),
              prefixEn: 'Presented by', prefixAr: 'برعاية'),
          SizedBox(height: compact ? 12 : 16),
          if (_lobbyLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: brandRed)))
          else if (_lobbyError != null)
            Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(t('Failed to load.','فشل التحميل.'), style: const TextStyle(color: muted)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadLobby,
                style: ElevatedButton.styleFrom(backgroundColor: brandRed),
                child: Text(t('Retry','إعادة المحاولة'))),
            ])))
          else if (_localEvent == null && _worldEvent == null)
            Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('⏳', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(t('No active rounds right now.','مفيش جولات نشطة دلوقتي.'),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(t('Check back soon for the next round.','تابعنا عشان تعرف موعد الجولة الجاية.'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted, fontSize: 13)),
            ])))
          else
            Expanded(child: _arenaSplit()),
          if (_arenaInfo == 'show') ...[const SizedBox(height: 10), StaggerIn(index: 4, child: _howItWorksStrip())] else const SizedBox(height: 10),
        ]),
      ));
    });
  }

  /// "إزاي بتلعب" في سطر واحد — من غير ما نوقف اليوزر
  Widget _howItWorksStrip() {
    Widget item(IconData icon, String text) => Expanded(child: Column(
      mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Brand.green, size: 18),
        const SizedBox(height: 4),
        Text(text, textAlign: TextAlign.center, maxLines: 2,
          style: const TextStyle(color: Color(0xFFCFCFCF), fontSize: 10.5, height: 1.3)),
      ]));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: line)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          item(Icons.groups_2_outlined, t('Be the\ncoach', 'عيش دور\nالمدرب')),
          item(Icons.star_rounded,      t('Pick the right player\nfor every spot', 'اختار الأنسب\nلكل مركز')),
          item(Icons.sports_soccer,     t('Points from\nreal matches', 'نقط من الماتشات\nالحقيقية')),
        ]),
      ),
      TextButton(
        onPressed: openHelpSheet,
        style: TextButton.styleFrom(foregroundColor: Brand.green, visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(vertical: 2), minimumSize: const Size(0, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        child: Text(t('How do you play?', 'إزاي بتلعب؟'),
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
      ),
    ]);
  }


  Widget _arenaTitle(bool compact) => Column(children: [
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _bracketCorner(left: true),
      Expanded(child: Padding(padding: const EdgeInsets.only(top: 8),
        child: FittedBox(fit: BoxFit.scaleDown, child: Text(
          t('PICK YOUR ARENA','اختار الأرينا'),
          style: TextStyle(fontSize: compact ? 24 : 28, fontWeight: FontWeight.w900, color: Colors.white))))),
      _bracketCorner(left: false),
    ]),
    const SizedBox(height: 6),
    Text(t('Choose your matches. Build your team.','اختار ماتشاتك. ابني فريقك.'),
      textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFCFCFCF), fontSize: 13)),
  ]);

  Widget _bracketCorner({required bool left}) {
    const side = BorderSide(color: Color(0xFF6B6B6B), width: 1.2);
    return Container(width: 14, height: 30, decoration: BoxDecoration(border: Border(
      top: side, left: left ? side : BorderSide.none, right: !left ? side : BorderSide.none)));
  }

  Widget _arenaSplit() => LayoutBuilder(builder: (context, cons) {
    const gap = 4.0;
    final total = cons.maxWidth - gap;
    final egyptOpen = expandedArena == 'EGYPT';
    final leftW  = total * (egyptOpen ? 0.66 : 0.34);
    final rightW = total - leftW;

    return Stack(fit: StackFit.expand, clipBehavior: Clip.none, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AnimatedContainer(duration: arenaAnim, curve: arenaCurve, width: leftW,
          child: StaggerIn(index: 2, dy: 60, durationMs: 560, child: _arenaHalf(id: 'EGYPT', tag: _arenaTag(_localEvent),
            image: egyptArenaImage, tint: egyptTint, isLeft: true, available: _localEvent != null))),
        const SizedBox(width: gap),
        AnimatedContainer(duration: arenaAnim, curve: arenaCurve, width: rightW,
          child: StaggerIn(index: 3, dy: 60, durationMs: 560, child: _arenaHalf(id: 'WORLD', tag: _arenaTag(_worldEvent),
            image: worldArenaImage, tint: worldTint, isLeft: false, available: _worldEvent != null))),
      ]),
      AnimatedPositioned(duration: arenaAnim, curve: arenaCurve,
        left: leftW + gap / 2 - 22, top: cons.maxHeight * 0.36 - 22,
        child: IgnorePointer(child: _arenaSeamBadge())),
    ]);
  });

  /// معلومة مفيدة على الكارت: عدد الماتشات + فاضل قد إيه على الديدلاين
  String _arenaTag(FantasyEvent? ev) {
    if (ev == null) return t('No round now', 'مفيش جولة دلوقتي');
    final n = ev.matches.length;
    final matches = t('$n ${n == 1 ? 'match' : 'matches'}', '$n ${n == 1 ? 'ماتش' : 'ماتشات'}');
    final ph = phaseOf(ev);
    if (ph == 'finished') return t('Finished · see results', 'خلصت · شوف النتايج');
    if (ph == 'live') return t('🔴 Live now', '🔴 شغالة دلوقتي');
    final left = ev.deadlineAt.difference(DateTime.now());
    final when = left.inDays >= 1
        ? t('${left.inDays}d', '${left.inDays} يوم')
        : left.inHours >= 1
            ? t('${left.inHours}h', '${left.inHours} ساعة')
            : t('${left.inMinutes}m', '${left.inMinutes} دقيقة');
    return '$matches · ${t('closes in', 'تتقفل بعد')} $when';
  }

  Widget _arenaSeamBadge() => Container(width: 44, height: 44,
    decoration: BoxDecoration(shape: BoxShape.circle,
      gradient: const LinearGradient(colors: [egyptTint, egyptTint, worldTint, worldTint], stops: [0.0, 0.5, 0.5, 1.0]),
      border: Border.all(color: mint, width: 1.5),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 10)]),
    child: const Icon(Icons.sports_soccer, color: Colors.white, size: 22));

  Widget _arenaHalf({required String id, required String tag, required String image,
      required Color tint, required bool isLeft, required bool available}) {
    final open = expandedArena == id;
    const radius = Radius.circular(18);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: open ? null : () => setState(() => expandedArena = id),
      child: ClipRRect(
        borderRadius: isLeft
          ? const BorderRadius.horizontal(left: radius)
          : const BorderRadius.horizontal(right: radius),
        child: Stack(fit: StackFit.expand, children: [
          Image(image: MediaCache.image(image), fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: tint,
              child: const Center(child: Icon(Icons.stadium, size: 60, color: sage)))),
          AnimatedContainer(duration: arenaAnim,
            decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [tint.withOpacity(open ? 0.20 : 0.60), tint.withOpacity(open ? 0.75 : 0.85), tint.withOpacity(0.97)],
              stops: const [0.0, 0.55, 1.0]))),
          LayoutBuilder(builder: (context, c) {
            final showOpen = open && c.maxWidth >= 170;
            return ClipRect(child: Padding(padding: const EdgeInsets.all(14),
              child: AnimatedSwitcher(duration: const Duration(milliseconds: 200),
                layoutBuilder: (current, previous) => Stack(fit: StackFit.expand,
                  children: [...previous, if (current != null) current]),
                child: showOpen
                  ? _arenaHalfOpen(key: ValueKey('open-$id'), id: id, tag: tag, available: available, showPoints: c.maxHeight >= 300)
                  : _arenaHalfClosed(key: ValueKey('closed-$id'), id: id, isLeft: isLeft))));
          }),
        ]),
      ),
    );
  }

  Widget _arenaHalfOpen({required Key key, required String id, required String tag, required bool available, required bool showPoints}) {
    final idLabel  = id == 'EGYPT' ? t('EGYPT','مصر') : t('WORLD','عالمي');
    final btnLabel = id == 'EGYPT' ? t('ENTER EGYPT','دخول مصر') : t('ENTER WORLD','دخول عالمي');
    return Column(key: key, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), borderRadius: BorderRadius.circular(20)),
        child: Text(tag, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 10, fontWeight: FontWeight.w600))),
      const Spacer(),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
        child: Text(idLabel, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 1))),
      if (!available) ...[
        const SizedBox(height: 6),
        Text(t('No active event','مفيش إيفنت نشط'), style: const TextStyle(color: muted, fontSize: 11)),
      ],
      const SizedBox(height: 16),
      Pressable(enabled: available, child: SizedBox(width: double.infinity, height: 46,
        child: ElevatedButton(
          onPressed: available ? () => enterArena(id) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: available ? brandRed : surface2,
            foregroundColor: available ? Colors.white : muted,
            elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
          child: FittedBox(fit: BoxFit.scaleDown,
            child: Text(btnLabel, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.6)))))),
    ]);
  }

  Widget _arenaHalfClosed({required Key key, required String id, required bool isLeft}) {
    final idLabel = id == 'EGYPT' ? t('EGYPT','مصر') : t('WORLD','عالمي');
    return Column(key: key, mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        FittedBox(fit: BoxFit.scaleDown,
          child: Text(idLabel, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1))),
        const SizedBox(height: 6),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: mint.withOpacity(0.5))),
          child: FittedBox(fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(t('View','عرض'), style: const TextStyle(color: mint, fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              const Icon(Icons.open_in_full, color: mint, size: 12),
            ]))),
      ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOBBY SCREEN
  // ─────────────────────────────────────────────────────────────────────────
  Widget buildLobbyScreen() {
    final event = currentEvent;
    if (event == null) {
      return Center(child: Text(t('No event available.','مفيش إيفنت متاح.'), style: const TextStyle(color: muted)));
    }
    return this.launchLobby(event);   // launch: fantasy_launch.dart
  }

  /// الجولات الجاية: معاينة (قابلة للتعديل لحد ما تتفتح)
  Future<void> _openUpcoming() async {
    final type = arena == 'EGYPT' ? 'LOCAL' : 'WORLD';
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, backgroundColor: bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.75, maxChildSize: 0.94,
        builder: (_, sc) => FutureBuilder<dynamic>(
          future: _sb.rpc('fantasy_upcoming', params: {'p_type': type}),
          builder: (_, snap) {
            final list = ((snap.data as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
            return ListView(controller: sc, padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 12),
              Text(t('🗓️ Next rounds', '🗓️ الجولات الجاية'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF221B0A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x66FFB300))),
                child: Text(t('Preview only — matches and times may change until the round opens. You can build your team when it opens on Friday.',
                              'معاينة بس — الماتشات والمواعيد ممكن تتغير لحد ما الجولة تتفتح. تقدر تبني فريقك لما تتفتح يوم الجمعة.'),
                  style: const TextStyle(color: Color(0xFFFFD27A), fontSize: 12.5, height: 1.4)),
              ),
              const SizedBox(height: 12),
              if (snap.connectionState != ConnectionState.done)
                const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: brandRed)))
              else if (list.isEmpty)
                Padding(padding: const EdgeInsets.all(30), child: Text(t('No upcoming rounds announced yet.', 'لسه مفيش جولات جاية متعلنة.'),
                  textAlign: TextAlign.center, style: const TextStyle(color: muted)))
              else for (final r in list) ...[
                Row(children: [
                  Text(t('Round ${r['round_no']}', 'الجولة ${r['round_no']}'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(() {
                    final o = DateTime.tryParse('${r['opens_at']}')?.toLocal();
                    return o == null ? '' : t('opens ${_fmtDeadline(o)} ${_fmtDate(o)}', 'بتتفتح ${_fmtDeadline(o)} ${_fmtDate(o)}');
                  }(), style: const TextStyle(color: muted, fontSize: 12))),
                ]),
                if (((r['prizes'] as List?) ?? []).isNotEmpty) Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('🏆 ${((r['prizes'] as List).map((p) => withPrizeIcon(prizeIconOf(p as Map), '${isArabic ? p['prize_ar'] : p['prize_en']}'))).join(' · ')}',
                    style: const TextStyle(color: Color(0xFFFFB300), fontSize: 12.5, fontWeight: FontWeight.w800))),
                const SizedBox(height: 8),
                for (final m in (r['matches'] as List? ?? []))
                  _matchCard(FantasyMatch.fromJson({
                    'match_id': '', 'kickoff_at': m['at'],
                    'home': m['home'], 'away': m['away'],
                  })),
                const SizedBox(height: 14),
              ],
            ]);
          },
        ),
      ),
    );
  }

  /// كارت واحد صغير: الوقت (أو الحالة) + الجوايز في سطر
  Widget _lobbyInfoCard(FantasyEvent event) {
    final ph = phaseOf(event);
    final left = _timeLeft;
    String pad(int n) => n.toString().padLeft(2, '0');
    final d = left.inDays, h = left.inHours.remainder(24), m = left.inMinutes.remainder(60), s = left.inSeconds.remainder(60);
    final (IconData ic, Color c, String title, String sub) = switch (ph) {
      'open' => (Icons.timer_outlined, Brand.green,
                 '${d > 0 ? t('${d}d ', '$dي ') : ''}${pad(h)}:${pad(m)}:${pad(s)}',
                 t('Team selection closes · ${_fmtDeadline(event.deadlineAt)} ${_fmtDate(event.deadlineAt)}',
                   'اختيار الفريق بيتقفل · ${_fmtDeadline(event.deadlineAt)} ${_fmtDate(event.deadlineAt)}')),
      'live' => (Icons.lock_rounded, const Color(0xFFFF5C5C),
                 t('Teams locked · matches on', 'التشكيلات اتقفلت · الماتشات شغالة'),
                 t('Results on Thursday night', 'النتايج يوم الخميس بالليل')),
      _      => (Icons.flag_rounded, Colors.white70,
                 _myRank?['rank'] != null ? t('You finished #${_myRank!['rank']}', 'ترتيبك #${_myRank!['rank']}') : t('Round finished', 'الجولة خلصت'),
                 _myRank?['rank'] != null
                   ? t('${(_myRank!['total_points'] as num?)?.toStringAsFixed(0) ?? 0} pts · of ${_myRank!['total_players']} players', '${(_myRank!['total_points'] as num?)?.toStringAsFixed(0) ?? 0} نقطة · من ${_myRank!['total_players']} لاعب')
                   : t('The next round opens on Friday', 'الجولة الجاية بتفتح يوم الجمعة')),
    };
    const medals = {1: '🥇', 2: '🥈', 3: '🥉'};
    const gold = Color(0xFFFFB300);
    String place(int r) => isArabic
        ? (const {1: 'الأول', 2: 'التاني', 3: 'التالت'}[r] ?? 'رقم $r')
        : (const {1: '1st', 2: '2nd', 3: '3rd'}[r] ?? '${r}th');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.withOpacity(0.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // الديدلاين + حالة الجولة
        Row(children: [
          Icon(ic, color: c, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: ph == 'open' ? Colors.white : c, fontSize: ph == 'open' ? 20 : 14.5,
                fontWeight: FontWeight.w900, fontFeatures: const [FontFeature.tabularFigures()])),
            Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 11.5)),
          ])),
          const SizedBox(width: 8),
          _phasePill(ph),
        ]),
        // الجوايز (كل مركز في سطر) + الراعي جنبها في المساحة الفاضية: لوجو + اسمه (الأونر، 21 نوفمبر)
        ValueListenableBuilder<int>(
          valueListenable: Ads.version,
          builder: (_, __, ___) {
            final ad = _roundSponsorAd(event);
            final prizes = event.prizes.isEmpty ? null : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.emoji_events_rounded, color: gold, size: 16),
                const SizedBox(width: 6),
                Text(t('PRIZES', 'الجوايز'), style: const TextStyle(color: gold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
              ]),
              const SizedBox(height: 4),
              for (final p in event.prizes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: Row(children: [
                    SizedBox(width: 26, child: Text(medals[p.rank] ?? '🏅', style: const TextStyle(fontSize: 17))),
                    SizedBox(width: 44, child: Text(place(p.rank), style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700))),
                    Expanded(child: Text(p.text(isArabic), maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.rank == 1 ? gold : Colors.white, fontSize: p.rank == 1 ? 16 : 14.5, fontWeight: FontWeight.w900))),
                  ]),
                ),
            ]);
            if (prizes == null && ad == null) return const SizedBox.shrink();
            return Column(mainAxisSize: MainAxisSize.min, children: [
              const Padding(padding: EdgeInsets.symmetric(vertical: 9), child: Divider(height: 1, color: line)),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                if (prizes != null) Expanded(child: prizes) else const Spacer(),
                if (ad != null) ...[
                  const SizedBox(width: 10),
                  _sponsorBlock(ad),
                ],
              ]),
            ]);
          },
        ),
      ]),
    );
  }

  /// راعي الجولة: واحد بس على صفحة الجولة (الأونر، 21 نوفمبر).
  /// بياخد أول حملة موجودة بالترتيب ده: بانر الجولة ← "الجولة برعاية" ← "الجوايز مقدّمة من".
  AdItem? _roundSponsorAd(FantasyEvent event) {
    Ads.ensure();
    for (final pl in const ['fantasy_lobby_banner', 'fantasy_round_title', 'fantasy_prize']) {
      final ad = Ads.pick(pl, eventId: event.eventId);
      if (ad != null) return ad;
    }
    return null;
  }

  /// "Sponsored by" + اللوجو + الاسم تحته + "إعلان" — الدوسة بتفتح كارت الإعلان الكبير (كام ثانية وبيتقفل)
  Widget _sponsorBlock(AdItem a) => AdImpression(
        ad: a,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showAdModal(context, a),
          child: Container(
            width: 96,
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(t('Sponsored by', 'برعاية'), maxLines: 1,
                  style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              AdLogo(a, size: 40),
              const SizedBox(height: 6),
              Text(a.sponsorName ?? a.title ?? '', maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900, height: 1.2)),
              const SizedBox(height: 5),
              AdLabel(demo: a.demo, onDark: false),
            ]),
          ),
        ),
      );

  String _dayLabel(DateTime dt) {
    final en = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
    final ar = ['الأحد','الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت'];
    return isArabic ? ar[dt.weekday % 7] : en[dt.weekday % 7];
  }

  String _fmtDeadline(DateTime dt) {
    final en = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
    final ar = ['أحد','اثنين','ثلاثاء','أربعاء','خميس','جمعة','سبت'];
    final day  = isArabic ? ar[dt.weekday % 7] : en[dt.weekday % 7];
    final h    = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m    = dt.minute.toString().padLeft(2,'0');
    final ampm = dt.hour >= 12 ? (isArabic ? 'م' : 'PM') : (isArabic ? 'ص' : 'AM');
    return '$day, $h:$m $ampm';
  }

  String _fmtDate(DateTime dt) {
    const en = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const ar = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    final d = dt.toLocal();
    return '${d.day} ${isArabic ? ar[d.month - 1] : en[d.month - 1]}';
  }

  Widget _phasePill(String ph) {
    final (Color c, String label) = switch (ph) {
      'open'     => (Brand.green,              t('Open', 'مفتوحة')),
      'live'     => (const Color(0xFFFF5C5C),   t('Live', 'شغالة')),
      _          => (Colors.white54,           t('Finished', 'خلصت')),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.5))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, color: c, size: 8),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _statusCard({required IconData icon, required Color color, required String title,
      required String body, Widget? extra}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.45))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: const TextStyle(color: Colors.white,
            fontSize: 15, fontWeight: FontWeight.w900))),
      ]),
      const SizedBox(height: 6),
      Text(body, style: const TextStyle(color: Color(0xFFCFCFCF), fontSize: 13, height: 1.4)),
      if (extra != null) ...[const SizedBox(height: 10), extra],
    ]),
  );

  Widget _liveCard() => _statusCard(
    icon: Icons.lock_rounded, color: const Color(0xFFFF5C5C),
    title: t('Teams are locked — matches are on', 'التشكيلات اتقفلت — الماتشات شغالة'),
    body: t('Points are added after the matches. Check your rank when the round finishes.',
            'النقط بتتحسب بعد الماتشات. شوف ترتيبك لما الجولة تخلص.'),
  );

  Widget _finishedCard() {
    final r = _myRank;
    Widget? extra;
    if (r != null && r['rank'] != null) {
      extra = Row(children: [
        _miniStat(t('Your rank', 'ترتيبك'), '#${r['rank']}'),
        const SizedBox(width: 8),
        _miniStat(t('Your points', 'نقطك'), '${(r['total_points'] as num?)?.toStringAsFixed(0) ?? '0'}'),
        const SizedBox(width: 8),
        _miniStat(t('Players', 'اللاعبين'), '${r['total_players'] ?? '-'}'),
      ]);
    }
    return _statusCard(
      icon: Icons.flag_rounded, color: Colors.white70,
      title: t('This round is over', 'الجولة دي خلصت'),
      body: r == null
          ? t('The next round will appear here once it opens.', 'الجولة الجاية هتظهر هنا أول ما تتفتح.')
          : t('Here is how you did. The next round will appear here once it opens.',
              'دي نتيجتك. الجولة الجاية هتظهر هنا أول ما تتفتح.'),
      extra: extra,
    );
  }

  Widget _miniStat(String label, String value) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(color: const Color(0xFF0E0E12), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: line)),
    child: Column(children: [
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(color: muted, fontSize: 10.5)),
    ]),
  ));

  /// الجوايز: واضحة ومحفّزة
  Widget _prizesCard(List<FantasyPrize> prizes) {
    const medals = {1: '🥇', 2: '🥈', 3: '🥉'};
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2A2210), Color(0xFF16140E)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x66FFB300)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFB300), size: 20),
          const SizedBox(width: 8),
          Text(t('Prizes', 'الجوايز'), style: const TextStyle(color: Colors.white,
              fontSize: 15, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 8),
        for (final p in prizes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Text(medals[p.rank] ?? '🏅', style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(child: Text(isArabic ? p.labelAr : p.labelEn,
                  style: const TextStyle(color: Color(0xFFCFCFCF), fontSize: 13))),
              Text(p.text(isArabic), style: const TextStyle(
                  color: Color(0xFFFFB300), fontSize: 15, fontWeight: FontWeight.w900)),
            ]),
          ),
      ]),
    );
  }

  /// "⇄ التحويل لـ عالمي": بيوديك على صفحة جولة الساحة التانية (نفس الصفحة)
  Widget _switchArenaButton() {
    final other = arena == 'EGYPT' ? 'WORLD' : 'EGYPT';
    final otherEvent = other == 'EGYPT' ? _localEvent : _worldEvent;
    if (otherEvent == null) return const SizedBox(height: 4);
    final name = other == 'EGYPT' ? t('Egypt', 'مصر') : t('World', 'عالمي');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: () => enterArena(other),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.swap_horiz, color: Brand.green, size: 16),
            const SizedBox(width: 6),
            Text(t('Switch to $name', 'التحويل لـ $name'),
                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  /// عدّاد الديدلاين: بيقل كل ثانية (أيام لو فاضل أكتر من 24 ساعة)
  Widget _deadlineCountdown(DateTime deadline) {
    final left = _timeLeft;
    final closed = deadlinePassed;
    final d = left.inDays, h = left.inHours.remainder(24),
          m = left.inMinutes.remainder(60), s = left.inSeconds.remainder(60);
    String pad(int n) => n.toString().padLeft(2, '0');

    Widget box(String value, String label) => Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(color: const Color(0xFF0E0E12), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: line)),
      child: Column(children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 26,
            fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: muted, fontSize: 10, letterSpacing: 0.5)),
      ]),
    ));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: closed
            ? [const Color(0xFF2A1414), cardBg]
            : [const Color(0xFF12241A), cardBg],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: closed ? const Color(0x66FF5C5C) : const Color(0x5500FF87)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(closed ? Icons.lock_rounded : Icons.timer_outlined,
              color: closed ? const Color(0xFFFF5C5C) : Brand.green, size: 18),
          const SizedBox(width: 6),
          Text(closed ? t('Team selection closed', 'اختيار الفريق اتقفل')
                      : t('Team selection closes in', 'اختيار الفريق بيتقفل بعد'),
              style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)),
        ]),
        if (!closed) ...[
          const SizedBox(height: 10),
          Row(children: [
            if (d > 0) box('$d', d == 1 ? t('DAY', 'يوم') : t('DAYS', 'أيام')),
            box(pad(h), t('HRS', 'ساعة')),
            box(pad(m), t('MIN', 'دقيقة')),
            box(pad(s), t('SEC', 'ثانية')),
          ]),
        ],
        const SizedBox(height: 8),
        Text('${_fmtDeadline(deadline)} · ${_fmtDate(deadline)}',
            style: const TextStyle(color: muted, fontSize: 12)),
      ]),
    );
  }

  String _fmtTime(DateTime dt) {
    final h    = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m    = dt.minute.toString().padLeft(2,'0');
    final ampm = dt.hour >= 12 ? (isArabic ? 'م' : 'PM') : (isArabic ? 'ص' : 'AM');
    return '$h:$m $ampm';
  }

  Widget infoCard(IconData icon, String label, String value) =>
    Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(13), border: Border.all(color: line)),
      child: Row(children: [
        Icon(icon, color: sage, size: 22), const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: muted, fontSize: 10, letterSpacing: 0.5)),
          const SizedBox(height: 3),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))),
        ])),
      ]));

  Widget _matchCard(FantasyMatch match) {
    final started = DateTime.now().isAfter(match.kickoffAt);
    return GestureDetector(
    onTap: started ? () => openMatchSheet(context, match.matchId) : null,
    child: Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(15), border: Border.all(color: line)),
    child: Row(children: [
      Expanded(child: _teamWidget(isArabic ? match.homeNameAr : match.homeNameEn, match.homeLogoUrl, true, match.homeNameEn)),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (match.finished)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(8)),
            child: Text('${match.homeScore ?? 0} - ${match.awayScore ?? 0}', textDirection: TextDirection.ltr,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)))
        else
          const Text('VS', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(match.finished ? t('Full time', 'انتهت') : (started ? t('Result soon', 'النتيجة قريب') : _fmtTime(match.kickoffAt)),
          style: TextStyle(color: match.finished ? muted : sage, fontSize: 10, fontWeight: FontWeight.bold)),
      ])),
      Expanded(child: _teamWidget(isArabic ? match.awayNameAr : match.awayNameEn, match.awayLogoUrl, false, match.awayNameEn)),
    ])));
  }

  Widget _teamWidget(String name, String? logoUrl, bool home, [String? nameEn]) => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 40, height: 40,
      decoration: BoxDecoration(color: const Color(0xFF242424), borderRadius: BorderRadius.circular(12)),
      child: logoUrl != null && logoUrl.isNotEmpty
        ? ClipRRect(borderRadius: BorderRadius.circular(10),
            child: _netImage(logoUrl, fit: BoxFit.contain,
              fallback: Center(child: TeamInitialsCrest(name: nameEn ?? name, size: 30))))
        : Center(child: TeamInitialsCrest(name: nameEn ?? name, size: 30))),
    const SizedBox(height: 6),
    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
    const SizedBox(height: 2),
    Text(home ? t('HOME','هوم') : t('AWAY','أواي'), style: const TextStyle(color: muted, fontSize: 9, letterSpacing: 1)),
  ]);

  // ─────────────────────────────────────────────────────────────────────────
  // SQUAD BUILDER
  // ─────────────────────────────────────────────────────────────────────────
  Widget buildSquadScreen() {
    // أول لاعب اتختار = النصيحة اتفهمت، ما تظهرش تاني
    if (_showPitchTip && selectedCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _dismissPitchTip());
    }
    return LayoutBuilder(key: const ValueKey('squad'), builder: (context, constraints) {
      return Column(children: [
        Container(color: bg, padding: const EdgeInsets.fromLTRB(16, 10, 16, 8), child: Column(children: [
          backHeader(
            label: isArabic ? currentEvent?.nameAr ?? '' : currentEvent?.nameEn ?? '',
            onBack: () => setState(() { step = 1; saved = false; })),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _statCard(Icons.account_balance_wallet_outlined, t('REMAINING','المتبقي'), _fmtBudget(remaining))),
            const SizedBox(width: 8),
            Expanded(child: _statCard(Icons.people_alt_outlined, t('SELECTED','المختارون'), '$selectedCount / 11')),
          ]),
          const SizedBox(height: 8),
          Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: deadlinePassed ? surface2 : cardBg, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: deadlinePassed ? Colors.red.withOpacity(0.4) : line)),
            child: Row(children: [
              Icon(Icons.timer, color: deadlinePassed ? Colors.red : sage, size: 16), const SizedBox(width: 8),
              Text(t('Deadline in','الديدلاين بعد'), style: const TextStyle(color: muted, fontSize: 11)),
              const SizedBox(width: 6),
              Text(countdownText, style: TextStyle(color: deadlinePassed ? Colors.red : Colors.white,
                fontSize: 13, fontWeight: FontWeight.w900)),
            ])),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: SizedBox(height: 42, child: ElevatedButton(
              onPressed: () => _openPlayersPage(),
              style: ElevatedButton.styleFrom(backgroundColor: brandRed, foregroundColor: Colors.white, elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: FittedBox(child: Text(t('👥 All players', '👥 كل اللاعيبة'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)))))),
            const SizedBox(width: 8),
            Expanded(child: SizedBox(height: 42, child: OutlinedButton.icon(
              onPressed: _playersLoading ? null : autoPick,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: _playersLoading ? const SizedBox(width:14, height:14, child: CircularProgressIndicator(color: muted, strokeWidth: 2)) : const Icon(Icons.auto_fix_high, size: 16),
              label: FittedBox(child: Text(t('AUTO','تلقائي'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.6)))))),
            const SizedBox(width: 8),
            Expanded(child: SizedBox(height: 42, child: DropdownButtonHideUnderline(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(10), border: Border.all(color: line)),
              child: DropdownButton<String>(value: formation, dropdownColor: cardBg, isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, color: muted, size: 20),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                items: formations.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: (v) { if (v != null) changeFormation(v); }))))),
          ]),
        ])),
        if (_showPitchTip && selectedCount == 0) _pitchTip(),
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: buildPitch())),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: SizedBox(width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: canSave && !_saving ? saveSquad : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canSave ? brandRed : surface2,
              foregroundColor: canSave ? Colors.white : muted,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _saving
              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
              : Text(deadlinePassed ? t('DEADLINE PASSED','انتهى الديدلاين') : t('SAVE TEAM','حفظ الفريق'),
                  style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8))))),
      ]);
    });
  }

  Widget _pitchTip() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: const Color(0x1A00FF87),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x5500FF87)),
      ),
      child: Row(children: [
        const Icon(Icons.touch_app, color: Brand.green, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(
          t('Tap any empty spot to pick a player — or use AUTO PICK.',
            'دوس على أي مكان فاضي عشان تختار لاعب، أو استخدم التعبئة التلقائي.'),
          style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.35))),
        IconButton(
          onPressed: _dismissPitchTip,
          icon: const Icon(Icons.close, color: Colors.white54, size: 18),
          visualDensity: VisualDensity.compact,
        ),
      ]),
    ),
  );

  Widget _statCard(IconData icon, String label, String value) =>
    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: line)),
      child: Row(children: [
        Icon(icon, color: sage, size: 18), const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: muted, fontSize: 9, letterSpacing: 0.5)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
        ])),
      ]));

  // ─────────────────────────────────────────────────────────────────────────
  // MY SQUAD VIEW
  // ─────────────────────────────────────────────────────────────────────────
  Widget buildMySquadView() => LayoutBuilder(key: const ValueKey('mysquad'), builder: (context, _) {
    return Column(children: [
      Container(color: bg, padding: const EdgeInsets.fromLTRB(16, 10, 16, 10), child: Column(children: [
        backHeader(
          label: isArabic ? currentEvent?.nameAr ?? '' : currentEvent?.nameEn ?? '',
          onBack: () => setState(() => step = 1)),
        const SizedBox(height: 10),
        if (phaseOf(currentEvent) != 'open')
          // اتقفلت: مفيش تعديل خالص
          Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: line)),
            child: Row(children: [
              const Icon(Icons.lock_rounded, color: Colors.white70, size: 18), const SizedBox(width: 8),
              Expanded(child: Text(
                phaseOf(currentEvent) == 'finished'
                  ? t('Round finished · your final team', 'الجولة خلصت · دي تشكيلتك النهائية')
                  : t('Team locked · results Thursday 9 PM', 'التشكيلة اتقفلت · النتايج الخميس 9 بالليل'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5))),
            ]))
        else
          // launch (owner 27 Nov): one slim line — saved ✓ · tie rule (ⓘ) · small Edit pill — so the pitch gets the space
          Row(children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 18), const SizedBox(width: 6),
            Text(t('Team saved', 'الفريق متسجل'), style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(width: 4),
            IconButton(onPressed: () => showTieBreakSheet(context, isArabic, period: 'round', draft: isDraft),
              tooltip: t('If you tie on points', 'لو اتعادلت في النقط'),
              icon: const Icon(Icons.balance_rounded, color: Colors.white38, size: 17),
              visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
            const Spacer(),
            Pressable(child: GestureDetector(onTap: () => setState(() => saved = false),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(20), border: Border.all(color: line)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.edit_rounded, color: Colors.white70, size: 14), const SizedBox(width: 5),
                  Text(t('Edit', 'تعديل'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                ])))),
          ]),
        if (isDraft && _predMatches.isNotEmpty) ...[const SizedBox(height: 8), this.d7MyPredStrip()],
        if (phaseOf(currentEvent) != 'open' && currentEvent != null && _sb.auth.currentUser != null) ...[
          const SizedBox(height: 8),
          SquadSocialBar(key: ValueKey('soc_${currentEvent!.eventId}_$isDraft'), eventId: currentEvent!.eventId,
            userId: _sb.auth.currentUser!.id, draft: isDraft, isArabic: isArabic),
        ],
      ])),
      Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: (formation == '4-5-1' || isDraft) ? this.buildPitchV2(readOnly: true) : buildPitch(readOnly: true))),
      // WORLD bench under the pitch (edit until the deadline; saved at once)
      if (this._benchOn) Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: this._benchRow(editable: phaseOf(currentEvent) == 'open', autoSave: true)),
    ]);
  });

  // ─────────────────────────────────────────────────────────────────────────
  // PITCH
  // ─────────────────────────────────────────────────────────────────────────
  Widget buildPitch({bool readOnly = false, bool empty = false, String? target}) {
    Diag.step('buildPitch arena=$arena ro=$readOnly players=${pickedPlayers.length} f=$formation kits=${_kits.length}');
    final rows = empty ? <MapEntry<String, int>>[] : <MapEntry<String, int>>[
      MapEntry('FWD', slotCount('FWD')), MapEntry('MID', slotCount('MID')),
      MapEntry('DEF', slotCount('DEF')), const MapEntry('GK', 1),
    ];
    // Stadium look (fantasy_stadium.dart): tilted pitch, far line smaller, crowd + floodlights,
    // LED ad board on the far edge (placement fantasy_pitch_board, each ad for its own seconds).
    return ValueListenableBuilder<int>(valueListenable: Diag.stage, builder: (context, _, __) =>
      ValueListenableBuilder<int>(valueListenable: Ads.version, builder: (context, _, __) {
      final ads = Ads.candidates('fantasy_pitch_board', eventId: currentEvent?.eventId);
      return StadiumPitch(
        rowCount: rows.length,
        board: ads.isEmpty ? null : LedBoard(
          key: ValueKey(ads.map((a) => a.id).join('|')),
          count: ads.length,
          secondsOf: (i) => ads[i].boardS ?? 8,
          itemBuilder: (c, i) => _boardItem(ads[i])),
        rowBuilder: (i, w, h) {
          final shirt = (h - 36).clamp(28.0, 50.0).toDouble();
          final cardW = (w / 5 - 4).clamp(52.0, 70.0).toDouble();
          return Center(child: FittedBox(fit: BoxFit.scaleDown,
            child: SizedBox(width: w - 8, child: _positionRow(rows[i].key, rows[i].value, shirt, cardW, readOnly: readOnly,
              start: rows.take(i).fold<int>(0, (a, r) => a + r.value), target: target))));
        });
    }));
  }

  Widget _boardItem(AdItem a) => AdImpression(ad: a, child: GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => onAdBannerTap(context, a),
    child: (a.template == 'banner' && a.media != null)
      ? Stack(fit: StackFit.expand, children: [
          AdMedia(a),
          Positioned(right: 3, top: 0, bottom: 0, child: Center(child: AdLabel(demo: a.demo))),
        ])
      : Container(color: a.bg ?? Colors.black, padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(children: [
            const Spacer(),
            AdLogo(a, size: 16),
            const SizedBox(width: 7),
            Flexible(flex: 6, child: Text(a.displayName.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: a.fg ?? Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 2))),
            const Spacer(),
            AdLabel(demo: a.demo),
          ]))));

  Widget _positionRow(String pos, int count, double avatar, double cardW, {bool readOnly = false, int start = 0, String? target}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: List.generate(count, (index) {
      final player = squad[pos]![index];
      final card = _pitchCard(player, pos, cardW, avatar, start + index);
      // v2 builder: the slot has a key (flight target); the next empty slots pulse; a landed player gets a ring
      final slot = readOnly ? card : KeyedSubtree(key: _slotKeys.putIfAbsent('${pos}_$index', () => GlobalKey()),
        child: player == null
          ? (target == pos ? _TargetPulse(child: card) : Opacity(opacity: target == null ? 1 : 0.55, child: card))
          : (player.id == _landedId ? _LandingRing(key: ValueKey('land_${player.id}'), child: card) : card));
      return Expanded(child: Center(child: DropIn(
        key: ValueKey('drop_${pos}_${index}_${player?.id}'),
        enabled: player != null && !_flown.contains(player.id),
        delay: Duration(milliseconds: 70 * index),
        child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: readOnly
          ? (player != null ? () => _openPlayerInfoDialog(player) : null)
          : (player == null ? null : () => _openPlayerDialog(pos, index)),
        child: slot,
      ))));
    }));

  /// pitch strips text, by app_settings.fantasy_pitch_name (no build):
  /// split = first name / rest of the name · full_club = whole name / club · short_club = name cut with … / club
  (String, String) _pitchLines(FancyPlayer p) {
    final name = (isArabic ? p.nameAr : p.nameEn).trim();
    final club = isArabic ? p.teamNameAr : p.teamNameEn;
    if (_pitchName == 'split') {
      final i = name.indexOf(' ');
      if (i > 0) return (name.substring(0, i), name.substring(i + 1).trim());
      return (name, club);
    }
    return (name, club);
  }

  /// one line: shrinks to fit (fit = true) or cuts with … (fit = false)
  Widget _stripText(String s, {required bool fit, required TextStyle style}) => fit
      ? FittedBox(fit: BoxFit.scaleDown, child: Text(s, maxLines: 1, style: style))
      : Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);

  /// FPL-style card: team shirt (drawn) + name strip + price strip. Photo shows in the player dialog.
  Widget _pitchCard(FancyPlayer? p, String pos, double w, double shirtH, [int gi = 0]) {
    // diag-3: show the pieces of card #gi one at a time (Diag.stage 999 = everything)
    final st = Diag.stage.value;
    final showShirt = st >= gi * 3 + 1, showStrips = st >= gi * 3 + 2, showCrest = st >= gi * 3 + 3;
    Diag.cardInfo[gi] = '$pos ${p?.teamId}';
    final isCap = p != null && captain == p;
    final kit = p == null ? null : _kits[p.teamId];
    final shirtW = math.min(w * 0.80, shirtH * 1.05);
    final logo = p?.teamId == null ? null : teamLogos[p!.teamId];
    Diag.step('card $pos ${p?.teamId} kit=${kit?.pattern}/${kit?.img != null} logo=$logo');
    final Widget shirtPic = p == null
        ? KitShirt(c1: const Color(0x2EFFFFFF), c2: Colors.white70, pattern: 'ghost', width: shirtW)
        : (kit?.img != null
            // real shirt photo (cached on the phone); drawn shirt while loading / on error
            ? _kitPhoto(kit!.img!, shirtW * 1.08, shirtH,
                KitShirt(c1: kit.c1, c2: kit.c2, pattern: kit.pattern, width: shirtW))
            : KitShirt(c1: kit?.c1 ?? const Color(0xFF8A8F98), c2: kit?.c2 ?? Colors.white, pattern: kit?.pattern ?? 'plain', width: shirtW));
    // app_settings.fantasy_pitch_image = photo → the player's picture on his spot (shirt if none / while loading / on error)
    final pImg = (p == null || _pitchImage != 'photo') ? null : (p.imageUrl ?? p.fullImageUrl);
    final Widget pic = (pImg == null || pImg.toLowerCase().contains('.svg')) ? shirtPic
        : SizedBox(width: shirtH * 0.95, height: shirtH, child: ClipRRect(borderRadius: BorderRadius.circular(8),
            child: Image(image: ResizeImage(MediaCache.image(pImg), width: 160, allowUpscaling: false),
              fit: BoxFit.cover, alignment: Alignment.topCenter, gaplessPlayback: true,
              loadingBuilder: (_, child, pr) => pr == null ? child : Center(child: shirtPic),
              errorBuilder: (_, __, ___) => Center(child: shirtPic))));
    final top = SizedBox(width: w, height: shirtH, child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
      if (!showShirt) const SizedBox.shrink() else pic,
      if (p == null) Icon(Icons.add_rounded, color: Colors.white, size: shirtW * 0.42),
      if (logo != null && showCrest) Positioned(bottom: 0, right: (w - shirtW) / 2 - 3,
        child: Container(width: 17, height: 17, padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 3)]),
          child: ClipOval(child: _SafeCrest(logo, size: 14)))),
      if (isCap && showShirt) Positioned(top: -2, left: (w - shirtW) / 2 - 4,
        child: Container(width: 17, height: 17,
          decoration: BoxDecoration(color: captainColor, shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 1)),
          child: const Center(child: Text('C', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900, height: 1))))),
    ]));
    final lines = p == null ? ('', '') : _pitchLines(p);
    final strips = ClipRRect(borderRadius: BorderRadius.circular(5), child: SizedBox(width: w, height: 28, child: Column(children: [
      Container(height: 15, width: w, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 3),
        color: p == null ? const Color(0xD9000000) : Colors.white,
        child: _stripText(p != null ? lines.$1 : pos, fit: p != null && _pitchName != 'short_club',
          style: TextStyle(color: p == null ? Colors.white70 : Colors.black, fontSize: 9.5, fontWeight: FontWeight.w800, height: 1.1))),
      Container(height: 13, width: w, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 3),
        color: const Color(0xF2141418),
        // v2: no prices → the club name (or the rest of the name in "split") in the dark strip
        child: _stripText(p == null ? '' : lines.$2, fit: _pitchName == 'split',
          style: TextStyle(color: _pitchName == 'split' ? Colors.white : mint, fontSize: 8.5, fontWeight: FontWeight.w700, height: 1.1))),
    ])));
    return SizedBox(width: w, child: Column(mainAxisSize: MainAxisSize.min, children: [
      top,
      const SizedBox(height: 3),
      !showStrips ? SizedBox(width: w, height: 28) : isCap ? CaptainShine(size: w, height: 28, radius: 5, color: captainColor, child: strips) : strips,
    ]));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PLAYER PICKER
  // ─────────────────────────────────────────────────────────────────────────
  // v2: "بدّل" = empty the spot, so that line opens again in the cards under the pitch
  void _openPlayerPicker(String pos, int index) {
    setState(() {
      final cur = squad[pos]![index];
      if (cur != null && captain == cur) captain = null;
      squad[pos]![index] = null;
      saved = false;
    });
    squadTick.value++;
  }

  void _openPlayerInfoDialog(FancyPlayer player) {
    final isCap = captain == player;
    showDialog<void>(context: context, barrierColor: Colors.black.withOpacity(0.72),
      builder: (dctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Stack(clipBehavior: Clip.none, children: [
          Container(width: double.infinity,
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(22), border: Border.all(color: line)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                child: (player.fullImageUrl ?? player.photoUrl) != null
                  ? AspectRatio(aspectRatio: 3/4,
                      child: _netImage((player.fullImageUrl ?? player.photoUrl)!, fit: BoxFit.cover,
                        fallback: _playerShirtHero(player)))
                  : SizedBox(height: 190, width: double.infinity, child: _playerShirtHero(player))),
              if (isCap) Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 6),
                color: captainColor.withOpacity(0.15),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.star, color: captainColor, size: 14),
                  const SizedBox(width: 4),
                  Text(t('Captain','كابتن'), style: const TextStyle(color: captainColor, fontSize: 12, fontWeight: FontWeight.w900)),
                ])),
              Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 20), child:
                Column(children: [
                  Text(isArabic ? player.nameAr : player.nameEn, textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('${isArabic ? player.teamNameAr : player.teamNameEn}  •  ${this._v2PosLabel(player)}',
                    style: const TextStyle(color: muted, fontSize: 12)),
                  const SizedBox(height: 8),
                  const SizedBox.shrink(), // v2: no prices
                ])),
            ])),
          Positioned(top: -14, right: -14, child: GestureDetector(onTap: () => Navigator.pop(dctx),
            child: Container(width: 30, height: 30,
              decoration: BoxDecoration(color: surface2, shape: BoxShape.circle, border: Border.all(color: line)),
              child: const Icon(Icons.close, color: muted, size: 16)))),
        ])));
  }

  void _openPlayerDialog(String pos, int index) {
    final player = squad[pos]![index];
    if (player == null) return;
    showDialog<void>(context: context, barrierColor: Colors.black.withOpacity(0.72),
      builder: (dctx) {
        final isCap = captain == player;
        return Dialog(backgroundColor: Colors.transparent, insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Stack(clipBehavior: Clip.none, children: [
            Container(width: double.infinity,
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(22), border: Border.all(color: line)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // ── full card image (3/4) ──
                ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  child: (player.fullImageUrl ?? player.photoUrl) != null
                    ? AspectRatio(aspectRatio: 3/4,
                        child: _netImage((player.fullImageUrl ?? player.photoUrl)!, fit: BoxFit.cover,
                          fallback: _playerShirtHero(player)))
                    : SizedBox(height: 190, width: double.infinity, child: _playerShirtHero(player))),
                // ── captain ring ──
                if (isCap) Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 6),
                  color: captainColor.withOpacity(0.15),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.star, color: captainColor, size: 14),
                    const SizedBox(width: 4),
                    Text(t('Captain','كابتن'), style: const TextStyle(color: captainColor, fontSize: 12, fontWeight: FontWeight.w900)),
                  ])),
                // ── info ──
                Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 20), child:
                  Column(children: [
                    Text(isArabic ? player.nameAr : player.nameEn, textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('${isArabic ? player.teamNameAr : player.teamNameEn}  •  ${this._v2PosLabel(player)}',
                      style: const TextStyle(color: muted, fontSize: 12)),
                    const SizedBox(height: 6),
                    const SizedBox.shrink(), // v2: no prices
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(child: SizedBox(height: 46, child: OutlinedButton.icon(
                        onPressed: () { Navigator.pop(dctx); _openPlayerPicker(pos, index); },
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: line),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: Text(t('Swap','بدّل'), style: const TextStyle(fontWeight: FontWeight.w700))))),
                      const SizedBox(width: 10),
                      Expanded(child: SizedBox(height: 46, child: ElevatedButton.icon(
                        onPressed: () { setState(() { captain = isCap ? null : player; saved = false; }); Navigator.pop(dctx); },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCap ? captainColor : surface2,
                          foregroundColor: isCap ? Colors.black : Colors.white, elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        icon: const Icon(Icons.star, size: 18),
                        label: Text(isCap ? t('Remove C','شيل C') : t('Captain','كابتن'),
                          style: const TextStyle(fontWeight: FontWeight.w700))))),
                    ]),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, height: 46, child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() { if (captain == player) captain = null; squad[pos]![index] = null; saved = false; });
                        Navigator.pop(dctx);
                      },
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      label: Text(t('Remove','شيل'), style: const TextStyle(fontWeight: FontWeight.w700)))),
                  ])),
              ])),
            Positioned(top: -14, right: -14, child: GestureDetector(onTap: () => Navigator.pop(dctx),
              child: Container(width: 30, height: 30,
                decoration: BoxDecoration(color: surface2, shape: BoxShape.circle, border: Border.all(color: line)),
                child: const Icon(Icons.close, color: muted, size: 16)))),
          ]));
      });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TOUR OVERLAY
  // ─────────────────────────────────────────────────────────────────────────
  Widget buildTourOverlay() {
    final card   = tourCards[tourIndex];
    final isLast = tourIndex == tourCards.length - 1;
    final title  = isArabic ? card.titleAr : card.titleEn;
    final lines  = isArabic ? card.linesAr : card.linesEn;
    return Positioned.fill(child: Stack(children: [
      Positioned.fill(child: GestureDetector(onTap: () {}, child: Container(color: Colors.black.withOpacity(0.55)))),
      Align(alignment: Alignment.bottomCenter, child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: line)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${tourIndex + 1} / ${tourCards.length}', style: const TextStyle(color: muted, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            ...lines.map((l) => Padding(padding: const EdgeInsets.only(bottom: 5),
              child: Text('• $l', style: const TextStyle(color: Color(0xFFD4D4D4), fontSize: 13.5, height: 1.45)))),
            const SizedBox(height: 14),
            Row(children: [
              TextButton(onPressed: skipTour, child: Text(t('SKIP','تخطي'), style: const TextStyle(color: muted, fontSize: 12))),
              const Spacer(),
              SizedBox(height: 42, child: ElevatedButton(onPressed: nextTour,
                style: ElevatedButton.styleFrom(backgroundColor: brandRed, foregroundColor: Colors.white, elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
                child: Text(isLast ? t('GOT IT','فهمت') : t('NEXT','التالي'),
                  style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6)))),
            ]),
          ])))),
    ]));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELP SHEET
  // ─────────────────────────────────────────────────────────────────────────
  void openHelpSheet() {
    _dismissHelpHint();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FantasyHelpSheet(
        isArabic: isArabic,
        budget: initialBudget,
        onToggleLanguage: () => widget.onLanguageToggle?.call(),
      ),
    );
  }

  Widget _helpSection(String title, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: line)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: sage, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8), ...children]));

  Widget _helpLine(String text) => Padding(padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(color: Color(0xFFD4D4D4), fontSize: 13.5, height: 1.45)));

  // ─────────────────────────────────────────────────────────────────────────
  // BACK HEADER
  // ─────────────────────────────────────────────────────────────────────────
  // العنوان بياخد المساحة لحد زراير (ع/EN و ؟) اللي فوق على اليمين وما يدخلش تحتهم
  Widget backHeader({required String label, required VoidCallback onBack, Widget? title}) => Row(children: [
    IconButton(onPressed: onBack,
      style: IconButton.styleFrom(backgroundColor: cardBg, side: BorderSide(color: line)),
      icon: const Icon(Icons.arrow_back, color: Colors.white)),
    const SizedBox(width: 10),
    Expanded(child: title ?? Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6))),
    // زرار واحد يرجّعك تختار الساحة
    GestureDetector(
      onTap: () => setState(() { step = 0; saved = false; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(arena == 'EGYPT' ? '🇪🇬' : '🌍', style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(arena == 'EGYPT' ? t('Egypt', 'مصر') : t('World', 'عالمي'),
            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          const Icon(Icons.swap_horiz_rounded, color: Brand.green, size: 16),
        ]),
      ),
    ),
    SizedBox(width: widget.showTopButtons ? 136 : 0),   // مكان زراير ع/EN و ؟ (لو FancyPage لوحدها)
  ]);
}

// ═══════════════════════════════════════════════════════════════════════════
// FANTASY SHELL — wraps FancyPage with fantasy-specific bottom navigation
// Use this widget instead of FancyPage when embedding in the main app.
// ═══════════════════════════════════════════════════════════════════════════

class FantasyShell extends StatefulWidget {
  final VoidCallback? onExitFantasy;
  const FantasyShell({super.key, this.onExitFantasy});
  @override
  State<FantasyShell> createState() => _FantasyShellState();
}

class _FantasyShellState extends State<FantasyShell> {
  int _tab = 0;   // 0 فريقي · 1 الترتيب · 2 الليجز
  bool _helpPulse = false;   // أول مرة: "؟" بينبض لحد ما يدوس عليه
  bool _statsPulse = false;  // أول مرة: دايرة الإحصائيات بتنبض لحد ما يدوس عليها
  bool _inArena = false;     // جوه أرينا: التابات فوق بتختفي علشان الصفحة تبقى فاضية
  _FancyPageState? get _team => _teamKey.currentState is _FancyPageState ? _teamKey.currentState as _FancyPageState : null;
  /// compact round bar: "Current GW" + arena in the top bar while inside an arena
  bool get _gwBar => _FancyPageState._lobbyCompact && _inArena && _team != null;
  bool isArabic = AppLang.isArabic;   // لغة التطبيق

  /// عربي ⇄ English: بيتطبّق على كل صفحات الفانتازي وبيتحفظ كآخر اختيار
  void _toggleLanguage() {
    setState(() => isArabic = !isArabic);
    final lang = isArabic ? 'ar' : 'en';
    AppLang.set(lang);
    LocalStore.setLang(lang);
  }
  String t(String en, String ar) => isArabic ? ar : en;

  final _teamKey = GlobalKey<_FancyPageState>();

  // shared event loaded eagerly
  FantasyEvent? _sharedLocalEvent;
  FantasyEvent? _sharedWorldEvent;
  bool _eventsLoaded = false;

  FantasyEvent? get _currentEvent =>
    _teamKey.currentState?.currentEvent ??
    _sharedLocalEvent ??
    _sharedWorldEvent;

  // onboarding
  // صفحة الـ Onboarding اتلغت: اليوزر يدخل يلعب على طول
  bool _checkingFirstTime = false;
  bool _showOnboarding = false;
  int  _onboardPage = 0;

  bool _showIntro = false;   // launch: stadium intro, once per app run

  void _onTabActive() {
    if (!FantasyMotion.tabActive.value || FantasyMotion.introPlayed || !mounted) return;
    FantasyMotion.introPlayed = true;
    if (motionCalm(context)) { FantasyMotion.ready.value = true; return; }
    setState(() => _showIntro = true);
  }

  @override
  void dispose() {
    FantasyMotion.tabActive.removeListener(_onTabActive);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    FantasyMotion.tabActive.addListener(_onTabActive);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onTabActive());
    _loadSharedEvents();
    LocalStore.getFlag('fantasy_help_hint').then((seen) {
      if (mounted && !seen) setState(() => _helpPulse = true);
    });
    LocalStore.getFlag('fantasy_stats_hint').then((seen) {
      if (mounted && !seen) setState(() => _statsPulse = true);
    });
  }

  Future<void> _checkFirstTime() async {
    try {
      final res = await _sb.rpc('has_played_fantasy');
      if (mounted) setState(() {
        _showOnboarding = res == false;
        _checkingFirstTime = false;
      });
    } catch (_) {
      if (mounted) setState(() => _checkingFirstTime = false);
    }
  }

  void _finishOnboarding() => setState(() { _showOnboarding = false; _onboardPage = 0; });

  static const _onboardData = [
    (icon: '⚽', titleEn: 'Build Your Team', titleAr: 'ابني فريقك', bodyEn: 'Pick 11 players from the match pool within your budget.', bodyAr: 'اختار 11 لاعب من بول الماتشات في حدود الميزانية.'),
    (icon: '🏆', titleEn: 'Pick a Captain', titleAr: 'اختار كابتن', bodyEn: 'Your captain scores double points. Choose wisely.', bodyAr: 'الكابتن بتاعك بيجيب ضعف النقاط. اختار بعقلك.'),
    (icon: '📊', titleEn: 'Score Points', titleAr: 'اجمع نقاطك', bodyEn: 'Goals, assists, clean sheets — every action counts.', bodyAr: 'أهداف، أسيستات، شباك نظيفة — كل حاجة بتفرق.'),
    (icon: '🥇', titleEn: 'Top the Leaderboard', titleAr: 'تصدّر الليدربورد', bodyEn: 'Compete locally and globally. Win prizes every round.', bodyAr: 'تنافس محلياً وعالمياً. اكسب جوائز كل جولة.'),
  ];

  Widget _buildOnboarding(double topInset, double bottomInset) {
    final page = _onboardData[_onboardPage];
    final isLast = _onboardPage == _onboardData.length - 1;
    return SafeArea(
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(children: [
          const SizedBox(height: 20),
          // logo
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('BDGR', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(width: 8),
            Text(isArabic ? 'فانتازي' : 'FANTASY', style: const TextStyle(color: brandRed, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
          ]),
          const Spacer(),
          // icon
          Text(page.icon, style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 28),
          // title
          Text(isArabic ? page.titleAr : page.titleEn,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          // body
          Text(isArabic ? page.bodyAr : page.bodyEn,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 15, height: 1.6)),
          const Spacer(),
          // dots
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_onboardData.length, (i) =>
            AnimatedContainer(duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == _onboardPage ? 20 : 6, height: 6,
              decoration: BoxDecoration(
                color: i == _onboardPage ? brandRed : surface2,
                borderRadius: BorderRadius.circular(3))))),
          const SizedBox(height: 28),
          // buttons
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: brandRed, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () {
                if (isLast) { _finishOnboarding(); }
                else { setState(() => _onboardPage++); }
              },
              child: Text(isLast ? (isArabic ? 'ابدأ دلوقتي 🚀' : 'Get Started 🚀') : (isArabic ? 'التالي' : 'Next'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)))),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _finishOnboarding,
            child: Text(isArabic ? 'تخطى' : 'Skip',
              style: const TextStyle(color: muted, fontSize: 14))),
          SizedBox(height: bottomInset + 8),
        ])));
  }

  Future<void> _loadSharedEvents() async {
    try {
      final data = await _sb.rpc('get_fantasy_lobby');
      if (data == null) return;
      final m = data as Map<String, dynamic>;
      setState(() {
        if (m['LOCAL'] != null) _sharedLocalEvent = FantasyEvent.fromJson(m['LOCAL'] as Map<String, dynamic>);
        if (m['WORLD'] != null) _sharedWorldEvent = FantasyEvent.fromJson(m['WORLD'] as Map<String, dynamic>);
        _eventsLoaded = true;
      });
    } catch (_) {
      setState(() => _eventsLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topInset    = mq.padding.top;
    final bottomInset = mq.viewPadding.bottom;

    // loading check
    if (_checkingFirstTime) {
      return Scaffold(backgroundColor: bg, body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: brandRed),
          const SizedBox(height: 16),
          Text(isArabic ? 'جاري التحميل…' : 'Loading…', style: const TextStyle(color: muted)),
        ])));
    }

    // onboarding
    if (_showOnboarding) {
      return Scaffold(backgroundColor: bg, body: _buildOnboarding(topInset, bottomInset));
    }

    return Stack(children: [Positioned.fill(child: Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        SizedBox(height: topInset),
        // فريقي | الترتيب | الليجز  + اللغة و ؟
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Column(children: [
          Row(children: [
            // launch compact round page: the badger box = back to the arenas, title = Current GW + the arena
            GestureDetector(
              onTap: _gwBar && _team?.step == 1 ? () => _team?.goArenaPicker() : null,
              child: Stack(clipBehavior: Clip.none, children: [
                Container(width: 40, height: 40, padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
                  child: Image.asset(Brand.badger, fit: BoxFit.contain)),
                if (_gwBar && _team?.step == 1)
                  PositionedDirectional(start: -5, top: 12, child: Container(width: 16, height: 16,
                    decoration: BoxDecoration(color: cardBg, shape: BoxShape.circle, border: Border.all(color: line)),
                    child: Icon(isArabic ? Icons.chevron_right : Icons.chevron_left, color: Colors.white70, size: 13))),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(child: _gwBar
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(isArabic ? 'الجولة الحالية' : 'Current GW', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, height: 1.1)),
                  Text(_team?.arena == 'EGYPT' ? (isArabic ? 'محلي' : 'EGYPT') : (isArabic ? 'دولي' : 'WORLD'),
                    style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2)),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  // اسم المنتج ثابت بالإنجليزي زي BDGR (جزء من اللوجو)
                  const Text('FANTASY', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5, height: 1.1)),
                  const Text('B D G R', style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2)),
                ])),
            _HelpPulse(active: _statsPulse && !_helpPulse, child: GestureDetector(
              onTap: () {
                if (_statsPulse) { setState(() => _statsPulse = false); LocalStore.setFlag('fantasy_stats_hint'); }
                final st = _team;
                openMyFantasyHub(context, isArabic, onToggleLanguage: _toggleLanguage,   // launch: ranking · leagues · Badger League
                    showLanguage: _FancyPageState._lobbyCompact,
                    onRecap: st != null && st._recap != null ? () => st._openRecap() : null);
              },
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(color: cardBg, shape: BoxShape.circle, border: Border.all(color: const Color(0x99FFB300))),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 19)),
            )),
            const SizedBox(width: 6),
            // compact: the language moved into My Fantasy; the arena switch circle sits here on the round page
            if (!_FancyPageState._lobbyCompact) ...[
              FantasyLangToggle(isArabic: isArabic, onTap: _toggleLanguage),
              const SizedBox(width: 6),
            ],
            if (_gwBar && _team?.step == 1) ...[
              _ArenaSwitchCircle(world: _team?.arena != 'EGYPT', onTap: () => _team?.switchArena()),
              const SizedBox(width: 6),
            ],
            _HelpPulse(active: _helpPulse, child: GestureDetector(
              onTap: () {
                if (_helpPulse) { setState(() => _helpPulse = false); LocalStore.setFlag('fantasy_help_hint'); }
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => FantasyHelpSheet(
                    isArabic: isArabic,
                    budget: _currentEvent?.playerBudget ?? 100,
                    onToggleLanguage: _toggleLanguage,
                  ),
                );
              },
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(color: cardBg, shape: BoxShape.circle, border: Border.all(color: line)),
                child: const Center(child: Text('?', style: TextStyle(color: mint, fontSize: 13, fontWeight: FontWeight.w900)))),
            )),
          ]),
          AnimatedSize(
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut,
            child: true ? const SizedBox(width: double.infinity) : Column(children: [   // launch: tab row removed (code kept)
              const SizedBox(height: 8),
              _FantasyTopTabs(selected: _tab, isArabic: isArabic, onTap: (i) => setState(() => _tab = i)),
            ])),
          ]),
        ),
        Expanded(child: IndexedStack(
          index: _tab,
          children: [
            FancyPage(key: _teamKey, isArabicOverride: isArabic,
              onLanguageToggle: _toggleLanguage, showTopButtons: false,
              onInArena: (v) { if (mounted) setState(() => _inArena = v); }),
            FantasyRankTab(isArabic: isArabic, onToggleLanguage: _toggleLanguage),
            FantasyLeaguesTab(isArabic: isArabic),
          ],
        )),
      ]),
    )),
      if (_showIntro) Positioned.fill(child: FantasyIntro(isArabic: isArabic,
          onDone: () { if (mounted) setState(() => _showIntro = false); })),
    ]);
  }
}

// ─── arena switch circle (launch top bar): flag inside, ⇄ badge, EG / WR under ───
class _ArenaSwitchCircle extends StatelessWidget {
  const _ArenaSwitchCircle({required this.world, required this.onTap});
  final bool world;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { Buzz.tap(); onTap(); },
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(clipBehavior: Clip.none, children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (c, a) => RotationTransition(turns: Tween(begin: 0.5, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: c)),
          child: Container(key: ValueKey(world), width: 34, height: 34, alignment: Alignment.center,
            decoration: BoxDecoration(color: cardBg, shape: BoxShape.circle, border: Border.all(color: Brand.green, width: 1.4)),
            child: Text(world ? '🌍' : '🇪🇬', style: const TextStyle(fontSize: 16))),
        ),
        Positioned(right: -4, bottom: -3, child: Container(
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(color: Brand.green, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.swap_horiz_rounded, color: Colors.black, size: 11))),
      ]),
      const SizedBox(height: 1),
      Text(world ? 'WR' : 'EG', style: const TextStyle(color: Colors.white70, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 1)),
    ]),
  );
}

// ─── Fantasy top tabs: فريقي | الترتيب | الليجز ───────────────────────────
class _FantasyTopTabs extends StatelessWidget {
  final int selected;
  final bool isArabic;
  final ValueChanged<int> onTap;
  const _FantasyTopTabs({required this.selected, required this.isArabic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = isArabic ? ['فريقي', 'الترتيب', 'الليجز'] : ['My team', 'Ranking', 'Leagues'];
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
      child: Row(children: [
        for (var i = 0; i < items.length; i++)
          Expanded(child: GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: selected == i ? brandRed : Colors.transparent, borderRadius: BorderRadius.circular(9)),
              child: FittedBox(fit: BoxFit.scaleDown, child: Text(items[i],
                style: TextStyle(color: selected == i ? Colors.white : Colors.white60, fontSize: 13, fontWeight: FontWeight.w900))),
            ),
          )),
      ]),
    );
  }
}

// ─── Fantasy Bottom Nav ────────────────────────────────────────────────────
class _FantasyBottomNav extends StatelessWidget {
  final int selectedIndex;
  final bool isArabic;
  final double bottomInset;
  final ValueChanged<int> onTap;
  const _FantasyBottomNav({
    required this.selectedIndex,
    required this.isArabic,
    required this.bottomInset,
    required this.onTap,
  });

  String t(String en, String ar) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_outlined, t('Home', 'الرئيسية')),
      (Icons.emoji_events_outlined, t('Rank', 'الترتيب')),
      (Icons.sports_soccer, t('My Team', 'فريقي')),
      (Icons.shield_outlined, t('Leagues', 'الليجات')),
      (Icons.bar_chart_rounded, t('Stats', 'إحصائيات')),
    ];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(top: BorderSide(color: line)),
      ),
      padding: EdgeInsets.only(top: 8, bottom: 8 + bottomInset),
      child: Row(children: List.generate(items.length, (i) {
        final active = i == selectedIndex;
        return Expanded(child: GestureDetector(
          onTap: () => onTap(i),
          behavior: HitTestBehavior.opaque,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(items[i].$1, color: active ? brandRed : muted, size: 24),
            const SizedBox(height: 3),
            Text(items[i].$2, style: TextStyle(
              fontSize: 10,
              color: active ? brandRed : muted,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            )),
          ]),
        ));
      })),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LEADERBOARD TAB
// ═══════════════════════════════════════════════════════════════════════════

class _LeaderboardTab extends StatefulWidget {
  final bool isArabic;
  final FantasyEvent? Function() getEvent;
  final bool eventsLoaded;
  const _LeaderboardTab({required this.isArabic, required this.getEvent, this.eventsLoaded = false});
  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

// ─── Round summary model ───────────────────────────────────────────────────
class _RoundSummary {
  final String eventId, eventCode, nameAr, nameEn;
  final DateTime? endAt;
  final num? myScore, avgScore, topScore;
  final int? myRank;
  final int totalPlayers;
  final String? topUserName;
  final String? topUserId;
  _RoundSummary({required this.eventId, required this.eventCode,
    required this.nameAr, required this.nameEn, this.endAt,
    this.myScore, this.myRank, required this.totalPlayers,
    this.avgScore, this.topScore, this.topUserName, this.topUserId});
  factory _RoundSummary.fromMap(Map<String, dynamic> m) => _RoundSummary(
    eventId: m['event_id'] as String,
    eventCode: m['event_code'] as String,
    nameAr: m['name_ar'] as String? ?? '',
    nameEn: m['name_en'] as String? ?? '',
    endAt: m['end_at'] != null ? DateTime.tryParse(m['end_at'].toString()) : null,
    myScore: m['my_score'] as num?,
    myRank: m['my_rank'] as int?,
    totalPlayers: (m['total_players'] as num?)?.toInt() ?? 0,
    avgScore: m['avg_score'] as num?,
    topScore: m['top_score'] as num?,
    topUserName: m['top_user_name'] as String?,
    topUserId: m['top_user_id'] as String?,
  );
}

class _LeaderboardTabState extends State<_LeaderboardTab> {
  // rounds history
  List<_RoundSummary> _rounds = [];
  int _selectedRoundIdx = 0;

  // per-round leaderboard
  List<Map<String, dynamic>> _entries = [];
  Map<String, dynamic>? _myRank;
  bool _loading = false;
  bool _loadingRounds = false;
  String? _error;

  // filter
  String? _selGov;
  String? _selCity;
  List<String> _govList  = [];
  List<String> _cityList = [];
  String? _myGov;
  String? _myCity;
  int _loadToken = 0; // race-condition guard

  String t(String en, String ar) => widget.isArabic ? ar : en;
  _RoundSummary? get _currentRound => _rounds.isNotEmpty ? _rounds[_selectedRoundIdx] : null;

  @override
  void initState() { super.initState(); _init(); }

  @override
  void didUpdateWidget(_LeaderboardTab old) {
    super.didUpdateWidget(old);
    if (!old.eventsLoaded && widget.eventsLoaded && _rounds.isEmpty && !_loadingRounds) {
      _init();
    }
  }

  Future<void> _init() async {
    await Future.wait([_loadMyInfo(), _loadRounds()]);
  }

  Future<void> _loadRounds() async {
    setState(() => _loadingRounds = true);
    try {
      final data = await _sb.rpc('get_fantasy_rounds_history', params: {'p_type': 'LOCAL'});
      final rounds = (data as List).map((e) => _RoundSummary.fromMap(e as Map<String, dynamic>)).toList();
      setState(() {
        _rounds = rounds;
        _selectedRoundIdx = 0;
        _loadingRounds = false;
      });
      if (rounds.isNotEmpty) {
        await _loadLocations(rounds[0].eventId);
        _load();
      }
    } catch (e) {
      setState(() { _loadingRounds = false; _error = e.toString(); });
    }
  }

  void _selectRound(int idx) {
    _loadToken++;
    setState(() { _selectedRoundIdx = idx; _entries = []; _selGov = null; _selCity = null; });
    _loadLocations(_rounds[idx].eventId).then((_) => _load());
  }

  Future<void> _loadLocations(String eventId) async {
    try {
      final data = await _sb.rpc('get_leaderboard_locations', params: {'p_event_id': eventId});
      final m = data as Map<String, dynamic>;
      setState(() {
        _govList  = (m['governorates'] as List?)?.map((e) => e.toString()).toList() ?? [];
        _cityList = (m['cities']       as List?)?.map((e) => e.toString()).toList() ?? [];
      });
    } catch (_) {}
  }

  Future<void> _loadMyInfo() async {
    try {
      final myId = await _sb.rpc('get_my_iplay_user_id');
      if (myId != null) {
        final prof = await _sb.from('user_profile').select('governorate,city').eq('user_id', myId).maybeSingle();
        if (prof != null) { _myGov = prof['governorate']; _myCity = prof['city']; }
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    final round = _currentRound;
    if (round == null) { setState(() => _error = t('No rounds yet.','مفيش جولات لحد دلوقتي.')); return; }
    final token = ++_loadToken; // capture before any await
    setState(() { _loading = true; _error = null; });
    try {
      final lb = await _sb.rpc('get_event_leaderboard', params: {
        'p_event_id': round.eventId, 'p_limit': 10, 'p_offset': 0,
        'p_governorate': _selGov, 'p_city': _selCity,
      });
      if (!mounted || token != _loadToken) return; // stale response → discard
      final me = await _sb.rpc('get_my_event_rank', params: {'p_event_id': round.eventId});
      if (!mounted || token != _loadToken) return;
      setState(() {
        _entries = (lb as List).map((e) => e as Map<String, dynamic>).toList();
        _myRank  = me as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || token != _loadToken) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _resetFilter() {
    _loadToken++;
    setState(() { _selGov = null; _selCity = null; });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingRounds) return const Center(child: CircularProgressIndicator(color: brandRed));
    if (_rounds.isEmpty) return Center(child: Text(t('No finished rounds yet.','مفيش جولات خلصت لحد دلوقتي.'), style: const TextStyle(color: muted)));

    Widget content;
    if (_loading && _entries.isEmpty) {
      content = const SizedBox(height: 320, child: Center(child: CircularProgressIndicator(color: brandRed)));
    } else if (_error != null) {
      content = SizedBox(height: 320, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!, style: const TextStyle(color: muted), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _load, style: ElevatedButton.styleFrom(backgroundColor: brandRed),
          child: Text(t('Retry','إعادة'))),
      ])));
    } else if (_entries.isEmpty) {
      content = SizedBox(height: 320, child: Center(child: Text(t('No results yet.','مفيش نتائج لحد دلوقتي.'),
        style: const TextStyle(color: muted))));
    } else {
      content = _buildPodium(_entries.take(3).toList());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(t('LEADERBOARD','الترتيب'), textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        _roundSwitcher(),
        const SizedBox(height: 30),
        content,
        const SizedBox(height: 22),
        Row(children: [
          Expanded(child: _govDropdown()),
          const SizedBox(width: 8),
          Expanded(child: _cityDropdown()),
          if (_selGov != null || _selCity != null) ...[
            const SizedBox(width: 8),
            GestureDetector(onTap: _resetFilter, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: line)),
              child: Text(t('Reset','مسح'), style: const TextStyle(color: muted, fontSize: 12)),
            )),
          ],
        ]),
      ]),
    );
  }

  // ─── Round switcher: ‹ Last week › ─────────────────────────────────────
  // _rounds[0] = latest finished round; higher index = older.
  Widget _roundSwitcher() {
    final r        = _currentRound!;
    final canOlder = _selectedRoundIdx < _rounds.length - 1;
    final canNewer = _selectedRoundIdx > 0;
    final label    = _selectedRoundIdx == 0
        ? t('Last week','الأسبوع اللي فات')
        : (widget.isArabic ? r.nameAr : r.nameEn);
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _arrowBtn(Icons.chevron_left, canOlder ? () => _selectRound(_selectedRoundIdx + 1) : null),
      const SizedBox(width: 12),
      ConstrainedBox(constraints: const BoxConstraints(minWidth: 120, maxWidth: 200),
        child: Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w600))),
      const SizedBox(width: 12),
      _arrowBtn(Icons.chevron_right, canNewer ? () => _selectRound(_selectedRoundIdx - 1) : null),
    ]);
  }

  Widget _arrowBtn(IconData icon, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: Container(width: 32, height: 32,
      decoration: BoxDecoration(color: cardBg, shape: BoxShape.circle, border: Border.all(color: line)),
      child: Icon(icon, size: 20, color: onTap != null ? Colors.white : const Color(0xFF4A4A4A))));

  Widget _statChip(String label, String value, Color color) => Column(mainAxisSize: MainAxisSize.min, children: [
    Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
    Text(label, style: const TextStyle(fontSize: 10, color: muted)),
  ]);

  Widget _vDivider() => Container(width: 1, height: 32, color: line);

  Widget _govDropdown() {
    return _dropdown(
      hint: t('All Egypt','كل مصر'),
      value: _selGov,
      items: [
        if (_myGov != null) DropdownMenuItem(value: _myGov, child: Text('⭐ ${_myGov!}', overflow: TextOverflow.ellipsis)),
        ..._govList.where((g) => g != _myGov).map((g) => DropdownMenuItem(value: g, child: Text(g, overflow: TextOverflow.ellipsis))),
      ],
      onChanged: (v) { _loadToken++; setState(() { _selGov = v; _selCity = null; }); _load(); },
    );
  }

  Widget _cityDropdown() {
    final cities = _selGov != null
        ? _cityList.where((c) => true).toList() // in future filter by gov
        : _cityList;
    return _dropdown(
      hint: t('All Cities','كل الأحياء'),
      value: _selCity,
      items: [
        if (_myCity != null) DropdownMenuItem(value: _myCity, child: Text('⭐ ${_myCity!}', overflow: TextOverflow.ellipsis)),
        ...cities.where((c) => c != _myCity).map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))),
      ],
      onChanged: (v) { _loadToken++; setState(() => _selCity = v); _load(); },
    );
  }

  Widget _dropdown({required String hint, required String? value, required List<DropdownMenuItem<String>> items, required ValueChanged<String?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: value != null ? brandRed : line)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        hint: Text(hint, style: const TextStyle(color: muted, fontSize: 12)),
        value: value,
        isExpanded: true,
        dropdownColor: cardBg,
        icon: const Icon(Icons.keyboard_arrow_down, color: muted, size: 18),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        items: items,
        onChanged: onChanged,
      )),
    );
  }

  // ─── Podium (shared widget, see _podiumView) ─────────────────────────────
  Widget _buildPodium(List<Map<String, dynamic>> top3) => _podiumView(top3,
    youLabel: t('You','أنت'),
    onTap: (e) {
      final userId = e['user_id'] as String?;
      if (userId == null) return;
      _openUserSquad(userId, (e['display_name'] as String?) ?? '—', e['username'] as String?, e['avatar_url'] as String?,
        rank: (e['rank'] as num?)?.toInt(), points: e['total_points']);
    });

  Widget _squareAvatar(String? url, String name, double size, Color borderColor) {
    final radius = size * 0.28;
    final letter = Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.4)));
    return Container(width: size, height: size,
      decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 1.5)),
      child: ClipRRect(borderRadius: BorderRadius.circular(radius - 1.5),
        child: (url != null && url.isNotEmpty)
          ? _netImage(url, width: size, height: size, fit: BoxFit.cover, fallback: letter)
          : letter));
  }

  Widget _buildRow(Map<String, dynamic> e) {
    final rank = e['rank'] as int;
    final name = (e['display_name'] as String?) ?? '—';
    final pts = e['total_points'];
    final isMe = e['is_me'] == true;
    final userId   = e['user_id']   as String?;
    final username = e['username']  as String?;
    final avatarUrl = e['avatar_url'] as String?;
    return GestureDetector(
      onTap: userId != null ? () => _openUserSquad(userId, name, username, avatarUrl, rank: rank, points: pts) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF1A0A0A) : cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isMe ? brandRed.withOpacity(0.4) : line),
        ),
        child: Row(children: [
          SizedBox(width: 50, child: Row(children: [
            const Icon(Icons.emoji_events_outlined, color: muted, size: 14),
            const SizedBox(width: 4),
            Flexible(child: Text('$rank', maxLines: 1, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14))),
          ])),
          _squareAvatar(avatarUrl, name, 42, line),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            if (username != null && username.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('@$username', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: muted, fontSize: 12)),
            ],
          ])),
          const SizedBox(width: 8),
          Icon(Icons.diamond_outlined, color: isMe ? brandRed : muted, size: 14),
          const SizedBox(width: 4),
          Text('$pts', style: TextStyle(color: isMe ? brandRed : Colors.white,
            fontWeight: FontWeight.w900, fontSize: 14)),
        ]),
      ),
    );
  }

  Future<void> _openUserSquad(String userId, String userName, String? username, String? avatarUrl, {int? rank, dynamic points}) async {
    final round = _currentRound;
    if (round == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _UserSquadPage(
        userId:    userId,
        userName:  userName,
        username:  username,
        avatarUrl: avatarUrl,
        eventId:   round.eventId,
        roundName: widget.isArabic ? round.nameAr : round.nameEn,
        rank:      rank,
        points:    points,
        isArabic:  widget.isArabic,
      ),
    ));
  }

  Widget _buildMyRankBar() {
    final rank  = (_myRank?['rank'] as num?)?.toInt();
    final pts   = _myRank?['total_points'];
    final total = (_myRank?['total_players'] as num?)?.toInt();
    if (rank == null) return const SizedBox.shrink();

    // جيب بياناتي من الـ entries
    final _meList = _entries.where((e) => e['is_me'] == true);
    final myEntry = _meList.isEmpty ? null : _meList.first;
    final myName  = (myEntry?['display_name'] as String?) ?? t('You','أنت');
    final myAvatar = myEntry?['avatar_url'] as String?;

    // أول 3؟
    final isTop3 = rank <= 3;
    final medals = ['🥇','🥈','🥉'];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: isTop3 ? const Color(0xFF1A1200) : const Color(0xFF1A0505),
        border: Border(top: BorderSide(color: (isTop3 ? captainColor : brandRed).withOpacity(0.4), width: 1.5))),
      child: isTop3
        ? Row(children: [
            Text(medals[rank - 1], style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                rank == 1
                  ? t('You\'re #1! 🏆 Hero of the week!','أنت الأول! 🏆 بطل الجولة!')
                  : t('You\'re in the top 3! 🎉','أنت من الثلاثة الأوائل! 🎉'),
                style: TextStyle(color: captainColor, fontWeight: FontWeight.w900, fontSize: 13)),
              Text('$pts ${t("pts","نقطة")} • ${t("of","من")} $total',
                style: const TextStyle(color: muted, fontSize: 11)),
            ])),
          ])
        : Row(children: [
            // avatar
            CircleAvatar(radius: 18, backgroundColor: surface2,
              backgroundImage: myAvatar != null && myAvatar.isNotEmpty ? MediaCache.image(myAvatar) : null,
              child: (myAvatar == null || myAvatar.isEmpty)
                ? Text(myName.isNotEmpty ? myName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))
                : null),
            const SizedBox(width: 10),
            // name
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(myName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              Text('$pts ${t("pts","نقطة")}', style: const TextStyle(color: muted, fontSize: 11)),
            ])),
            // rank badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: brandRed.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10), border: Border.all(color: brandRed.withOpacity(0.4))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('#$rank', style: const TextStyle(color: brandRed, fontWeight: FontWeight.w900, fontSize: 16)),
                Text(total != null ? t('of $total','من $total') : '',
                  style: const TextStyle(color: muted, fontSize: 10)),
              ])),
          ]),
    );
  }
}

// ─── User Squad Sheet ─────────────────────────────────────────────────────

// ═══════════════════════════════════════════════════════════════════════════
// USER SQUAD PAGE — read-only squad of a leaderboard user for the selected round
// ═══════════════════════════════════════════════════════════════════════════
class _UserSquadPage extends StatefulWidget {
  final String userId, userName, eventId, roundName;
  final String? username, avatarUrl;
  final int? rank;
  final dynamic points;
  final bool isArabic;
  final bool draft;   // the user's DRAFT squad (second squad)
  const _UserSquadPage({required this.userId, required this.userName, required this.eventId,
    required this.roundName, this.username, this.avatarUrl, this.rank, this.points, required this.isArabic, this.draft = false});
  @override
  State<_UserSquadPage> createState() => _UserSquadPageState();
}

class _UserSquadPageState extends State<_UserSquadPage> {
  Map<String, dynamic>? _squad;
  bool _loading = true;
  String? _error;
  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = widget.draft
        ? await _sb.rpc('get_user_draft_public', params: {'p_event_id': widget.eventId, 'p_user_id': widget.userId})
        : await _sb.rpc('get_user_squad_public', params: {
            'p_target_user_id': widget.userId,
            'p_event_id': widget.eventId,
          });
      if (!mounted) return;
      setState(() { _squad = data as Map<String, dynamic>?; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = (e.toString().contains('deadline_not_passed') || e.toString().contains('not_yet'))
            ? t('Squad visible after deadline.', 'التشكيلة بتظهر بعد الديدلاين.')
            : t('Failed to load squad.', 'فشل تحميل التشكيلة.');
      });
    }
  }

  Color get _rankColor {
    switch (widget.rank) {
      case 1:  return const Color(0xFFFFB300);
      case 2:  return const Color(0xFF9E9E9E);
      case 3:  return const Color(0xFFCD7F32);
      default: return brandRed;
    }
  }

  void _goToProfile() {
    _openVisitorProfile(
      context,
      userId:      widget.userId,
      username:    widget.username ?? '',
      displayName: widget.userName,
      avatarUrl:   widget.avatarUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final formation = _squad?['formation']?.toString();
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(child: Column(children: [
        // top bar
        Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: Row(children: [
          IconButton(onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(backgroundColor: cardBg, side: BorderSide(color: line)),
            icon: const Icon(Icons.arrow_back, color: Colors.white)),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.roundName, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5))),
          if (formation != null)
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(20), border: Border.all(color: line)),
              child: Text(formation, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900))),
        ])),
        const SizedBox(height: 6),
        _buildHeader(),
        if (widget.draft && ((_squad?['predictions'] as List?)?.isNotEmpty ?? false))
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: DraftPredictStrip(
            isArabic: widget.isArabic, mine: false,
            rows: [for (final x in (_squad!['predictions'] as List)) PredRow.fromPublic(Map<String, dynamic>.from(x as Map))])),
        const SizedBox(height: 10),
        // pitch
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _loading
            ? const Center(child: CircularProgressIndicator(color: brandRed))
            : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(_error!, style: const TextStyle(color: muted), textAlign: TextAlign.center)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _load, style: ElevatedButton.styleFrom(backgroundColor: brandRed, foregroundColor: Colors.white),
                    child: Text(t('Retry','إعادة'))),
                ]))
              : _squad == null
                ? Center(child: Text(t('No squad saved.','مفيش تشكيلة.'), style: const TextStyle(color: muted)))
                : _buildPitch())),
        if (widget.draft && ((_squad?['subs'] as List?)?.isNotEmpty ?? false)) _benchLine(),
        if (_squad != null)
          Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: SquadSocialBar(
            eventId: widget.eventId, userId: widget.userId, draft: widget.draft, isArabic: widget.isArabic)),
        // go to profile
        Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 12), child: SizedBox(width: double.infinity, height: 50,
          child: ElevatedButton.icon(
            onPressed: _goToProfile,
            style: ElevatedButton.styleFrom(backgroundColor: brandRed, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.person_outline, size: 19),
            label: Text(t('GO TO PROFILE','روح للبروفايل'), style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8))))),
      ])),
    );
  }

  // ── header: avatar + name + podium block with total points & rank ───────
  Widget _buildHeader() {
    final color  = _rankColor;
    final name   = widget.userName;
    final url    = widget.avatarUrl;
    const size   = 56.0;
    const radius = size * 0.28;
    final letter = Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.4)));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // الصورة والاسم واليوزرنيم: كلهم بيودّوا على البروفايل (زي الزرار اللي تحت)
      GestureDetector(behavior: HitTestBehavior.opaque, onTap: _goToProfile, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(clipBehavior: Clip.none, children: [
        Container(width: size, height: size,
          decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: color.withOpacity(0.7), width: 1.5)),
          child: ClipRRect(borderRadius: BorderRadius.circular(radius - 1.5),
            child: (url != null && url.isNotEmpty)
              ? _netImage(url, width: size, height: size, fit: BoxFit.cover, fallback: letter)
              : letter)),
        Positioned(top: -5, left: 0, right: 0, child: Center(child: Container(width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: bg, width: 2))))),
      ]),
      const SizedBox(height: 6),
      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
      if (widget.username != null && widget.username!.isNotEmpty)
        Text('@${widget.username}', style: const TextStyle(color: muted, fontSize: 12)),
      ])),
      const SizedBox(height: 12),
      Stack(clipBehavior: Clip.none, children: [
        SizedBox(width: 160, child: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipPath(clipper: _PodiumLipClipper(),
            child: Container(height: 12, width: double.infinity, color: color.withOpacity(0.75))),
          Container(height: 76, width: double.infinity,
            decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [color.withOpacity(0.55), color.withOpacity(0.18), color.withOpacity(0.0)],
              stops: const [0.0, 0.6, 1.0])),
            child: Column(children: [
              const SizedBox(height: 6),
              Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.star_rounded, color: Colors.white70, size: 9),
                Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.star_rounded, color: Colors.white70, size: 10)),
                Icon(Icons.star_rounded, color: Colors.white70, size: 9),
              ]),
              // الترتيب هو الرقم الكبير (أول حاجة العين بتشوفها)
              Text(widget.rank != null ? '#${widget.rank}' : '—', style: TextStyle(fontSize: 32, height: 1.1, fontWeight: FontWeight.w900,
                color: Colors.white, shadows: [Shadow(color: Colors.black.withOpacity(0.35), blurRadius: 8)])),
              Text(t('RANK','المركز'), style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            ])),
        ])),
        if (widget.points != null) Positioned(top: -10, right: -18, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${widget.points}', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900, height: 1.1)),
            Text(t('POINTS','نقطة'), style: const TextStyle(color: muted, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ]))),
      ]),
    ]);
  }

  // ── pitch (same look as Build Team, read-only, shows each player's points) ──
  /// the bench (WORLD) + who came in after the results
  Widget _benchLine() {
    final subs = [for (final x in (_squad!['subs'] as List)) Map<String, dynamic>.from(x as Map)];
    final names = <String, String>{};
    for (final x in [...(_squad!['slots'] as List? ?? const []), ...subs]) {
      final m = Map<String, dynamic>.from(x as Map);
      names['${m['player_id']}'] = '${widget.isArabic ? (m['name_ar'] ?? m['name_en']) : m['name_en']}';
    }
    final ins = [for (final x in (_squad!['subs_in'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    String label(Map<String, dynamic> b) => b['kind'] == 'GK' ? 'GK' : '${b['order']}';
    return Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${t('Bench', 'الاحتياطي')}: ${subs.map((b) => '${label(b)} ${names['${b['player_id']}'] ?? ''}').join(' · ')}',
        maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      for (final s in ins)
        Text('⇄ ${names['${s['in']}'] ?? ''} ${t('in for', 'دخل مكان')} ${names['${s['out']}'] ?? ''}',
          style: const TextStyle(color: Brand.green, fontSize: 12, fontWeight: FontWeight.w700)),
    ]));
  }

  Widget _buildPitch() {
    final slots     = (_squad!['slots'] as List?) ?? [];
    final formation = (_squad!['formation'] as String?) ?? '4-3-3';
    final captainId = _squad!['captain_player_id']?.toString();
    var parts = formation.split('-').map((x) => int.tryParse(x) ?? 0).toList();
    if (parts.length < 3) parts = [4, 3, 3];
    final rows = <MapEntry<String, int>>[
      MapEntry('FWD', parts[2]), MapEntry('MID', parts[1]),
      MapEntry('DEF', parts[0]), const MapEntry('GK', 1),
    ];
    final byPos = <String, List<Map<String, dynamic>>>{'GK': [], 'DEF': [], 'MID': [], 'FWD': []};
    for (final s in slots) {
      final m = Map<String, dynamic>.from(s as Map);
      byPos[(m['position'] ?? 'MID').toString()]?.add(m);
    }
    for (final l in byPos.values) {
      l.sort((a, b) => ((a['slot_index'] as num?) ?? 0).compareTo((b['slot_index'] as num?) ?? 0));
    }
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1D6345), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF70A988), width: 1)),
      child: ClipRRect(borderRadius: BorderRadius.circular(13),
        child: LayoutBuilder(builder: (context, cons) {
          final rowH   = cons.maxHeight / 4;
          final avatar = (rowH - 42).clamp(28.0, 46.0).toDouble();
          final cardW  = (cons.maxWidth / 5 - 2).clamp(50.0, 68.0).toDouble();
          return Stack(fit: StackFit.expand, children: [
            Positioned(bottom: -1, left: cons.maxWidth * 0.27, right: cons.maxWidth * 0.27, height: rowH * 0.62,
              child: Container(decoration: BoxDecoration(border: Border.all(color: const Color(0xFF70A988), width: 1)))),
            for (var k = 1; k < 4; k++)
              Positioned(top: rowH * k, left: 0, right: 0, child: Container(height: 1, color: const Color(0xFF70A988))),
            Column(children: rows.map((row) => SizedBox(height: rowH, child: Center(child: FittedBox(fit: BoxFit.scaleDown,
              child: SizedBox(width: cons.maxWidth - 8,
                child: _posRow(row.key, row.value, byPos[row.key] ?? [], captainId, avatar, cardW)))))).toList()),
          ]);
        })));
  }

  Widget _posRow(String pos, int count, List<Map<String, dynamic>> players, String? captainId, double avatar, double cardW) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: List.generate(count, (i) {
      final p     = i < players.length ? players[i] : null;
      final isCap = p != null && captainId != null && p['player_id']?.toString() == captainId;
      final name  = p == null ? pos : ((widget.isArabic ? p['name_ar'] : p['name_en'])?.toString() ?? '—');
      final photo = p?['photo_url'] as String?;
      final pts   = p == null ? null : (p['points'] ?? p['total_points'] ?? p['fantasy_points']);
      return Expanded(child: Center(child: SizedBox(width: cardW, child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: avatar, height: avatar, child: Stack(clipBehavior: Clip.none, children: [
          Container(width: avatar, height: avatar,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: p == null ? const Color(0x55000000) : const Color(0xFFE8E8E8),
              border: Border.all(color: p == null ? const Color(0xCCFFFFFF) : (isCap ? captainColor : mint), width: isCap ? 2.2 : 1.5)),
            child: p == null
              ? Icon(Icons.person_outline, color: Colors.white, size: avatar * 0.55)
              : ClipOval(child: photo != null
                  ? _netImage(photo, width: avatar, height: avatar, fit: BoxFit.cover,
                      fallback: Icon(Icons.person, color: const Color(0xFF333333), size: avatar * 0.6))
                  : Icon(Icons.person, color: const Color(0xFF333333), size: avatar * 0.6))),
          if (isCap) Positioned(top: -4, right: -4,
            child: Container(width: 18, height: 18,
              decoration: BoxDecoration(color: captainColor, shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 1)),
              child: const Center(child: Text('C', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900, height: 1))))),
        ])),
        const SizedBox(height: 4),
        Container(width: cardW, padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          decoration: BoxDecoration(color: const Color(0xE6000000), borderRadius: BorderRadius.circular(5)),
          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
        const SizedBox(height: 3),
        SizedBox(height: 15, child: p == null ? null : Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(color: isCap ? captainColor : Colors.white, borderRadius: BorderRadius.circular(4)),
          child: Text('${pts ?? '—'} ${t('pts','ن')}',
            style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900, height: 1.4)))),
      ]))));
    }));
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED LEADERBOARD WIDGETS (used by Rank tab + League detail)
// ═══════════════════════════════════════════════════════════════════════════
const List<Color>  _podiumColors  = [Color(0xFFFFB300), Color(0xFF9E9E9E), Color(0xFFCD7F32)]; // 1st gold, 2nd silver, 3rd bronze
const List<double> _podiumHeights = [185.0, 140.0, 140.0];

// 2nd left · 1st center · 3rd right
Widget _podiumView(List<Map<String, dynamic>> top3, {required String youLabel, required void Function(Map<String, dynamic> e) onTap}) {
  const order = [1, 0, 2];
  return Row(crossAxisAlignment: CrossAxisAlignment.end, children: order.map((place) {
    if (place >= top3.length) return const Expanded(child: SizedBox.shrink());
    final e         = top3[place];
    final color     = _podiumColors[place];
    final rank      = (e['rank'] as num?)?.toInt() ?? place + 1;
    final name      = (e['display_name'] as String?) ?? '—';
    final pts       = e['total_points'];
    final isMe      = e['is_me'] == true;
    final avatarUrl = e['avatar_url'] as String?;
    return Expanded(child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(e),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (isMe) Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: brandRed, borderRadius: BorderRadius.circular(10)),
          child: Text(youLabel, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
        ),
        _glassAvatarW(avatarUrl, name, place == 0 ? 64.0 : 56.0, color),
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white))),
        const SizedBox(height: 3),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.diamond, color: color.withOpacity(0.9), size: 12),
          const SizedBox(width: 4),
          Text('$pts', style: const TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 14),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 1), child: _podiumBlockW(rank, color, _podiumHeights[place], place == 0)),
      ])));
  }).toList());
}

// glass rounded-square frame with the photo inside + small dot on top
Widget _glassAvatarW(String? url, String name, double size, Color color) {
  final inner  = size - 10;
  final letter = Container(color: surface2, child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: inner * 0.42))));
  return Stack(clipBehavior: Clip.none, children: [
    Container(width: size, height: size, padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.16), Colors.white.withOpacity(0.05)]),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))]),
      child: ClipRRect(borderRadius: BorderRadius.circular(inner * 0.24),
        child: (url != null && url.isNotEmpty)
          ? _netImage(url, width: inner, height: inner, fit: BoxFit.cover, fallback: letter)
          : letter)),
    Positioned(top: -5, left: 0, right: 0, child: Center(child: Container(width: 10, height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))))),
  ]);
}

Widget _podiumBlockW(int rank, Color color, double height, bool first) => Column(mainAxisSize: MainAxisSize.min, children: [
  // top face
  ClipPath(clipper: _PodiumLipClipper(),
    child: Container(height: 14, width: double.infinity, color: Color.lerp(color, Colors.white, 0.3)!.withOpacity(0.85))),
  // body
  Container(height: height, width: double.infinity,
    decoration: BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [color.withOpacity(0.85), color.withOpacity(0.45), color.withOpacity(0.0)],
      stops: const [0.0, 0.55, 1.0])),
    child: Column(children: [
      SizedBox(height: first ? 16 : 14),
      Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: const [
        Icon(Icons.star_rounded, color: Colors.white, size: 8),
        Padding(padding: EdgeInsets.only(bottom: 3), child: Icon(Icons.star_rounded, color: Colors.white, size: 9)),
        Icon(Icons.star_rounded, color: Colors.white, size: 8),
      ]),
      Text('$rank', style: TextStyle(fontSize: first ? 54 : 44, height: 1.05, fontWeight: FontWeight.w900,
        color: Colors.white, shadows: [Shadow(color: Colors.black.withOpacity(0.25), blurRadius: 6)])),
      const SizedBox(height: 2),
      CustomPaint(size: Size(first ? 50 : 44, first ? 18 : 16), painter: _LaurelPainter(Colors.white)),
    ])),
]);

// ‹ Last week ›
Widget _roundSwitcherView({required String label, VoidCallback? onOlder, VoidCallback? onNewer}) {
  Widget arrow(IconData icon, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: Container(width: 32, height: 32,
      decoration: BoxDecoration(color: cardBg, shape: BoxShape.circle, border: Border.all(color: line)),
      child: Icon(icon, size: 20, color: onTap != null ? Colors.white : const Color(0xFF4A4A4A))));
  return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
    arrow(Icons.chevron_left, onOlder),
    const SizedBox(width: 12),
    ConstrainedBox(constraints: const BoxConstraints(minWidth: 120, maxWidth: 200),
      child: Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w600))),
    const SizedBox(width: 12),
    arrow(Icons.chevron_right, onNewer),
  ]);
}

// row for rank 4+ (rounded-square avatar, @username, points)
Widget _leaderRowW(Map<String, dynamic> e, {VoidCallback? onTap}) {
  final rank     = (e['rank'] as num?)?.toInt() ?? 0;
  final name     = (e['display_name'] as String?) ?? '—';
  final pts      = e['total_points'];
  final isMe     = e['is_me'] == true;
  final username = e['username'] as String?;
  final url      = e['avatar_url'] as String?;
  const size     = 42.0;
  final letter   = Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.4)));
  return GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF1A0A0A) : cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isMe ? brandRed.withOpacity(0.4) : line),
      ),
      child: Row(children: [
        SizedBox(width: 54, child: Row(children: [
          const Icon(Icons.emoji_events_outlined, color: muted, size: 14),
          const SizedBox(width: 4),
          Flexible(child: Text('$rank', maxLines: 1, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14))),
        ])),
        Container(width: size, height: size,
          decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(size * 0.28),
            border: Border.all(color: line, width: 1.5)),
          child: ClipRRect(borderRadius: BorderRadius.circular(size * 0.28 - 1.5),
            child: (url != null && url.isNotEmpty)
              ? _netImage(url, width: size, height: size, fit: BoxFit.cover, fallback: letter)
              : letter)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          if (username != null && username.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('@$username', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontSize: 12)),
          ],
        ])),
        const SizedBox(width: 8),
        Icon(Icons.diamond_outlined, color: isMe ? brandRed : muted, size: 14),
        const SizedBox(width: 4),
        Text('$pts', style: TextStyle(color: isMe ? brandRed : Colors.white,
          fontWeight: FontWeight.w900, fontSize: 14)),
      ]),
    ),
  );
}

// ─── Laurel wreath under the podium number ────────────────────────────────
class _LaurelPainter extends CustomPainter {
  final Color color;
  _LaurelPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color..style = PaintingStyle.fill;
    final stem = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.1..strokeCap = StrokeCap.round;
    final r  = size.width * 0.40;
    final c  = Offset(size.width / 2, size.height - r);
    final lw = size.width * 0.13, lh = lw * 0.45;
    double rad(double d) => d * math.pi / 180;

    void leaf(Offset p, double angle) {
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(angle);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: lw, height: lh), fill);
      canvas.restore();
    }

    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(rect, rad(98), rad(72), false, stem);   // left branch
    canvas.drawArc(rect, rad(10), rad(72), false, stem);   // right branch

    for (final d in [110.0, 130.0, 150.0, 168.0]) {        // left side
      final a = rad(d);
      final dir = Offset(math.cos(a), math.sin(a));
      final p = c + dir * r;
      final tan = a + math.pi / 2;
      leaf(p + dir * (lh * 1.1), tan - 0.55);
      leaf(p - dir * (lh * 1.1), tan + 0.55);
    }
    for (final d in [70.0, 50.0, 30.0, 12.0]) {            // right side
      final a = rad(d);
      final dir = Offset(math.cos(a), math.sin(a));
      final p = c + dir * r;
      final tan = a - math.pi / 2;
      leaf(p + dir * (lh * 1.1), tan + 0.55);
      leaf(p - dir * (lh * 1.1), tan - 0.55);
    }
  }
  @override
  bool shouldRepaint(covariant _LaurelPainter old) => old.color != color;
}

// ─── Podium top-face clipper (trapezoid) ──────────────────────────────────
class _PodiumLipClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const inset = 8.0;
    return Path()
      ..moveTo(inset, 0)
      ..lineTo(size.width - inset, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ─── User Squad Sheet ─────────────────────────────────────────────────────
class _UserSquadSheet extends StatefulWidget {
  final String userId, userName, eventId;
  final bool isArabic;
  const _UserSquadSheet({required this.userId, required this.userName,
    required this.eventId, required this.isArabic});
  @override
  State<_UserSquadSheet> createState() => _UserSquadSheetState();
}

class _UserSquadSheetState extends State<_UserSquadSheet> {
  Map<String, dynamic>? _squad;
  bool _loading = true;
  String? _error;
  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await _sb.rpc('get_user_squad_public', params: {
        'p_target_user_id': widget.userId,
        'p_event_id': widget.eventId,
      });
      setState(() { _squad = data as Map<String, dynamic>?; _loading = false; });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().contains('deadline_not_passed')
            ? t('Squad visible after deadline.', 'التشكيلة بتظهر بعد الديدلاين.')
            : e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(children: [
        const SizedBox(height: 12),
        Container(width: 42, height: 4, decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(10))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8), child: Row(children: [
          CircleAvatar(radius: 18, backgroundColor: surface2,
            child: Text(widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.userName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            if (_squad != null)
              Text(_squad!['formation'] as String? ?? '', style: const TextStyle(color: muted, fontSize: 12)),
          ])),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: muted)),
        ])),
        if (_loading) const Expanded(child: Center(child: CircularProgressIndicator(color: brandRed)))
        else if (_error != null) Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(20),
          child: Text(_error!, style: const TextStyle(color: muted), textAlign: TextAlign.center))))
        else if (_squad == null) Expanded(child: Center(child: Text(t('No squad saved.','مفيش تشكيلة.'), style: const TextStyle(color: muted))))
        else Expanded(child: _buildPitch()),
      ]),
    );
  }

  Widget _buildPitch() {
    final slots = (_squad!['slots'] as List?) ?? [];
    final formation = (_squad!['formation'] as String?) ?? '4-3-3';
    final captainId = _squad!['captain_player_id'] as String?;
    final fmtParts = formation.split('-').map(int.parse).toList();
    final rows = <MapEntry<String, int>>[
      MapEntry('FWD', fmtParts[2]),
      MapEntry('MID', fmtParts[1]),
      MapEntry('DEF', fmtParts[0]),
      const MapEntry('GK', 1),
    ];
    Map<String, List<Map<String, dynamic>>> byPos = {'GK': [], 'DEF': [], 'MID': [], 'FWD': []};
    for (final s in slots) {
      final pos = (s as Map<String, dynamic>)['position'] as String? ?? 'MID';
      byPos[pos]?.add(s);
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(color: const Color(0xFF1D6345), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF70A988))),
      child: ClipRRect(borderRadius: BorderRadius.circular(13),
        child: LayoutBuilder(builder: (_, cons) {
          final rowH = cons.maxHeight / 4;
          final avatarSize = (rowH - 34).clamp(28.0, 44.0).toDouble();
          return Column(children: rows.map((row) {
            final rowPlayers = byPos[row.key] ?? [];
            return SizedBox(height: rowH, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(row.value, (i) {
                final p = i < rowPlayers.length ? rowPlayers[i] : null;
                final isCap = p != null && p['player_id'] == captainId;
                final name = p != null ? (widget.isArabic ? p['name_ar'] : p['name_en']) as String? ?? '—' : '—';
                final photo = p?['photo_url'] as String?;
                return Expanded(child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Stack(clipBehavior: Clip.none, children: [
                    Container(width: avatarSize, height: avatarSize,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                        color: p == null ? const Color(0x55000000) : const Color(0xFFE8E8E8),
                        border: Border.all(color: isCap ? captainColor : mint, width: isCap ? 2.2 : 1.5)),
                      child: p == null ? Icon(Icons.add, color: Colors.white, size: avatarSize * 0.5)
                        : ClipOval(child: photo != null
                            ? _netImage(photo, width: avatarSize, height: avatarSize, fit: BoxFit.cover,
                                fallback: Icon(Icons.person, color: const Color(0xFF333333), size: avatarSize * 0.6))
                            : Icon(Icons.person, color: const Color(0xFF333333), size: avatarSize * 0.6))),
                    if (isCap) Positioned(top: -4, right: -4, child: Container(width: 16, height: 16,
                      decoration: BoxDecoration(color: captainColor, shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 1)),
                      child: const Center(child: Text('C', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900, height: 1))))),
                  ]),
                  const SizedBox(height: 3),
                  Container(width: 60, padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xE6000000), borderRadius: BorderRadius.circular(4)),
                    child: Text(name.length > 10 ? '${name.substring(0,10)}…' : name,
                      maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700))),
                ]));
              })));
          }).toList());
        })));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LEAGUES TAB
// ═══════════════════════════════════════════════════════════════════════════

class _LeaguesTab extends StatefulWidget {
  final bool isArabic;
  final FantasyEvent? Function() getEvent;
  const _LeaguesTab({required this.isArabic, required this.getEvent});
  @override
  State<_LeaguesTab> createState() => _LeaguesTabState();
}

class _LeaguesTabState extends State<_LeaguesTab> {
  List<Map<String, dynamic>> _leagues = [];
  bool _loading = false;
  String? _error;
  final _nameCtrl   = TextEditingController();
  final _codeCtrl   = TextEditingController();
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  Map<String, dynamic>? _selectedLeague;
  List<Map<String, dynamic>> _leagueBoard = [];

  // guards against double taps on Create / Join
  bool _creating = false;
  bool _joining  = false;

  // league leaderboard paging (show 20, then +20 per "Show more")
  static const int _pageSize = 20;
  int     _leagueShown   = _pageSize;
  bool    _loadingBoard  = false;
  String? _boardEventId;

  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _nameCtrl.dispose(); _codeCtrl.dispose(); _searchCtrl.dispose(); _searchDebounce?.cancel(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _sb.rpc('get_my_leagues');
      final list = (data as List).map((e) => e as Map<String, dynamic>).toList()
        ..sort((a, b) {
          // most members first
          final byMembers = ((b['member_count'] as num?) ?? 0).compareTo((a['member_count'] as num?) ?? 0);
          if (byMembers != 0) return byMembers;
          // tie → older league first
          final ca = DateTime.tryParse(a['created_at']?.toString() ?? '');
          final cb = DateTime.tryParse(b['created_at']?.toString() ?? '');
          if (ca == null || cb == null) return 0;
          return ca.compareTo(cb);
        });
      setState(() { _leagues = list; _loading = false; });
    } catch (e) { setState(() { _loading = false; _error = e.toString(); }); }
  }

  Future<bool> _createLeague() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _creating) return false;
    _creating = true;
    try {
      await _sb.rpc('create_fantasy_league', params: {'p_name': name});
      _nameCtrl.clear(); _load();
      if (mounted) Navigator.pop(context);
      return true;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${t("Failed","فشل")}: $e'), backgroundColor: surface2));
      return false;
    } finally {
      _creating = false;
    }
  }

  Future<bool> _joinLeague() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty || _joining) return false;
    _joining = true;
    try {
      await _sb.rpc('join_fantasy_league', params: {'p_code': code});
      _codeCtrl.clear(); _load();
      if (mounted) Navigator.pop(context);
      return true;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${t("Failed","فشل")}: $e'), backgroundColor: surface2));
      return false;
    } finally {
      _joining = false;
    }
  }

  Map<String, dynamic>? _leagueStats;
  int _leagueRoundIdx = 0;
  bool _loadingStats = false;
  int _leagueInnerTab = 0; // 0=leaderboard, 1=members
  List<Map<String,dynamic>> _members = [];
  bool _loadingMembers = false;

  Future<void> _openLeague(Map<String, dynamic> league) async {
    setState(() {
      _selectedLeague = league; _leagueBoard = []; _leagueStats = null;
      _leagueRoundIdx = 0; _loadingStats = true; _searchCtrl.clear();
      _leagueInnerTab = 0; _members = [];
    });
    try {
      final stats = await _sb.rpc('get_league_stats', params: {'p_league_id': league['league_id']});
      setState(() { _leagueStats = stats as Map<String, dynamic>?; _loadingStats = false; });
      // load leaderboard for latest finished round
      final rounds = (_leagueStats?['rounds'] as List?) ?? [];
      if (rounds.isNotEmpty) _loadLeagueRound(league['league_id'], rounds[0]['event_id'] as String);
    } catch (_) { setState(() => _loadingStats = false); }
  }

  bool _hasMore = false;

  Future<void> _loadMembers(String leagueId) async {
    setState(() => _loadingMembers = true);
    try {
      final data = await _sb.rpc('get_league_members', params: {'p_league_id': leagueId});
      if (mounted) setState(() {
        _members = (data as List).map((e) => e as Map<String,dynamic>).toList();
        _loadingMembers = false;
      });
    } catch (_) { if (mounted) setState(() => _loadingMembers = false); }
  }

  Future<void> _loadLeagueRound(String leagueId, String eventId, {bool append = false}) async {
    _boardEventId = eventId;
    if (!append) setState(() { _loadingBoard = true; _leagueBoard = []; _leagueShown = 0; _hasMore = false; });
    try {
      final offset = append ? _leagueBoard.length : 0;
      final search = _searchCtrl.text.trim();
      final data = await _sb.rpc('get_league_leaderboard', params: {
        'p_league_id': leagueId, 'p_event_id': eventId,
        'p_limit': _pageSize, 'p_offset': offset,
        if (search.isNotEmpty) 'p_search': search,
      });
      if (!mounted || _boardEventId != eventId) return;
      final rows = (data as List).map((e) => e as Map<String, dynamic>).toList();
      setState(() {
        if (append) _leagueBoard.addAll(rows); else _leagueBoard = rows;
        _leagueShown = _leagueBoard.length;
        _hasMore = rows.length >= _pageSize;
        _loadingBoard = false;
      });
    } catch (_) {
      if (!mounted || _boardEventId != eventId) return;
      setState(() => _loadingBoard = false);
    }
  }

  void _selectLeagueRound(int idx) {
    final rounds = (_leagueStats?['rounds'] as List?) ?? [];
    if (idx < 0 || idx >= rounds.length) return;
    setState(() => _leagueRoundIdx = idx);
    _loadLeagueRound(_selectedLeague!['league_id'], (rounds[idx] as Map)['event_id'] as String);
  }

  Widget _leagueTabBtn(int idx, String label, IconData icon) => GestureDetector(
    onTap: () {
      setState(() => _leagueInnerTab = idx);
      if (idx == 1 && _members.isEmpty && _selectedLeague != null) {
        _loadMembers(_selectedLeague!['league_id']);
      }
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _leagueInnerTab == idx ? brandRed : surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _leagueInnerTab == idx ? brandRed : line)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: _leagueInnerTab == idx ? Colors.white : muted, size: 14),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(
          color: _leagueInnerTab == idx ? Colors.white : muted,
          fontSize: 12, fontWeight: FontWeight.w700)),
      ])));

  Widget _buildMembersTab() {
    if (_loadingMembers) return const Center(child: CircularProgressIndicator(color: brandRed));
    if (_members.isEmpty) return Center(child: Text(t('No members yet.','مفيش أعضاء.'), style: const TextStyle(color: muted)));
    final myId = _sb.auth.currentUser?.id;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16,8,16,24),
      itemCount: _members.length,
      itemBuilder: (_, i) {
        final m = _members[i];
        final uid = m['user_id'] as String?;
        final name = m['display_name']?.toString() ?? '—';
        final avatar = m['avatar_url'] as String?;
        final isOwner = m['is_owner'] == true;
        final isMe = uid == myId;
        return GestureDetector(
          onTap: isMe ? null : () {
            if (uid == null) return;
            _openVisitorProfile(context,
                userId: uid, username: m['username']?.toString() ?? '',
                displayName: name, avatarUrl: avatar);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF1A0A0A) : cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isMe ? brandRed.withOpacity(0.4) : line)),
            child: Row(children: [
              CircleAvatar(radius: 18, backgroundColor: surface2,
                backgroundImage: avatar != null && avatar.isNotEmpty ? MediaCache.image(avatar) : null,
                child: (avatar == null || avatar.isEmpty)
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))
                  : null),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  if (isMe) ...[const SizedBox(width: 6),
                    Text(t('(You)','(أنت)'), style: const TextStyle(color: brandRed, fontSize: 11))],
                ]),
                if (m['username'] != null)
                  Text('@${m['username']}', style: const TextStyle(color: muted, fontSize: 11)),
              ])),
              if (isOwner)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: captainColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: captainColor.withOpacity(0.4))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star, color: captainColor, size: 10),
                    const SizedBox(width: 3),
                    Text(t('Owner','مؤسس'), style: const TextStyle(color: captainColor, fontSize: 10, fontWeight: FontWeight.w900)),
                  ]))
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(10), border: Border.all(color: line)),
                  child: Text(t('Member','عضو'), style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700))),
            ]),
          ),
        );
      });
  }

  void _openMemberSquad(Map<String, dynamic> e, Map<String, dynamic> round) {
    final uid = e['user_id'] as String?;
    if (uid == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _UserSquadPage(
        userId:    uid,
        userName:  (e['display_name'] as String?) ?? '—',
        username:  e['username'] as String?,
        avatarUrl: e['avatar_url'] as String?,
        eventId:   round['event_id'] as String,
        roundName: widget.isArabic ? (round['name_ar'] ?? '').toString() : (round['name_en'] ?? '').toString(),
        rank:      (e['rank'] as num?)?.toInt(),
        points:    e['total_points'],
        isArabic:  widget.isArabic,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedLeague != null) return _buildLeagueDetail();
    final myLeague = _leagues.cast<Map<String, dynamic>?>()
        .firstWhere((l) => l!['is_owner'] == true, orElse: () => null);
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), child: Row(children: [
        Expanded(child: Text(t('LEAGUES','الليجات'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
        ElevatedButton(onPressed: _showCreateSheet, style: ElevatedButton.styleFrom(backgroundColor: brandRed, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 12)), child: Text(t('+ Create','+ إنشاء'))),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: _showJoinSheet, style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: line), padding: const EdgeInsets.symmetric(horizontal: 12)), child: Text(t('Join','انضمام'))),
      ])),
      if (myLeague != null) Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: GestureDetector(
          onTap: () => _openLeague(myLeague),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFF1A0A0A), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: brandRed.withOpacity(0.5))),
            child: Row(children: [
              const Icon(Icons.shield, color: brandRed, size: 18),
              const SizedBox(width: 10),
              Text(t('Go to my league','روح لليجي'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(child: Text(myLeague['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: muted, fontSize: 13))),
              const Icon(Icons.arrow_forward, color: brandRed, size: 18),
            ]),
          ),
        ),
      ),
      if (_loading) const Expanded(child: Center(child: CircularProgressIndicator(color: brandRed)))
      else if (_leagues.isEmpty) Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.shield_outlined, color: muted, size: 48),
        const SizedBox(height: 10),
        Text(t('No leagues yet.','مفيش ليجات لحد دلوقتي.'), style: const TextStyle(color: muted)),
      ])))
      else Expanded(child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _leagues.length, itemBuilder: (_, i) {
          final l = _leagues[i];
          return GestureDetector(onTap: () => _openLeague(l), child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(6)),
                    child: Text(l['invite_code'] as String, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w900, color: captainColor, letterSpacing: 2))),
                  const SizedBox(width: 8),
                  Text('${l['member_count']} ${t("members","عضو")}', style: const TextStyle(color: muted, fontSize: 12)),
                ]),
              ])),
              const Icon(Icons.chevron_right, color: muted),
            ]),
          ));
        })),
    ]);
  }

  Widget _buildLeagueDetail() {
    final rounds = (_leagueStats?['rounds'] as List?)
        ?.map((e) => e as Map<String, dynamic>).toList() ?? [];
    final round   = rounds.isNotEmpty ? rounds[_leagueRoundIdx] : null;
    final top3 = _leagueBoard.take(3).toList();
    final rest = _leagueBoard.length > 3 ? _leagueBoard.sublist(3) : <Map<String, dynamic>>[];

    Widget board;
    if (_loadingBoard) {
      board = const SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: brandRed)));
    } else if (_leagueBoard.isEmpty) {
      board = SizedBox(height: 300, child: Center(child: Text(t('No results yet.','مفيش نتائج لحد دلوقتي.'),
        style: const TextStyle(color: muted))));
    } else {
      board = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _podiumView(top3, youLabel: t('You','أنت'), onTap: (e) => _openMemberSquad(e, round!)),
        const SizedBox(height: 18),
        ...rest.map((e) => _leaderRowW(e, onTap: () => _openMemberSquad(e, round!))),
        if (_hasMore) Padding(
          padding: const EdgeInsets.only(top: 10),
          child: SizedBox(height: 46, child: OutlinedButton(
            onPressed: () {
              final rounds = (_leagueStats?['rounds'] as List?) ?? [];
              if (rounds.isNotEmpty) _loadLeagueRound(_selectedLeague!['league_id'], (rounds[_leagueRoundIdx] as Map)['event_id'] as String, append: true);
            },
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: line),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(t('Show more','عرض المزيد'), style: const TextStyle(fontWeight: FontWeight.w800)))),
        ),
      ]);
    }

    return Column(children: [
      // header
      Padding(padding: const EdgeInsets.fromLTRB(16,16,16,8), child: Row(children: [
        GestureDetector(onTap: () => setState(() { _selectedLeague = null; _leagueStats = null; }),
          child: const Icon(Icons.arrow_back, color: Colors.white)),
        const SizedBox(width: 10),
        Expanded(child: Text(_selectedLeague?['name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(6)),
          child: Text(_selectedLeague?['invite_code'] ?? '',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12,
              fontWeight: FontWeight.w900, color: captainColor, letterSpacing: 2))),
      ])),
      Padding(padding: const EdgeInsets.fromLTRB(16,0,16,8),
        child: Text('${_selectedLeague?['member_count'] ?? '—'} ${t("members","عضو")}',
          style: const TextStyle(color: muted, fontSize: 12))),
      // inner tabs
      Padding(padding: const EdgeInsets.fromLTRB(16,0,16,10), child:
        Row(children: [
          _leagueTabBtn(0, t('Leaderboard','الترتيب'), Icons.emoji_events_outlined),
          const SizedBox(width: 8),
          _leagueTabBtn(1, t('Members','الأعضاء'), Icons.people_outline),
        ])),
      if (_loadingStats) const Expanded(child: Center(child: CircularProgressIndicator(color: brandRed)))
      else if (_leagueInnerTab == 1) Expanded(child: _buildMembersTab())
      else if (rounds.isEmpty) Expanded(child: Center(child: Text(t('No finished rounds yet.','مفيش جولات خلصت.'), style: const TextStyle(color: muted))))
      else Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        Text(t('LEADERBOARD','الترتيب'), textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        _roundSwitcherView(
          label: _leagueRoundIdx == 0
              ? t('Last week','الأسبوع اللي فات')
              : (widget.isArabic ? (round!['name_ar'] ?? '').toString() : (round!['name_en'] ?? '').toString()),
          onOlder: _leagueRoundIdx < rounds.length - 1 ? () => _selectLeagueRound(_leagueRoundIdx + 1) : null,
          onNewer: _leagueRoundIdx > 0 ? () => _selectLeagueRound(_leagueRoundIdx - 1) : null,
        ),
        const SizedBox(height: 14),
        // search (UI only for now)
        Container(height: 44, padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
          child: Row(children: [
            const Icon(Icons.search, color: muted, size: 20),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _searchCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onChanged: (v) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                  final rounds = (_leagueStats?['rounds'] as List?) ?? [];
                  if (_selectedLeague != null && rounds.isNotEmpty && mounted)
                    _loadLeagueRound(_selectedLeague!['league_id'], (rounds[_leagueRoundIdx] as Map)['event_id'] as String);
                });
                setState(() {}); // rebuild to show/hide clear button
              },
              decoration: InputDecoration.collapsed(hintText: t('Search by username','دوّر باليوزرنيم'),
                hintStyle: const TextStyle(color: muted, fontSize: 13)))),
            if (_searchCtrl.text.isNotEmpty)
              GestureDetector(onTap: () {
                _searchCtrl.clear();
                _searchDebounce?.cancel();
                final rounds = (_leagueStats?['rounds'] as List?) ?? [];
                if (_selectedLeague != null && rounds.isNotEmpty)
                  _loadLeagueRound(_selectedLeague!['league_id'], (rounds[_leagueRoundIdx] as Map)['event_id'] as String);
                setState(() {});
              }, child: const Icon(Icons.close, color: muted, size: 18)),
          ])),
        const SizedBox(height: 28),
        board,
      ])),
    ]);
  }

  void _showCreateSheet() => showModalBottomSheet(context: context, backgroundColor: bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(t('Create League','إنشاء ليج'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        TextField(controller: _nameCtrl, enabled: !_creating, decoration: InputDecoration(hintText: t('League name','اسم الليج'),
          filled: true, fillColor: surface2, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 46, child: ElevatedButton(
          onPressed: _creating ? null : () async {
            final f = _createLeague();        // sets _creating = true synchronously
            setSheet(() {});                  // show disabled + spinner
            final ok = await f;
            if (!ok && ctx.mounted) setSheet(() {});
          },
          style: ElevatedButton.styleFrom(backgroundColor: brandRed, foregroundColor: Colors.white, elevation: 0,
            disabledBackgroundColor: brandRed.withOpacity(0.45), disabledForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: _creating
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(t('Create','إنشاء'), style: const TextStyle(fontWeight: FontWeight.w900)))),
      ])))));

  void _showJoinSheet() => showModalBottomSheet(context: context, backgroundColor: bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(t('Join League','انضم لليج'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        TextField(controller: _codeCtrl, enabled: !_joining, textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(hintText: t('Enter 6-letter code','ادخل الكود من 6 أحرف'),
            filled: true, fillColor: surface2, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 46, child: ElevatedButton(
          onPressed: _joining ? null : () async {
            final f = _joinLeague();          // sets _joining = true synchronously
            setSheet(() {});
            final ok = await f;
            if (!ok && ctx.mounted) setSheet(() {});
          },
          style: ElevatedButton.styleFrom(backgroundColor: brandRed, foregroundColor: Colors.white, elevation: 0,
            disabledBackgroundColor: brandRed.withOpacity(0.45), disabledForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: _joining
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(t('Join','انضم'), style: const TextStyle(fontWeight: FontWeight.w900)))),
      ])))));
}

// ═══════════════════════════════════════════════════════════════════════════
// PLAYER STATS TAB
// ═══════════════════════════════════════════════════════════════════════════

class _PlayerStatsTab extends StatefulWidget {
  final bool isArabic;
  final FantasyEvent? Function() getEvent;
  const _PlayerStatsTab({required this.isArabic, required this.getEvent});
  @override
  State<_PlayerStatsTab> createState() => _PlayerStatsTabState();
}

// ─── Stats inner tab enum ─────────────────────────────────────────────────
enum _StatsTab { players, charts, community }

class _PlayerStatsTabState extends State<_PlayerStatsTab> {
  // ── inner tab ──
  _StatsTab _innerTab = _StatsTab.players;

  // ── players tab ──
  List<Map<String,dynamic>> _all = [];
  List<Map<String,dynamic>> _rounds = [];
  String? _selectedEventId;
  bool _loading = false;
  String? _error;
  String? _posFilter;
  String? _clubFilter;
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  // ── charts tab ──
  Map<String,dynamic>? _playerCharts;
  bool _loadingCharts = false;

  // ── community tab ──
  Map<String,dynamic>? _community;
  bool _loadingCommunity = false;

  String t(String en, String ar) => widget.isArabic ? ar : en;
  static const _positions = ['GK','DEF','MID','FWD'];

  List<String> get _clubs {
    final seen = <String>{};
    final result = <String>[];
    for (final p in _all) {
      final c = (widget.isArabic ? p['team_name_ar'] : p['team_name_en'])?.toString() ?? '';
      if (c.isNotEmpty && seen.add(c)) result.add(c);
    }
    result.sort();
    return result;
  }

  List<Map<String,dynamic>> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _all.where((p) {
      if (_posFilter != null && p['player_pos'] != _posFilter) return false;
      if (_clubFilter != null) {
        final club = (widget.isArabic ? p['team_name_ar'] : p['team_name_en'])?.toString() ?? '';
        if (club != _clubFilter) return false;
      }
      if (q.isNotEmpty) {
        final en = (p['name_en'] ?? '').toString().toLowerCase();
        final ar = (p['name_ar'] ?? '').toString().toLowerCase();
        if (!en.contains(q) && !ar.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  @override
  void initState() { super.initState(); _init(); }

  @override
  void dispose() { _searchCtrl.dispose(); _searchDebounce?.cancel(); super.dispose(); }

  String get _statsType {
    // حاول تجيب النوع من الإيفنت الحالي، لو مش موجود LOCAL
    final event = widget.getEvent();
    if (event == null) return 'LOCAL';
    // FancyPage بتحدد arena كـ 'EGYPT' أو 'WORLD'
    // نستخدم event code — لو مفيش نرجع LOCAL
    return 'LOCAL'; // سيتحدد لاحقاً من الـ rounds list
  }

  Future<void> _init() async {
    try {
      // جرب LOCAL الأول، لو مفيش rounds جرب WORLD
      String type = 'LOCAL';
      var roundsData = await _sb.rpc('get_stats_rounds', params: {'p_type': 'LOCAL'});
      var rounds = (roundsData as List).map((e) => e as Map<String,dynamic>).toList();
      if (rounds.isEmpty) {
        type = 'WORLD';
        roundsData = await _sb.rpc('get_stats_rounds', params: {'p_type': 'WORLD'});
        rounds = (roundsData as List).map((e) => e as Map<String,dynamic>).toList();
      }
      final defId = await _sb.rpc('get_stats_default_event', params: {'p_type': type});
      if (mounted) setState(() { _rounds = rounds; _selectedEventId = defId as String?; });
      if (_selectedEventId != null) {
        _load();
        _loadCharts(_selectedEventId!);
        _loadCommunity(_selectedEventId!);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _loadCharts(String eventId) async {
    setState(() => _loadingCharts = true);
    try {
      final data = await _sb.rpc('get_event_player_charts', params: {'p_event_id': eventId});
      if (mounted) setState(() { _playerCharts = data as Map<String,dynamic>?; _loadingCharts = false; });
    } catch (_) { if (mounted) setState(() => _loadingCharts = false); }
  }

  Future<void> _loadCommunity(String eventId) async {
    setState(() => _loadingCommunity = true);
    try {
      final data = await _sb.rpc('get_event_community_stats', params: {'p_event_id': eventId});
      if (mounted) setState(() { _community = data as Map<String,dynamic>?; _loadingCommunity = false; });
    } catch (_) { if (mounted) setState(() => _loadingCommunity = false); }
  }

  Future<void> _load() async {
    if (_selectedEventId == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _sb.rpc('get_fantasy_player_stats', params: {'p_event_id': _selectedEventId});
      if (!mounted) return;
      setState(() {
        _all = (data as List).map((e) => e as Map<String,dynamic>).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Widget _dropdown({required String? value, required String hint, required List<String?> items,
      required List<String> labels, required ValueChanged<String?> onChanged, bool active = false}) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(context: context, backgroundColor: bg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16,16,16,8), child:
            Row(children: [
              Expanded(child: Text(hint, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
              if (value != null) GestureDetector(
                onTap: () { onChanged(null); Navigator.pop(context); },
                child: Text(t('Clear','مسح'), style: const TextStyle(color: brandRed, fontWeight: FontWeight.w700))),
            ])),
          Expanded(child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(labels[i], style: TextStyle(
                color: value == items[i] ? brandRed : Colors.white, fontWeight: FontWeight.w600)),
              trailing: value == items[i] ? const Icon(Icons.check, color: brandRed) : null,
              onTap: () { onChanged(items[i]); Navigator.pop(context); }))),
        ])),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? brandRed.withOpacity(0.15) : surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? brandRed : line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(value != null
            ? (labels[items.indexOf(value)].length > 10 ? labels[items.indexOf(value)].substring(0,10)+'…' : labels[items.indexOf(value)])
            : hint,
            style: TextStyle(color: active ? brandRed : muted, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, color: active ? brandRed : muted, size: 14),
        ])));
  }

  @override
  Widget build(BuildContext context) {
    final players = _filtered;
    final roundLabels = _rounds.map((r) => widget.isArabic ? r['name_ar'] as String : r['name_en'] as String).toList();
    final roundIds = _rounds.map((r) => r['event_id'] as String).toList();
    final clubs = _clubs;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16,14,16,10), child:
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _statsTabBtn(_StatsTab.players, t('Players','لاعبين'), Icons.format_list_bulleted),
          const SizedBox(width: 8),
          _statsTabBtn(_StatsTab.charts, t('Charts','تشارتس'), Icons.bar_chart),
          const SizedBox(width: 8),
          _statsTabBtn(_StatsTab.community, t('Community','مجتمع'), Icons.people_outline),
        ])),
      if (_innerTab == _StatsTab.charts)
        Expanded(child: _buildChartsTab())
      else if (_innerTab == _StatsTab.community)
        Expanded(child: _buildCommunityTab())
      else ...[
      // search
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child:
        Container(height: 42, padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
          child: Row(children: [
            const Icon(Icons.search, color: muted, size: 18),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _searchCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onChanged: (_) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 300), () { if (mounted) setState(() {}); });
              },
              decoration: InputDecoration.collapsed(
                hintText: t('Search by name','دوّر باسم اللاعب'),
                hintStyle: const TextStyle(color: muted, fontSize: 13)))),
            if (_searchCtrl.text.isNotEmpty)
              GestureDetector(onTap: () { _searchCtrl.clear(); setState(() {}); },
                child: const Icon(Icons.close, color: muted, size: 16)),
          ]))),
      const SizedBox(height: 8),
      // 3 dropdowns: round + position + club
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child:
        Row(children: [
          // round
          Expanded(child: _dropdown(
            value: _selectedEventId, hint: t('Round','الجولة'),
            items: roundIds, labels: roundLabels,
            active: true,
            onChanged: (v) {
              setState(() { _selectedEventId = v; _all = []; _playerCharts = null; _community = null; });
              if (v != null) { _load(); _loadCharts(v); _loadCommunity(v); }
            })),
          const SizedBox(width: 6),
          // position
          Expanded(child: _dropdown(
            value: _posFilter, hint: t('Position','المركز'),
            items: [null, ..._positions], labels: [t('All','الكل'), ..._positions],
            active: _posFilter != null,
            onChanged: (v) => setState(() => _posFilter = v))),
          const SizedBox(width: 6),
          // club
          Expanded(child: _dropdown(
            value: _clubFilter, hint: t('Club','نادي'),
            items: [null, ...clubs], labels: [t('All','الكل'), ...clubs],
            active: _clubFilter != null,
            onChanged: (v) => setState(() => _clubFilter = v))),
        ])),
      const SizedBox(height: 8),
      // header
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child:
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const SizedBox(width: 46),
            Expanded(child: Text(t('Player','لاعب'), style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700))),
            SizedBox(width: 36, child: Text('MV€', textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700))),
            SizedBox(width: 32, child: Text('Sel%', textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700))),
            SizedBox(width: 32, child: Text('LGW', textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700))),
            SizedBox(width: 36, child: Text(t('Total','إجمالي'), textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700))),
            SizedBox(width: 32, child: Text(t('Avg','متوسط'), textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700))),
          ]))),
      const SizedBox(height: 4),
      // list
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator(color: brandRed))
        : _error != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error!, style: const TextStyle(color: muted), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _init, style: ElevatedButton.styleFrom(backgroundColor: brandRed, foregroundColor: Colors.white),
                child: Text(t('Retry','إعادة'))),
            ]))
          : players.isEmpty
            ? Center(child: Text(t('No players.','مفيش لاعبين.'), style: const TextStyle(color: muted)))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: players.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _showPlayerStatsDialog(players[i]),
                  child: _playerRow(players[i])))),
      ], // end else players tab
    ]);
  }

  Widget _statsTabBtn(_StatsTab tab, String label, IconData icon) => GestureDetector(
    onTap: () => setState(() => _innerTab = tab),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _innerTab == tab ? brandRed : surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _innerTab == tab ? brandRed : line)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: _innerTab == tab ? Colors.white : muted, size: 13),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(
          color: _innerTab == tab ? Colors.white : muted,
          fontSize: 11, fontWeight: FontWeight.w700)),
      ])));

  // ── Charts Tab ────────────────────────────────────────────────────────────
  Widget _buildChartsTab() {
    if (_loadingCharts) return const Center(child: CircularProgressIndicator(color: brandRed));
    if (_playerCharts == null) return Center(child: Text(t('No data.','مفيش بيانات.'), style: const TextStyle(color: muted)));
    final mostSelected = (_playerCharts!['most_selected'] as List?) ?? [];
    final topScorers   = (_playerCharts!['top_scorers']   as List?) ?? [];
    return ListView(padding: const EdgeInsets.fromLTRB(16,8,16,24), children: [
      // Most Selected
      Text(t('Most Selected Players','أكثر اللاعبين اختياراً'),
        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      ...mostSelected.map((p) => _hBar(
        label: widget.isArabic ? (p['name_ar']??'') : (p['name_en']??''),
        sub: widget.isArabic ? (p['team_name_ar']??'') : (p['team_name_en']??''),
        pct: ((p['sel_pct'] as num?)?.toDouble() ?? 0) / 100,
        value: '${p['sel_pct']}%',
        color: brandRed,
        photo: p['photo_url'] as String?,
      )),
      const SizedBox(height: 20),
      // Top Scorers
      Text(t('Top Scorers','أعلى سكورات'),
        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      ...(() {
        final maxPts = topScorers.isEmpty ? 1.0
          : (topScorers.first['total_points'] as num?)?.toDouble() ?? 1.0;
        return topScorers.map((u) => _hBar(
          label: u['display_name']?.toString() ?? '—',
          pct: ((u['total_points'] as num?)?.toDouble() ?? 0) / maxPts,
          value: '${u['total_points']} ${t("pts","نقطة")}',
          color: captainColor,
          rank: (u['rank'] as num?)?.toInt(),
          photo: u['avatar_url'] as String?,
        ));
      })(),
    ]);
  }

  Widget _hBar({required String label, String? sub, required double pct,
      required String value, required Color color, String? photo, int? rank}) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child:
      Row(children: [
        // avatar/rank
        SizedBox(width: 36, child: rank != null
          ? Center(child: Text('#$rank', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)))
          : CircleAvatar(radius: 16, backgroundColor: surface2,
              backgroundImage: photo != null && photo.isNotEmpty ? MediaCache.image(photo) : null,
              child: (photo == null || photo.isEmpty)
                ? Text(label.isNotEmpty ? label[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))
                : null)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
            Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
          ]),
          if (sub != null) Text(sub, style: const TextStyle(color: muted, fontSize: 10)),
          const SizedBox(height: 4),
          ClipRRect(borderRadius: BorderRadius.circular(4), child:
            LinearProgressIndicator(value: pct.clamp(0.0, 1.0), minHeight: 5,
              backgroundColor: surface2,
              valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.8)))),
        ])),
      ]));
  }

  // ── Community Tab ─────────────────────────────────────────────────────────
  Widget _buildCommunityTab() {
    if (_loadingCommunity) return const Center(child: CircularProgressIndicator(color: brandRed));
    if (_community == null) return Center(child: Text(t('No data.','مفيش بيانات.'), style: const TextStyle(color: muted)));
    final total    = (_community!['total_players'] as num?)?.toInt() ?? 0;
    final myGov    = _community!['my_governorate']?.toString();
    final myCity   = _community!['my_city']?.toString();
    final govCount = (_community!['gov_count'] as num?)?.toInt() ?? 0;
    final cityCount= (_community!['city_count'] as num?)?.toInt() ?? 0;
    final top10Gov = (_community!['gov_top10_count'] as num?)?.toInt() ?? 0;
    final byGov    = (_community!['by_governorate'] as List?) ?? [];
    final maxGov   = byGov.isEmpty ? 1 : (byGov.first['player_count'] as num?)?.toInt() ?? 1;

    return ListView(padding: const EdgeInsets.fromLTRB(16,8,16,24), children: [
      // summary cards
      Row(children: [
        _commCard(t('Total Players','إجمالي اللاعبين'), '$total', Icons.people, brandRed),
        const SizedBox(width: 10),
        _commCard(t('From Your Gov.','من محافظتك'), '$govCount', Icons.location_on, const Color(0xFF4CAF50)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _commCard(myCity != null ? t('From $myCity','من $myCity') : t('From Your City','من حيّك'), '$cityCount', Icons.location_city, captainColor),
        const SizedBox(width: 10),
        _commCard(t('Gov. in Top 10%','محافظتك في Top 10%'), '$top10Gov', Icons.emoji_events, const Color(0xFFFF9800)),
      ]),
      const SizedBox(height: 20),
      // by governorate bars
      Text(t('Players by Governorate','اللاعبين بالمحافظة'),
        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      ...byGov.map((g) {
        final gov   = g['governorate']?.toString() ?? '—';
        final count = (g['player_count'] as num?)?.toInt() ?? 0;
        final pct   = count / maxGov;
        final isMe  = gov == myGov;
        return Padding(padding: const EdgeInsets.only(bottom: 8), child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Row(children: [
                Text(gov, style: TextStyle(
                  color: isMe ? brandRed : Colors.white,
                  fontSize: 12, fontWeight: isMe ? FontWeight.w900 : FontWeight.w600)),
                if (isMe) ...[const SizedBox(width: 4),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: brandRed, borderRadius: BorderRadius.circular(6)),
                    child: Text(t('You','أنت'), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)))],
              ])),
              Text('$count (${g['pct']}%)', style: const TextStyle(color: muted, fontSize: 11)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(4), child:
              LinearProgressIndicator(value: pct.clamp(0.0,1.0), minHeight: 6,
                backgroundColor: surface2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isMe ? brandRed : const Color(0xFF4CAF50)))),
          ]));
      }),
    ]);
  }

  Widget _commCard(String label, String value, IconData icon, Color color) =>
    Expanded(child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: muted, fontSize: 11), maxLines: 2),
      ])));

  void _showPlayerStatsDialog(Map<String,dynamic> p) {
    final name      = widget.isArabic ? (p['name_ar'] ?? p['name_en'] ?? '—') : (p['name_en'] ?? '—');
    final team      = widget.isArabic ? (p['team_name_ar'] ?? '') : (p['team_name_en'] ?? '');
    final pos       = p['player_pos']?.toString() ?? '—';
    final fullImg   = p['full_image_url'] as String?;
    final mval      = p['market_value'];
    final sel       = p['ownership_pct'];
    final lgw       = p['last_gw_pts'];
    final total     = p['total_pts'];
    final avg       = p['avg_pts'];
    final posColor  = pos == 'GK' ? const Color(0xFFFFB300)
                    : pos == 'DEF' ? const Color(0xFF4CAF50)
                    : pos == 'MID' ? const Color(0xFF2196F3) : brandRed;

    showDialog<void>(context: context, barrierColor: Colors.black.withOpacity(0.72),
      builder: (dctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Stack(clipBehavior: Clip.none, children: [
          Container(width: double.infinity,
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(22), border: Border.all(color: line)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // full image
              ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                child: AspectRatio(aspectRatio: 3/4,
                  child: fullImg != null
                    ? _netImage(fullImg, fit: BoxFit.cover,
                        fallback: Container(color: surface2, child: const Icon(Icons.person, color: mint, size: 80)))
                    : Container(color: surface2, child: const Icon(Icons.person, color: mint, size: 80)))),
              // pos badge strip
              Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 6),
                color: posColor.withOpacity(0.12),
                child: Center(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  decoration: BoxDecoration(color: posColor, borderRadius: BorderRadius.circular(10)),
                  child: Text(pos, style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900))))),
              // info
              Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 20), child:
                Column(children: [
                  Text(name, textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(team, style: const TextStyle(color: muted, fontSize: 13)),
                  const SizedBox(height: 14),
                  // stats grid
                  Row(children: [
                    _statCell(t('MV€','القيمة'), mval != null ? _fmtVal((mval as num).toDouble()) : '—', captainColor),
                    _statCell('Sel%', sel != null ? '$sel%' : '—', Colors.white),
                    _statCell('LGW', lgw != null ? '$lgw' : '—', Colors.white),
                    _statCell(t('Total','إجمالي'), total != null ? '$total' : '—', brandRed),
                    _statCell(t('Avg','متوسط'), avg != null ? '$avg' : '—', muted),
                  ]),
                ])),
            ])),
          Positioned(top: -14, right: -14, child: GestureDetector(onTap: () => Navigator.pop(dctx),
            child: Container(width: 30, height: 30,
              decoration: BoxDecoration(color: surface2, shape: BoxShape.circle, border: Border.all(color: line)),
              child: const Icon(Icons.close, color: muted, size: 16)))),
        ])));
  }

  Widget _statCell(String label, String value, Color color) => Expanded(child:
    Column(children: [
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: muted, fontSize: 9)),
    ]));

  Widget _playerRow(Map<String,dynamic> e) {
    final name   = widget.isArabic ? (e['name_ar'] ?? e['name_en'] ?? '—') : (e['name_en'] ?? '—');
    final team   = widget.isArabic ? (e['team_name_ar'] ?? '') : (e['team_name_en'] ?? '');
    final pos    = e['player_pos']?.toString() ?? '—';
    final photo  = (e['headshot_url'] ?? e['photo_url']) as String?;
    final mval   = e['market_value'];
    final sel    = e['ownership_pct'];
    final lgw    = e['last_gw_pts'];
    final total  = e['total_pts'];
    final avg    = e['avg_pts'];
    final posColor = pos == 'GK' ? const Color(0xFFFFB300)
                   : pos == 'DEF' ? const Color(0xFF4CAF50)
                   : pos == 'MID' ? const Color(0xFF2196F3) : brandRed;
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: line)),
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: surface2, shape: BoxShape.circle,
              border: Border.all(color: posColor.withOpacity(0.6), width: 1.5)),
            child: ClipOval(child: (photo != null && photo.isNotEmpty)
              ? _netImage(photo, width: 36, height: 36, fit: BoxFit.cover,
                  fallback: Center(child: Text(name.isNotEmpty ? name[0] : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14))))
              : Center(child: Text(name.isNotEmpty ? name[0] : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14))))),
          Positioned(bottom: -3, right: -3, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(color: posColor, borderRadius: BorderRadius.circular(3)),
            child: Text(pos, style: const TextStyle(color: Colors.black, fontSize: 7, fontWeight: FontWeight.w900)))),
        ]),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(name.toString(), maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
          Text(team, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: muted, fontSize: 10)),
        ])),
        // MV€
        SizedBox(width: 36, child: Text(mval != null ? _fmtVal((mval as num).toDouble()) : '—',
          textAlign: TextAlign.center,
          style: const TextStyle(color: captainColor, fontSize: 11, fontWeight: FontWeight.w700))),
        // Sel%
        SizedBox(width: 32, child: Text(sel != null ? '$sel%' : '—',
          textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 11))),
        // LGW
        SizedBox(width: 32, child: Text(lgw != null ? '$lgw' : '—',
          textAlign: TextAlign.center,
          style: TextStyle(color: lgw == null ? muted : (lgw as num) > 0 ? Colors.white : muted,
            fontWeight: FontWeight.w900, fontSize: 12))),
        // Total
        SizedBox(width: 36, child: Text(total != null ? '$total' : '—',
          textAlign: TextAlign.center,
          style: TextStyle(color: (total as num?) != null && (total as num) > 0 ? brandRed : muted,
            fontWeight: FontWeight.w900, fontSize: 12))),
        // Avg
        SizedBox(width: 32, child: Text(avg != null ? '$avg' : '—',
          textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 11))),
      ]),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════
// زرار اللغة (عربي / English) — نفس الشكل في كل صفحات الفانتازي
// ═══════════════════════════════════════════════════════════════════════════
class FantasyLangToggle extends StatelessWidget {
  const FantasyLangToggle({super.key, required this.isArabic, required this.onTap});
  final bool isArabic;
  final VoidCallback onTap;

  /// دايرة صغيرة: 🌐 وتحتها اللغة اللي هتتحول لها
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: cardBg, shape: BoxShape.circle, border: Border.all(color: line)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.language_rounded, color: Colors.white70, size: 14),
        Text(isArabic ? 'EN' : 'ع', style: const TextStyle(color: Brand.green, fontSize: 10, fontWeight: FontWeight.w900, height: 1.1)),
      ]),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// "إزاي بتلعب؟" — 3 أجزاء: الطريقة / النقط (جدول) / مثال كامل خطوة بخطوة
// النقط هنا نفس الداتابيز بالظبط (_calc_pts / admin_calculate_event_scores)
// ═══════════════════════════════════════════════════════════════════════════
class FantasyHelpSheet extends StatefulWidget {
  const FantasyHelpSheet({
    super.key,
    required this.isArabic,
    required this.budget,
    required this.onToggleLanguage,
  });
  final bool isArabic;
  final double budget;
  final VoidCallback onToggleLanguage;

  @override
  State<FantasyHelpSheet> createState() => _FantasyHelpSheetState();
}

class _FantasyHelpSheetState extends State<FantasyHelpSheet> {
  late bool _ar = widget.isArabic;
  int _section = 0;   // 0 الطريقة · 1 النقط · 2 مثال
  String t(String en, String ar) => _ar ? ar : en;

  void _toggle() {
    setState(() => _ar = !_ar);
    widget.onToggleLanguage();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Directionality(
      textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        height: h * 0.9,
        decoration: const BoxDecoration(
          color: Brand.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(top: false, child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 42, height: 4,
              decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(10))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
            child: Row(children: [
              Expanded(child: Text(t('How do you play?', 'إزاي بتلعب؟'),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))),
              FantasyLangToggle(isArabic: _ar, onTap: _toggle),
              IconButton(onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white)),
            ]),
          ),
          // 3 أجزاء
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: line)),
              child: Row(children: [
                _tabBtn(0, t('How it works', 'الطريقة')),
                _tabBtn(1, t('Points', 'النقط')),
                _tabBtn(2, t('Ties', 'التعادل')),
              ]),
            ),
          ),
          Expanded(child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _section == 0
                ? _howItWorks()
                : _section == 1
                    ? _pointsTable()
                    : ListView(key: const ValueKey('ties'), padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [FantasyTieRules(isArabic: _ar, draft: true)]),
          )),
        ])),
      ),
    );
  }

  Widget _tabBtn(int i, String label) => Expanded(child: GestureDetector(
    onTap: () => setState(() => _section = i),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: _section == i ? Brand.green : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, textAlign: TextAlign.center, style: TextStyle(
        color: _section == i ? Colors.black : Colors.white70,
        fontWeight: FontWeight.w800, fontSize: 13)),
    ),
  ));

  // ── الطريقة: خطوات مترقّمة ────────────────────────────────────────────────
  Widget _howItWorks() {
    final steps = [
      (Icons.stadium_outlined,      t('Pick your arena', 'اختار الأرينا'),
                                    t('Egypt (Ahly & Zamalek) or World.', 'مصر (الأهلي والزمالك) أو عالمي.')),
      (Icons.groups_2_outlined,     t('Pick your players', 'اختار لاعيبتك'),
                                    t('Every round says how many (4 to 7): a goalkeeper, then defence, midfield and attack.',
                                      'كل جولة بتقولك العدد (من 4 لـ 7): حارس، وبعدين دفاع، ووسط، وهجوم.')),
      (Icons.compare_arrows_rounded, t('How you pick', 'إزاي بتختار'),
                                    t('Egypt: two players at a time — tap the one you want, he stays on his side, or open "All players". World: swipe the cards or open the list with club and position filters.',
                                      'مصر: لاعبين قدامك — دوس على اللي عايزه ويفضل مكانه، أو افتح "كل اللعيبة". العالمي: اسحب الكروت، أو افتح الليستة بفلتر النادي والمركز.')),
      (Icons.event_seat_outlined,   t('Bench', 'الاحتياطي'),
                                    t('Optional: a goalkeeper + up to 3 players (defender, midfielder, attacker) in order. If one of your 7 does not play at all, sub 1 comes in, then 2, then 3; the bench goalkeeper only replaces your goalkeeper. Max ${_FancyPageState._subsMax} subs from one club.',
                                      'اختياري: حارس + لحد 3 لاعيبة (مدافع ووسط ومهاجم) بالترتيب. لو حد من الـ7 مالعبش خالص يدخل احتياطي 1، بعده 2، بعده 3، والحارس الاحتياطي بيدخل مكان الحارس بس. أقصى ${_FancyPageState._subsMax} احتياطي من نفس النادي.')),
      (Icons.shield_outlined,       t('Max ${4} from one club', 'أقصى 4 من نفس النادي'),
                                    t('In your main team. Mix it from different clubs.', 'في الأساسيين. نوّع فريقك من أكتر من نادي.')),
      (Icons.scoreboard_outlined,   t('Predict the score', 'توقّع النتيجة'),
                                    t('Right after you save. If you tie on points, the better predictions win.', 'بعد ما تحفظ على طول. لو اتعادلت في النقط، اللي توقعاته أصح يكسب.')),
      (Icons.lock_clock,            t('Save before the deadline', 'احفظ قبل الديدلاين'),
                                    t('Teams lock before the round starts.', 'التشكيلات بتتقفل قبل ما الجولة تبدأ.')),
      (Icons.sports_soccer,         t('Players play — you score', 'اللاعيبة بتلعب وإنت بتجمع نقط'),
                                    t('Goals, assists, clean sheets … from the real matches.', 'جول، أسيست، شباك نظيفة … من الماتشات الحقيقية.')),
      (Icons.emoji_events_outlined, t('Climb the ranking', 'اطلع في الترتيب'),
                                    t('Overall, in your leagues, and with your friends in the Badger League.',
                                      'على الكل، وفي الليجز بتاعتك، ومع صحابك في دوري بادجر.')),
    ];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: steps.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final (icon, title, body) = steps[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: line)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 30, height: 30, alignment: Alignment.center,
              decoration: const BoxDecoration(color: Brand.green, shape: BoxShape.circle),
              child: Text('${i + 1}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Flexible(child: Text(title, style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w800, fontSize: 14.5))),
              ]),
              const SizedBox(height: 4),
              Text(body, style: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 13, height: 1.4)),
            ])),
          ]),
        );
      },
    );
  }

  // ── النقط: جدول لكل مركز ──────────────────────────────────────────────────
  Widget _pointsTable() {
    final cols = [t('GK','حارس'), t('DEF','دفاع'), t('MID','وسط'), t('FWD','هجوم')];
    final rows = <(String, List<String>)>[
      (t('Goal','جول'),                    ['+10', '+6', '+5', '+4']),
      (t('Assist','أسيست'),                ['+8',  '+3', '+3', '+3']),
      (t('Clean sheet','شباك نظيفة'),       ['+4',  '+4', '+1', '–']),
      (t('Penalty saved','صد ضربة جزاء'),   ['+6',  '–',  '–',  '–']),
      (t('Yellow card','كارت أصفر'),        ['−1',  '−1', '−1', '−1']),
      (t('Red card','كارت أحمر'),           ['−3',  '−3', '−3', '−3']),
      (t('Own goal','جول في نفسه'),          ['−2',  '−2', '−2', '−2']),
      (t('Penalty missed','ضيّع ضربة جزاء'), ['−5',  '−5', '−5', '−5']),
    ];
    Color c(String v) => v.startsWith('+') ? Brand.green
        : v.startsWith('−') ? const Color(0xFFFF6B6B) : Colors.white24;

    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
      Container(
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: line)),
        child: Column(children: [
          // رأس الجدول
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(children: [
              const Expanded(flex: 5, child: SizedBox()),
              for (final h in cols)
                Expanded(flex: 2, child: Text(h, textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12.5))),
            ]),
          ),
          for (final (label, vals) in rows) ...[
            Divider(color: line, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(children: [
                Expanded(flex: 5, child: Text(label,
                    style: const TextStyle(color: Color(0xFFD4D4D4), fontSize: 13))),
                for (final v in vals)
                  Expanded(flex: 2, child: Text(v, textAlign: TextAlign.center,
                      style: TextStyle(color: c(v), fontWeight: FontWeight.w800, fontSize: 13))),
              ]),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0x1A00FF87), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x5500FF87))),
        child: Row(children: [
          const Icon(Icons.star_rounded, color: Brand.green),
          const SizedBox(width: 10),
          Expanded(child: Text(
            t('Captain: all his points are doubled (×2) — including minus points.',
              'الكابتن: كل نقطه بتتضرب في 2 — حتى النقط بالسالب.'),
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4))),
        ]),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// مثال كامل خطوة بخطوة (محاكاة — مش داتا حقيقية)
// ═══════════════════════════════════════════════════════════════════════════
class _FantasyExample extends StatefulWidget {
  const _FantasyExample({super.key, required this.isArabic});
  final bool isArabic;
  @override
  State<_FantasyExample> createState() => _FantasyExampleState();
}

class _FantasyExampleState extends State<_FantasyExample> {
  int _step = 0;
  static const int _steps = 6;
  String t(String en, String ar) => widget.isArabic ? ar : en;

  // تشكيلة مثال 4-4-2 — أسماء وأسعار تخيّلية
  static const _budget = 30.0;
  List<(String, String, String, double)> get _team => [
    ('GK',  t('Karim', 'كريم'),   'K', 2.5),
    ('DEF', t('Youssef', 'يوسف'), 'Y', 2.0),
    ('DEF', t('Mazen', 'مازن'),   'M', 2.5),
    ('DEF', t('Ali', 'علي'),      'A', 2.0),
    ('DEF', t('Hassan', 'حسن'),   'H', 1.5),
    ('MID', t('Ziad', 'زياد'),    'Z', 3.0),
    ('MID', t('Adam', 'آدم'),     'A', 2.5),
    ('MID', t('Seif', 'سيف'),     'S', 2.5),
    ('MID', t('Marwan', 'مروان'), 'M', 2.0),
    ('FWD', t('Omar', 'عمر'),     'O', 4.5),
    ('FWD', t('Nour', 'نور'),     'N', 3.0),
  ];
  double get _spent => _team.fold(0.0, (s, p) => s + p.$4);

  // اللي حصل في الماتشات (تخيّلي) والنقط حسب جدولنا
  List<(String, String, int)> get _events => [
    (t('Omar', 'عمر'),     t('2 goals (FWD 4 × 2)', 'جونين (هجوم 4 × 2)'), 8),
    (t('Mazen', 'مازن'),   t('1 goal (DEF)', 'جول (دفاع)'),                6),
    (t('Ziad', 'زياد'),    t('1 assist', 'أسيست'),                          3),
    (t('Karim', 'كريم'),   t('Clean sheet (GK)', 'شباك نظيفة (حارس)'),      4),
    (t('Youssef', 'يوسف'), t('Yellow card', 'كارت أصفر'),                   -1),
  ];
  // عمر كابتن: 8 × 2 = 16 → المجموع 16 + 6 + 3 + 4 − 1 = 28
  int get _total => 16 + 6 + 3 + 4 - 1;

  @override
  Widget build(BuildContext context) {
    final titles = [
      t('1. Build your team', '1. كوّن فريقك'),
      t('2. Pick a captain', '2. اختار الكابتن'),
      t('3. Deadline — teams lock', '3. الديدلاين — التشكيلة بتتقفل'),
      t('4. The matches are played', '4. الماتشات بتتلعب'),
      t('5. Your points', '5. نقطك'),
      t('6. The ranking', '6. الترتيب'),
    ];
    return Column(children: [
      // مؤشر الخطوات
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Row(children: List.generate(_steps, (i) => Expanded(child: Container(
          height: 4, margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: i <= _step ? Brand.green : line,
            borderRadius: BorderRadius.circular(4)),
        )))),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(alignment: AlignmentDirectional.centerStart,
          child: Text(titles[_step], style: const TextStyle(color: Colors.white,
              fontSize: 17, fontWeight: FontWeight.w900))),
      ),
      const SizedBox(height: 10),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(key: ValueKey(_step), child: _stepBody()),
        ),
      )),
      // رجوع / التالي
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(children: [
          if (_step > 0)
            Expanded(child: OutlinedButton(
              onPressed: () => setState(() => _step--),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white,
                side: BorderSide(color: line), padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(t('Back', 'رجوع')),
            )),
          if (_step > 0) const SizedBox(width: 10),
          Expanded(flex: 2, child: ElevatedButton(
            onPressed: () => setState(() => _step = _step < _steps - 1 ? _step + 1 : 0),
            style: ElevatedButton.styleFrom(backgroundColor: Brand.green, foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 13), elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(_step < _steps - 1 ? t('Next', 'التالي') : t('Start again', 'من الأول'),
                style: const TextStyle(fontWeight: FontWeight.w900)),
          )),
        ]),
      ),
    ]);
  }

  Widget _stepBody() {
    switch (_step) {
      case 0: return Column(children: [
        _note(t('Formation 4-4-2. Every player has his price. Budget ${_budget.toStringAsFixed(0)}M.',
                'تشكيل 4-4-2. كل لاعب ليه سعره. الميزانية ${_budget.toStringAsFixed(0)} مليون.')),
        const SizedBox(height: 10),
        _pitch(),
        const SizedBox(height: 10),
        _budgetBar(),
      ]);
      case 1: return Column(children: [
        _note(t('You picked Omar as captain — his points will be doubled.',
                'اخترت عمر كابتن — نقطه هتتحسب مرتين.')),
        const SizedBox(height: 10),
        _pitch(captain: true),
      ]);
      case 2: return Column(children: [
        _bigIcon(Icons.lock_rounded),
        _note(t('The deadline came before the first match. Your team is saved and locked — nobody can change his team now.',
                'الديدلاين جه قبل أول ماتش. فريقك اتحفظ واتقفل — محدش يقدر يغيّر فريقه دلوقتي.')),
      ]);
      case 3: return Column(children: [
        _note(t('Here is what your players did in the real matches:', 'ده اللي لاعيبتك عملوه في الماتشات الحقيقية:')),
        const SizedBox(height: 10),
        for (final (name, what, pts) in _events) _eventRow(name, what, pts),
      ]);
      case 4: return Column(children: [
        _eventRow(t('Omar (C)', 'عمر (كابتن)'), t('8 × 2 captain', '8 × 2 كابتن'), 16),
        _eventRow(t('Mazen', 'مازن'), t('goal', 'جول'), 6),
        _eventRow(t('Ziad', 'زياد'), t('assist', 'أسيست'), 3),
        _eventRow(t('Karim', 'كريم'), t('clean sheet', 'شباك نظيفة'), 4),
        _eventRow(t('Youssef', 'يوسف'), t('yellow card', 'كارت أصفر'), -1),
        const SizedBox(height: 10),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0x1A00FF87), borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Brand.green)),
          child: Column(children: [
            Text(t('Your total', 'مجموعك'), style: const TextStyle(color: Colors.white70)),
            Text('$_total ${t('pts', 'نقطة')}', style: const TextStyle(color: Brand.green,
                fontSize: 30, fontWeight: FontWeight.w900)),
          ]),
        ),
      ]);
      default: return Column(children: [
        _note(t('Everyone is ranked by points. You finished 3rd! 🎉', 'الكل بيترتب بالنقط. إنت طلعت التالت! 🎉')),
        const SizedBox(height: 16),
        _podium(),
      ]);
    }
  }

  Widget _note(String s) => Container(
    width: double.infinity, padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
    child: Text(s, style: const TextStyle(color: Color(0xFFD4D4D4), fontSize: 13.5, height: 1.45)),
  );

  Widget _bigIcon(IconData i) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Icon(i, color: Brand.green, size: 64),
  );

  Widget _eventRow(String name, String what, int pts) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
    child: Row(children: [
      Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
      Text(what, style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
      const SizedBox(width: 10),
      Text(pts > 0 ? '+$pts' : '$pts', style: TextStyle(
        color: pts >= 0 ? Brand.green : const Color(0xFFFF6B6B),
        fontWeight: FontWeight.w900, fontSize: 15)),
    ]),
  );

  Widget _budgetBar() {
    final ok = _spent <= _budget;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(t('Spent', 'صرفت'), style: const TextStyle(color: Colors.white70)),
          const Spacer(),
          Text('${_spent.toStringAsFixed(1)}M / ${_budget.toStringAsFixed(0)}M',
              style: TextStyle(color: ok ? Brand.green : const Color(0xFFFF6B6B), fontWeight: FontWeight.w900)),
          const SizedBox(width: 6),
          Icon(ok ? Icons.check_circle : Icons.error, color: ok ? Brand.green : const Color(0xFFFF6B6B), size: 18),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(
          value: (_spent / _budget).clamp(0, 1), minHeight: 8,
          backgroundColor: line, color: ok ? Brand.green : const Color(0xFFFF6B6B))),
      ]),
    );
  }

  Widget _pitch({bool captain = false}) {
    Widget row(String pos) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        for (final p in _team.where((p) => p.$1 == pos))
          Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(width: 34, height: 34, alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26)),
                child: Text(p.$3, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900))),
              if (captain && p.$2 == t('Omar', 'عمر'))
                Positioned(right: -4, top: -4, child: Container(width: 16, height: 16, alignment: Alignment.center,
                  decoration: const BoxDecoration(color: captainColor, shape: BoxShape.circle),
                  child: const Text('C', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900)))),
            ]),
            const SizedBox(height: 2),
            Text(p.$2, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            Text('${p.$4}M', style: const TextStyle(color: Colors.white70, fontSize: 9.5)),
          ]),
      ]),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1E6B36), Color(0xFF175A2C)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(children: [row('FWD'), row('MID'), row('DEF'), row('GK')]),
    );
  }

  Widget _podium() {
    Widget step(String place, String name, int pts, double h, Color c, {bool me = false}) => Expanded(
      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text(name, style: TextStyle(color: me ? Brand.green : Colors.white,
            fontWeight: FontWeight.w900, fontSize: me ? 14 : 13)),
        Text('$pts ${t('pts', 'نقطة')}', style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
        const SizedBox(height: 6),
        Container(height: h, margin: const EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: me ? Border.all(color: Brand.green, width: 2) : null,
          ),
          child: Text(place, style: const TextStyle(color: Colors.black, fontSize: 26, fontWeight: FontWeight.w900))),
      ]),
    );
    return SizedBox(height: 230, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      step('2', t('Sara', 'سارة'), 31, 120, const Color(0xFF9E9E9E)),
      step('1', t('Ahmed', 'أحمد'), 34, 160, const Color(0xFFFFB300)),
      step('3', t('You', 'إنت'), _total, 95, const Color(0xFFCD7F32), me: true),
    ]));
  }
}


// ═══════════════════════════════════════════════════════════════════════════
// "؟" بتنبض + صباع صغير بيتحرك تحتها — أول مرة بس، ومش بيغطي أي حاجة
// ═══════════════════════════════════════════════════════════════════════════
class _HelpPulse extends StatefulWidget {
  const _HelpPulse({required this.active, required this.child});
  final bool active;
  final Widget child;
  @override
  State<_HelpPulse> createState() => _HelpPulseState();
}

class _HelpPulseState extends State<_HelpPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 850))..repeat(reverse: true);

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) {
        final v = Curves.easeInOut.transform(_c.value);
        // الهالة بتترسم حوالين الزرار من غير ما تغيّر مقاسه، فمفيش حاجة جنبه بتتهز
        return Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
          Positioned(left: -6 * v, top: -6 * v, right: -6 * v, bottom: -6 * v, child: IgnorePointer(child: DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(color: Brand.green.withOpacity(0.7 * (1 - v)), width: 2),
              color: Brand.green.withOpacity(0.12 * (1 - v)))))),
          child!,
        ]);
      },
    );
  }
}
