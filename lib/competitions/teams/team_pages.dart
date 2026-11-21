import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_lang.dart';
import '../../brand.dart';
import '../../fantasy.dart' show cardBg, brandRed, surface2, muted, line;
import '../../media_cache.dart';
import 'athlete_form.dart';
import 'team_api.dart';

String _t(String en, String ar) => AppLang.t(en, ar);
const Color _gold = Color(0xFFFFD54F);

void _snack(BuildContext context, String text) {
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
}

Widget _dir(Widget child) => Directionality(textDirection: AppLang.isArabic ? TextDirection.rtl : TextDirection.ltr, child: child);

PreferredSizeWidget _bar(String title) => AppBar(
      backgroundColor: Brand.background, foregroundColor: Colors.white, elevation: 0,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)));

ButtonStyle _primary() => ElevatedButton.styleFrom(
    backgroundColor: brandRed, foregroundColor: Colors.white, elevation: 0,
    disabledBackgroundColor: surface2, disabledForegroundColor: muted,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)));

ButtonStyle _outline() => OutlinedButton.styleFrom(
    foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)));

String _posLabel(String? p) => switch (p) {
      'gk' => _t('GK', 'حارس'), 'def' => _t('DEF', 'دفاع'), 'mid' => _t('MID', 'وسط'), 'att' => _t('ATT', 'هجوم'), _ => '' };

String _timeLabel(String k) => switch (k) {
      'weekday_morning' => _t('Weekdays · morning', 'أيام الأسبوع · الصبح'),
      'weekday_evening' => _t('Weekdays · evening', 'أيام الأسبوع · بالليل'),
      'weekend_morning' => _t('Weekend · morning', 'الويك إند · الصبح'),
      'weekend_evening' => _t('Weekend · evening', 'الويك إند · بالليل'),
      _ => k };

Widget _avatar(String? url, String name, {double size = 40}) => ClipOval(
      child: SizedBox(width: size, height: size, child: (url ?? '').isEmpty
          ? Container(color: surface2, alignment: Alignment.center,
              child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                  style: TextStyle(color: Colors.white70, fontSize: size * 0.4, fontWeight: FontWeight.w800)))
          : Image(image: MediaCache.image(url!), fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: surface2))),
    );

// ═══════════════════════════════════════════════════════════════════════════
// المداخل
// ═══════════════════════════════════════════════════════════════════════════

/// "هعمل فريق (كابتن)": بيانات اللاعب الأول، بعدين صفحة إنشاء الفريق
Future<void> openTeamCreate(BuildContext context) async {
  if (!await ensureAthleteComplete(context) || !context.mounted) return;
  final id = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const TeamCreatePage()));
  if (id != null && context.mounted) {
    await Navigator.of(context).push(teamPageRoute(id, justCreated: true));
  }
}

/// "هنضم لفريق": صفحة الكود (البيانات بتتطلب وقت ما يبعت الطلب)
Future<void> openTeamJoin(BuildContext context, {String? code}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TeamJoinPage(code: code)));

Route<void> teamPageRoute(String id, {bool justCreated = false}) =>
    MaterialPageRoute(builder: (_) => TeamPage(teamId: id, justCreated: justCreated));

// ═══════════════════════════════════════════════════════════════════════════
// كارت "فريقي ⚽" في صفحة المسابقات
// ═══════════════════════════════════════════════════════════════════════════

class TeamHubCard extends StatefulWidget {
  const TeamHubCard({super.key});
  @override
  State<TeamHubCard> createState() => _TeamHubCardState();
}

class _TeamHubCardState extends State<TeamHubCard> {
  Map<String, dynamic>? _d;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    TeamApi.changed.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    TeamApi.changed.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await TeamApi.home();
      if (mounted) setState(() => _d = d);
    } catch (e) {
      debugPrint('team home error: $e');
    }
  }

  List<Map<String, dynamic>> _list(String k) =>
      ((_d?[k] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<void> _decideInvite(String id, bool accept) async {
    if (_busy) return;
    if (accept && !await ensureAthleteComplete(context)) return;
    setState(() => _busy = true);
    try {
      final r = await TeamApi.decide(id, accept);
      if (accept && mounted) {
        final team = r['team'] as Map?;
        if (team != null) Navigator.of(context).push(teamPageRoute('${team['id']}'));
      }
    } catch (e) {
      if (mounted) _snack(context, TeamApi.error(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null) return const SizedBox.shrink();
    final teams = _list('teams'), invites = _list('invites'), requests = _list('requests');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _gold.withOpacity(0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text(_t('My team ⚽', 'فريقي ⚽'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          const Spacer(),
          if (teams.isNotEmpty)
            GestureDetector(onTap: () => openTeamJoin(context),
                child: Text(_t('Join with code', 'انضم بكود'), style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 10),
        // دعوات جاية لي
        for (final i in invites) _inviteRow(i),
        // فرقي
        for (final t in teams) _teamRow(t),
        // طلبات بعتها ومستنية
        for (final r in requests) _requestRow(r),
        if (teams.isEmpty) ...[
          if (invites.isEmpty && requests.isEmpty)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(
              _t('Create your team as captain, or join a friend\'s team with its code.',
                 'اعمل فريقك وإنت الكابتن، أو انضم لفريق صاحبك بالكود بتاعه.'),
              style: const TextStyle(color: muted, fontSize: 12.5, height: 1.4))),
          Row(children: [
            Expanded(child: SizedBox(height: 44, child: ElevatedButton(onPressed: () => openTeamCreate(context), style: _primary(),
                child: Text(_t('Create (captain)', 'اعمل فريق (كابتن)'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13))))),
            const SizedBox(width: 8),
            Expanded(child: SizedBox(height: 44, child: OutlinedButton(onPressed: () => openTeamJoin(context), style: _outline(),
                child: Text(_t('Join a team', 'انضم لفريق'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))))),
          ]),
        ],
      ]),
    );
  }

  Widget _teamRow(Map<String, dynamic> t) {
    final ready = t['ready'] == true;
    final pending = (t['pending'] as num?)?.toInt() ?? 0;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(teamPageRoute('${t['id']}')),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${t['name']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text('${AppLang.isArabic ? t['format_ar'] : t['format_en']} · ${t['count']} / ${t['min']}'
                '${t['is_captain'] == true ? _t(' · Captain', ' · كابتن') : ''}',
                style: const TextStyle(color: muted, fontSize: 12)),
          ])),
          if (pending > 0) Container(
            margin: const EdgeInsetsDirectional.only(end: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: brandRed, borderRadius: BorderRadius.circular(10)),
            child: Text(_t('$pending new', '$pending جديد'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
          Text(ready ? _t('Ready ✓', 'جاهز ✓') : _t('Not ready', 'لسه'),
              style: TextStyle(color: ready ? Brand.green : muted, fontSize: 12, fontWeight: FontWeight.w800)),
          const Icon(Icons.chevron_right_rounded, color: muted),
        ]),
      ),
    );
  }

  Widget _inviteRow(Map<String, dynamic> i) {
    final t = Map<String, dynamic>.from(i['team'] as Map);
    final cap = Map<String, dynamic>.from((t['captain'] as Map?) ?? {});
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _gold.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: _gold.withOpacity(0.4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_t('📩 ${cap['name']} invited you to "${t['name']}"', '📩 ${cap['name']} عزمك على فريق "${t['name']}"'),
            style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('${AppLang.isArabic ? t['format_ar'] : t['format_en']} · ${t['count']} / ${t['max']}', style: const TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: SizedBox(height: 40, child: ElevatedButton(onPressed: _busy ? null : () => _decideInvite('${i['request_id']}', true), style: _primary(),
              child: Text(_t('Accept', 'قبول'), style: const TextStyle(fontWeight: FontWeight.w900))))),
          const SizedBox(width: 8),
          Expanded(child: SizedBox(height: 40, child: OutlinedButton(onPressed: _busy ? null : () => _decideInvite('${i['request_id']}', false), style: _outline(),
              child: Text(_t('Decline', 'رفض'))))),
        ]),
      ]),
    );
  }

  Widget _requestRow(Map<String, dynamic> r) {
    final t = Map<String, dynamic>.from(r['team'] as Map);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const Icon(Icons.hourglass_top_rounded, color: muted, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(_t('Waiting for the captain of "${t['name']}"', 'مستني موافقة كابتن "${t['name']}"'),
            style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w700))),
        TextButton(
          onPressed: _busy ? null : () async {
            try { await TeamApi.cancel('${r['request_id']}'); } catch (e) { if (mounted) _snack(context, TeamApi.error(e)); }
          },
          child: Text(_t('Cancel', 'إلغاء'), style: const TextStyle(color: muted)),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// إنشاء فريق (الكابتن)
// ═══════════════════════════════════════════════════════════════════════════

class TeamCreatePage extends StatefulWidget {
  const TeamCreatePage({super.key});
  @override
  State<TeamCreatePage> createState() => _TeamCreatePageState();
}

class _TeamCreatePageState extends State<TeamCreatePage> {
  List<Map<String, dynamic>> _formats = [];
  String? _format;
  final _name = TextEditingController();
  final Set<String> _times = {};
  bool _loading = true, _saving = false;

  @override
  void initState() {
    super.initState();
    TeamApi.home().then((d) {
      if (!mounted) return;
      setState(() {
        _formats = ((d['formats'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _format = _formats.isEmpty ? null : _formats.first['key'] as String;
        _loading = false;
      });
    }).catchError((Object e) {
      if (mounted) { setState(() => _loading = false); _snack(context, TeamApi.error(e)); }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid => _format != null && _name.text.trim().length >= 2;

  Future<void> _create() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    try {
      final t = await TeamApi.create({'sport': 'football', 'format': _format, 'name': _name.text.trim(), 'play_times': _times.toList()});
      if (mounted) Navigator.of(context).pop('${t['id']}');
    } catch (e) {
      if (mounted) _snack(context, TeamApi.error(e));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) => _dir(Scaffold(
        backgroundColor: Brand.background,
        appBar: _bar(_t('Create your team', 'اعمل فريقك')),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: brandRed, strokeWidth: 2))
            : ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 24), children: [
                Text(_t('You are the captain ⚽', 'إنت الكابتن ⚽'), style: const TextStyle(color: _gold, fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                Text(_t('Format', 'شكل الفريق'), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                for (final f in _formats) GestureDetector(
                  onTap: () => setState(() => _format = f['key'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _format == f['key'] ? brandRed.withOpacity(0.12) : cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _format == f['key'] ? brandRed : line),
                    ),
                    child: Row(children: [
                      Expanded(child: Text(AppLang.isArabic ? '${f['ar']}' : '${f['en']}',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900))),
                      Text(_t('${f['min']}–${f['max']} players', 'من ${f['min']} لـ ${f['max']} لاعيبة'), style: const TextStyle(color: muted, fontSize: 12.5)),
                      const SizedBox(width: 8),
                      Icon(_format == f['key'] ? Icons.radio_button_checked : Icons.radio_button_off, color: _format == f['key'] ? brandRed : muted, size: 20),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                Text(_t('Team name', 'اسم الفريق'), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                TextField(
                  controller: _name, maxLength: 30, onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: _t('e.g. Maadi Lions', 'مثلاً: أسود المعادي'), hintStyle: const TextStyle(color: muted),
                    filled: true, fillColor: surface2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 6),
                Text(_t('Best time to play (optional)', 'أنسب وقت للعب (اختياري)'), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final k in const ['weekday_evening', 'weekend_morning', 'weekend_evening', 'weekday_morning'])
                    GestureDetector(
                      onTap: () => setState(() => _times.contains(k) ? _times.remove(k) : _times.add(k)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _times.contains(k) ? brandRed.withOpacity(0.16) : surface2,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _times.contains(k) ? brandRed : Colors.transparent)),
                        child: Text(_timeLabel(k), style: TextStyle(color: _times.contains(k) ? Colors.white : Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ]),
                const SizedBox(height: 24),
                SizedBox(height: 50, child: ElevatedButton(
                  onPressed: _valid && !_saving ? _create : null, style: _primary(),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_t('Create team', 'اعمل الفريق'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                )),
              ]),
      ));
}

// ═══════════════════════════════════════════════════════════════════════════
// الانضمام بكود
// ═══════════════════════════════════════════════════════════════════════════

class TeamJoinPage extends StatefulWidget {
  const TeamJoinPage({super.key, this.code});
  final String? code;
  @override
  State<TeamJoinPage> createState() => _TeamJoinPageState();
}

class _TeamJoinPageState extends State<TeamJoinPage> {
  late final _code = TextEditingController(text: widget.code ?? '');
  Map<String, dynamic>? _team;
  bool _busy = false;
  String? _done;

  @override
  void initState() {
    super.initState();
    if ((widget.code ?? '').isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _find());
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    if (_code.text.trim().length < 4 || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() { _busy = true; _team = null; _done = null; });
    try {
      final t = await TeamApi.preview(_code.text);
      if (mounted) setState(() => _team = t);
    } catch (e) {
      if (mounted) _snack(context, TeamApi.error(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _join() async {
    if (_busy) return;
    if (!await ensureAthleteComplete(context) || !mounted) return;
    setState(() => _busy = true);
    try {
      final r = await TeamApi.join(_code.text);
      if (!mounted) return;
      if (r['status'] == 'accepted') {
        final team = r['team'] as Map?;
        Navigator.of(context).pushReplacement(teamPageRoute('${team?['id'] ?? _team?['id']}'));
        return;
      }
      setState(() => _done = _t('Request sent ✓ The captain will confirm it.', 'طلبك اتبعت ✓ الكابتن هيأكده.'));
    } catch (e) {
      if (mounted) _snack(context, TeamApi.error(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = _team;
    final st = t?['my_status'];
    final cap = Map<String, dynamic>.from((t?['captain'] as Map?) ?? {});
    final full = t != null && (t['count'] as num) >= (t['max'] as num);
    return _dir(Scaffold(
      backgroundColor: Brand.background,
      appBar: _bar(_t('Join a team', 'انضم لفريق')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 24), children: [
        Text(_t('Enter the team code your captain sent you.', 'اكتب كود الفريق اللي الكابتن بعتهولك.'),
            style: const TextStyle(color: muted, fontSize: 13)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(
            controller: _code, textCapitalization: TextCapitalization.characters, maxLength: 12,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]'))],
            onSubmitted: (_) => _find(),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 3),
            decoration: InputDecoration(
              counterText: '', hintText: 'ABC234', hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 3),
              filled: true, fillColor: surface2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
          )),
          const SizedBox(width: 8),
          SizedBox(height: 52, child: ElevatedButton(onPressed: _busy ? null : _find, style: _primary(),
              child: Text(_t('Find', 'دوّر'), style: const TextStyle(fontWeight: FontWeight.w900)))),
        ]),
        const SizedBox(height: 18),
        if (t != null) Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: _gold.withOpacity(0.35))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${t['name']}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('${AppLang.isArabic ? t['format_ar'] : t['format_en']} · ${t['count']} / ${t['max']} ${_t('players', 'لاعيبة')}',
                style: const TextStyle(color: muted, fontSize: 12.5)),
            const SizedBox(height: 12),
            Row(children: [
              _avatar(cap['avatar'] as String?, '${cap['name'] ?? ''}', size: 34),
              const SizedBox(width: 10),
              Expanded(child: Text(_t('Captain: ${cap['name']}', 'الكابتن: ${cap['name']}'),
                  style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 16),
            if (_done != null)
              Text(_done!, style: const TextStyle(color: Brand.green, fontSize: 13.5, fontWeight: FontWeight.w800))
            else if (st == 'member')
              SizedBox(width: double.infinity, height: 46, child: OutlinedButton(style: _outline(),
                  onPressed: () => Navigator.of(context).pushReplacement(teamPageRoute('${t['id']}')),
                  child: Text(_t('You are in this team — open it', 'إنت في الفريق ده — افتحه'))))
            else if (st == 'requested')
              Text(_t('Your request is waiting for the captain.', 'طلبك مستني موافقة الكابتن.'), style: const TextStyle(color: muted))
            else if (full)
              Text(_t('This team is full.', 'الفريق ده كامل.'), style: const TextStyle(color: muted))
            else
              SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: _busy ? null : _join, style: _primary(),
                  child: Text(st == 'invited' ? _t('Accept invite', 'اقبل الدعوة') : _t('Send join request', 'ابعت طلب انضمام'),
                      style: const TextStyle(fontWeight: FontWeight.w900)))),
          ]),
        ),
      ]),
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// صفحة الفريق
// ═══════════════════════════════════════════════════════════════════════════

class TeamPage extends StatefulWidget {
  const TeamPage({super.key, required this.teamId, this.justCreated = false});
  final String teamId;
  final bool justCreated;
  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  Map<String, dynamic>? _t0;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await TeamApi.get(widget.teamId);
      if (mounted) setState(() { _t0 = t; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = TeamApi.error(e));
    }
  }

  List<Map<String, dynamic>> _list(String k) =>
      ((_t0?[k] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<void> _run(Future<void> Function() f) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await f();
      await _load();
    } catch (e) {
      if (mounted) _snack(context, TeamApi.error(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  void _share() {
    final t = _t0!;
    Share.share(TeamApi.shareText('${t['name']}', '${t['code']}'));
  }

  Future<void> _inviteByUsername() async {
    final ctrl = TextEditingController();
    final u = await showDialog<String>(context: context, builder: (ctx) => _dir(AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(_t('Invite by username', 'ادعي باليوزرنيم'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      content: TextField(
        controller: ctrl, autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(prefixText: '@', prefixStyle: const TextStyle(color: muted), hintText: 'username',
            hintStyle: const TextStyle(color: Colors.white24), filled: true, fillColor: surface2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_t('Cancel', 'إلغاء'), style: const TextStyle(color: muted))),
        TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: Text(_t('Invite', 'ادعي'), style: const TextStyle(color: brandRed, fontWeight: FontWeight.w900))),
      ],
    )));
    if (u == null || u.trim().isEmpty) return;
    await _run(() async {
      final r = await TeamApi.invite(widget.teamId, u.replaceAll('@', ''));
      final user = Map<String, dynamic>.from((r['user'] as Map?) ?? {});
      if (mounted) {
        _snack(context, r['status'] == 'accepted'
            ? _t('${user['name'] ?? 'They'} had asked to join — now in the team ✓', '${user['name'] ?? ''} كان باعت طلب — دخل الفريق ✓')
            : _t('Invite sent to ${user['name']} (@${user['username']}) ✓', 'الدعوة اتبعتت لـ ${user['name']} (@${user['username']}) ✓'));
      }
    });
  }

  Future<bool> _confirm(String title, String body, String yes) async =>
      await showDialog<bool>(context: context, builder: (ctx) => _dir(AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: Text(body, style: const TextStyle(color: Colors.white70, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('Cancel', 'إلغاء'), style: const TextStyle(color: muted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(yes, style: const TextStyle(color: brandRed, fontWeight: FontWeight.w900))),
        ],
      ))) == true;

  @override
  Widget build(BuildContext context) {
    final t = _t0;
    if (t == null) {
      return _dir(Scaffold(backgroundColor: Brand.background, appBar: _bar(_t('My team', 'فريقي')),
          body: Center(child: _error != null
              ? Text(_error!, style: const TextStyle(color: muted))
              : const CircularProgressIndicator(color: brandRed, strokeWidth: 2))));
    }
    final cap = t['is_captain'] == true;
    final count = (t['count'] as num).toInt(), min = (t['min'] as num).toInt(), max = (t['max'] as num).toInt();
    final ready = t['ready'] == true;
    final members = _list('members'), requests = _list('requests'), invites = _list('invites');
    final times = ((t['play_times'] as List?) ?? []).map((e) => '$e').toList();
    final incomplete = members.where((m) => m['complete'] != true).length;
    return _dir(Scaffold(
      backgroundColor: Brand.background,
      appBar: _bar(_t('My team', 'فريقي')),
      body: RefreshIndicator(
        color: brandRed, onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
          if (widget.justCreated) Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Brand.green.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: Brand.green.withOpacity(0.4))),
            child: Text(_t('Your team is created 🎉 Now invite your friends with the code.', 'فريقك اتعمل 🎉 دلوقتي ادعي صحابك بالكود.'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
          // الهيدر
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1C1A12), Color(0xFF121212)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(18), border: Border.all(color: _gold.withOpacity(0.4))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${t['name']}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: (ready ? Brand.green : muted).withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
                  child: Text(ready ? _t('Ready ✓', 'جاهز ✓') : _t('Not ready', 'لسه مش جاهز'),
                      style: TextStyle(color: ready ? Brand.green : Colors.white70, fontSize: 12, fontWeight: FontWeight.w900))),
              ]),
              const SizedBox(height: 4),
              Text('⚽ ${AppLang.isArabic ? t['format_ar'] : t['format_en']} · ${_t('Captain', 'الكابتن')}: ${(t['captain'] as Map?)?['name'] ?? ''}',
                  style: const TextStyle(color: muted, fontSize: 12.5)),
              const SizedBox(height: 14),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
                value: (count / min).clamp(0, 1).toDouble(), minHeight: 6,
                backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation(ready ? Brand.green : _gold))),
              const SizedBox(height: 6),
              Text(count < min
                  ? _t('$count of $min players · need ${min - count} more (max $max)', '$count من $min لاعيبة · ناقص ${min - count} (أقصى حاجة $max)')
                  : _t('$count players (max $max)', '$count لاعيبة (أقصى حاجة $max)'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w700)),
              if (incomplete > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Text(
                  _t('$incomplete player(s) still need to complete their info.', '$incomplete لاعب لسه مكمّلش بياناته.'),
                  style: const TextStyle(color: _gold, fontSize: 12))),
              if (times.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(
                  '🕒 ${times.map(_timeLabel).join(' · ')}', style: const TextStyle(color: muted, fontSize: 12))),
              const SizedBox(height: 14),
              // الكود
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: '${t['code']}'));
                  _snack(context, _t('Code copied', 'الكود اتنسخ'));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                  child: Row(children: [
                    Text(_t('Team code', 'كود الفريق'), style: const TextStyle(color: muted, fontSize: 12)),
                    const Spacer(),
                    Text('${t['code']}', style: const TextStyle(color: _gold, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 3)),
                    const SizedBox(width: 8),
                    const Icon(Icons.copy_rounded, color: muted, size: 16),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          if (cap && count < max) Row(children: [
            Expanded(child: SizedBox(height: 46, child: ElevatedButton.icon(onPressed: _share, style: _primary(),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: Text(_t('Invite friends', 'ادعي صحابك'), style: const TextStyle(fontWeight: FontWeight.w900))))),
            const SizedBox(width: 8),
            Expanded(child: SizedBox(height: 46, child: OutlinedButton.icon(onPressed: _busy ? null : _inviteByUsername, style: _outline(),
                icon: const Icon(Icons.alternate_email_rounded, size: 18),
                label: Text(_t('By username', 'باليوزرنيم'), style: const TextStyle(fontWeight: FontWeight.w800))))),
          ]),
          // طلبات الانضمام (الكابتن)
          if (cap && requests.isNotEmpty) ...[
            const SizedBox(height: 18),
            _title(_t('Join requests', 'طلبات الانضمام'), requests.length),
            for (final r in requests) _requestTile(r),
          ],
          const SizedBox(height: 18),
          _title(_t('Players', 'اللاعيبة'), members.length),
          for (final m in members) _memberTile(m, cap),
          // دعوات مستنية (الكابتن)
          if (cap && invites.isNotEmpty) ...[
            const SizedBox(height: 18),
            _title(_t('Invites sent', 'دعوات مستنية'), invites.length),
            for (final i in invites) _inviteTile(i),
          ],
          const SizedBox(height: 26),
          Center(child: TextButton(
            onPressed: _busy ? null : () async {
              if (cap) {
                if (!await _confirm(_t('Delete the team?', 'تحذف الفريق؟'),
                    _t('All players will be removed. This can\'t be undone.', 'كل اللاعيبة هيتشالوا، ومش هينفع ترجّعه.'), _t('Delete', 'احذف'))) return;
                await _run(() async { await TeamApi.disband(widget.teamId); if (mounted) Navigator.of(context).pop(); });
              } else {
                if (!await _confirm(_t('Leave the team?', 'تسيب الفريق؟'), _t('You can join again with the code.', 'تقدر ترجع تاني بالكود.'), _t('Leave', 'سيب'))) return;
                await _run(() async { await TeamApi.leave(widget.teamId); if (mounted) Navigator.of(context).pop(); });
              }
            },
            child: Text(cap ? _t('Delete team', 'احذف الفريق') : _t('Leave team', 'سيب الفريق'), style: const TextStyle(color: Colors.white38)),
          )),
        ]),
      ),
    ));
  }

  Widget _title(String s, int n) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text('$s · $n', style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.6)));

  Widget _sub(Map<String, dynamic> m) {
    final parts = <String>[
      if (_posLabel(m['position'] as String?).isNotEmpty) _posLabel(m['position'] as String?),
      if ((m['area_en'] ?? '').toString().isNotEmpty) '${m['area_en']}',
      if (m['age'] != null) _t('${m['age']} yrs', '${m['age']} سنة'),
    ];
    return Text(parts.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 12));
  }

  Widget _memberTile(Map<String, dynamic> m, bool cap) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
        child: Row(children: [
          _avatar(m['avatar'] as String?, '${m['name'] ?? ''}'),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text('${m['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800))),
              if (m['role'] == 'captain') const Padding(padding: EdgeInsetsDirectional.only(start: 6),
                  child: Text('©', style: TextStyle(color: _gold, fontSize: 14, fontWeight: FontWeight.w900))),
              if (m['me'] == true) Padding(padding: const EdgeInsetsDirectional.only(start: 6),
                  child: Text(_t('(you)', '(إنت)'), style: const TextStyle(color: muted, fontSize: 11.5))),
            ]),
            _sub(m),
            if (m['complete'] != true) Text(_t('Info not complete yet', 'لسه مكمّلش بياناته'), style: const TextStyle(color: _gold, fontSize: 11.5)),
          ])),
          if (cap && m['role'] != 'captain')
            IconButton(
              tooltip: _t('Remove', 'شيل'),
              icon: const Icon(Icons.person_remove_alt_1_outlined, color: muted, size: 20),
              onPressed: _busy ? null : () async {
                if (!await _confirm(_t('Remove ${m['name']}?', 'تشيل ${m['name']}؟'), _t('They can ask to join again.', 'يقدر يطلب ينضم تاني.'), _t('Remove', 'شيل'))) return;
                await _run(() => TeamApi.remove(widget.teamId, (m['user_id'] as num).toInt()));
              },
            ),
        ]),
      );

  Widget _requestTile(Map<String, dynamic> r) {
    final u = Map<String, dynamic>.from((r['user'] as Map?) ?? {});
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: brandRed.withOpacity(0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: brandRed.withOpacity(0.35))),
      child: Column(children: [
        Row(children: [
          _avatar(u['avatar'] as String?, '${u['name'] ?? ''}'),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${u['name'] ?? ''}  @${u['username'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
            _sub(r),
          ])),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: SizedBox(height: 40, child: ElevatedButton(style: _primary(),
              onPressed: _busy ? null : () => _run(() => TeamApi.decide('${r['request_id']}', true)),
              child: Text(_t('Accept', 'قبول'), style: const TextStyle(fontWeight: FontWeight.w900))))),
          const SizedBox(width: 8),
          Expanded(child: SizedBox(height: 40, child: OutlinedButton(style: _outline(),
              onPressed: _busy ? null : () => _run(() => TeamApi.decide('${r['request_id']}', false)),
              child: Text(_t('Decline', 'رفض'))))),
        ]),
      ]),
    );
  }

  Widget _inviteTile(Map<String, dynamic> i) {
    final u = Map<String, dynamic>.from((i['user'] as Map?) ?? {});
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
      child: Row(children: [
        _avatar(u['avatar'] as String?, '${u['name'] ?? ''}', size: 34),
        const SizedBox(width: 10),
        Expanded(child: Text('${u['name'] ?? ''}  @${u['username'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700))),
        TextButton(onPressed: _busy ? null : () => _run(() => TeamApi.cancel('${i['request_id']}')),
            child: Text(_t('Cancel', 'إلغاء'), style: const TextStyle(color: muted))),
      ]),
    );
  }
}
