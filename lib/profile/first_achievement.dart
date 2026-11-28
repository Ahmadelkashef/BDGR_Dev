import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_lang.dart';
import '../local_store.dart';
import '../motion_kit.dart';
import '../push/push_ask.dart' show PushRemindButton;
import 'level_looks.dart' show ConfettiBit, ConfettiPainter;
import 'profile_trophies.dart';
import 'trophy_cabinet.dart' show debutTrophyArt, ArenaLevel, levelName;

// ═════════════════════════════════════════════════════════════════════════
// First achievement (owner, 28 Nov): the very first squad a user ever saves →
// a celebration ("your first achievement: First round +2 pts") → "See my cabinet" takes him to his profile,
// scrolls to the cabinet, the First round trophy drops onto its shelf, and a card shows the points,
// New n/34 and the glowing "Complete profile" next step (+30 → almost Rookie).
// That first time the complete-profile sheet is NOT shown after the save; from the 2nd save it is (once per round).
// Only once per phone (key first_achv_done); old users (more than one saved round) never see it. Switch profile_first_achv.
// ═════════════════════════════════════════════════════════════════════════

/// The profile page listens: 'first' = scroll to the cabinet and play the first-achievement landing.
class ProfileFocus {
  ProfileFocus._();
  static final ValueNotifier<String?> pending = ValueNotifier<String?>(null);
}

/// After a squad save. Returns true when the first-achievement moment ran (the caller then skips the profile sheet).
Future<bool> maybeFirstAchievement(BuildContext context, {VoidCallback? onSeeCabinet}) async {
  try {
    if (await LocalStore.getStr('first_achv_done') != null) return false;
    final sb = Supabase.instance.client;
    final id = await sb.rpc('get_my_iplay_user_id');
    final uid = id is num ? id.toInt() : int.tryParse('$id');
    if (uid == null) return false;
    final t = await ProfileTrophies.load(uid);
    if (t == null) return false;
    final saved = t.savedRounds('LOCAL') + t.savedRounds('WORLD');
    // only the very first saved round; anyone with more history never gets it
    await LocalStore.setStr('first_achv_done', '1');
    if (saved != 1 || !ProfileUi.firstAchv || !context.mounted) return false;
    final go = await showGeneralDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierLabel: 'first',
      barrierColor: Colors.black.withOpacity(0.9),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => _FirstView(t: t),
    );
    if (go == true) {
      ProfileFocus.pending.value = 'first';
      onSeeCabinet?.call();
    }
    return true;
  } catch (_) {
    return false;
  }
}

class _FirstView extends StatefulWidget {
  const _FirstView({required this.t});
  final ProfileTrophies t;
  @override
  State<_FirstView> createState() => _FirstViewState();
}

class _FirstViewState extends State<_FirstView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  late final List<ConfettiBit> _bits = List.generate(70, (_) => ConfettiBit(math.Random()));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      _c.forward();
      Buzz.medium();
      Future.delayed(const Duration(milliseconds: 160), Buzz.medium);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calm = calmMotion(context);
    final pts = ProfileUi.levelPts['round'] ?? 2;
    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        if (!calm) Positioned.fill(child: IgnorePointer(child: AnimatedBuilder(animation: _c,
            builder: (_, __) => CustomPaint(painter: ConfettiPainter(_bits, ((_c.value - 0.2) / 0.8).clamp(0.0, 1.0).toDouble(),
                const [Color(0xFFFFD27A), Color(0xFFFF3B3B), Colors.white, Color(0xFFC97B45)]))))),
        Center(child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, child) {
              final v = calm ? 1.0 : Curves.elasticOut.transform((_c.value / 0.6).clamp(0.0, 1.0).toDouble());
              final glow = calm ? 0.6 : (_c.value).clamp(0.0, 1.0).toDouble();
              return Stack(alignment: Alignment.center, children: [
                Container(width: 260, height: 260, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(
                    colors: [const Color(0xFFFFD27A).withOpacity(0.35 * glow), const Color(0x00FFD27A)]))),
                Transform.scale(scale: 0.3 + 0.7 * v, child: child),
              ]);
            },
            child: debutTrophyArt(120),
          ),
          const SizedBox(height: 10),
          Text(AppLang.t('YOUR FIRST ACHIEVEMENT', 'أول إنجاز ليك'),
              style: const TextStyle(color: Color(0xFFFFD27A), fontSize: 12, letterSpacing: 3, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(AppLang.t('First round 🎉', 'First round 🎉'),
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(AppLang.t('+$pts points · your story starts today', '+$pts نقطة · تاريخك بيبدأ من النهارده'),
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.emoji_events_outlined, size: 19),
            label: Text(AppLang.t('See my cabinet', 'شوف دولابك'), style: const TextStyle(fontWeight: FontWeight.w900)),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF0000), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
          TextButton(onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppLang.t('Later', 'بعدين'), style: const TextStyle(color: Colors.white54))),
          // owner 28 Nov: the notification permission is offered here (first save), not at app open
          const PushRemindButton(),
        ]))),
      ]),
    );
  }
}

/// The card above the cabinet on that first visit: points, New n/34 bar, and the next step (complete profile +30).
class FirstAchievementCard extends StatelessWidget {
  const FirstAchievementCard({super.key, required this.t, this.onCompleteProfile, this.onClose});
  final ProfileTrophies t;
  final VoidCallback? onCompleteProfile;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final a = ArenaLevel.of(t, 'LOCAL'), b = ArenaLevel.of(t, 'WORLD');
    final lv = a.points >= b.points ? a : b;
    final next = lv.next;
    final prof = ProfileUi.levelPts['profile'] ?? 30;
    final rnd = ProfileUi.levelPts['round'] ?? 2;
    final after = lv.points + (t.profileComplete ? 0 : prof);
    final frac = next == null ? 1.0 : ((lv.points - lv.floor) / (next - lv.floor)).clamp(0.0, 1.0).toDouble();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x88FFD27A)),
        gradient: const LinearGradient(colors: [Color(0xFF2A2210), Color(0xF016171B)]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Text('🎉', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(child: Text(AppLang.t('First round · +$rnd points', 'First round · +$rnd نقطة'),
              style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w900))),
          if (onClose != null) GestureDetector(onTap: onClose, child: const Icon(Icons.close, color: Colors.white38, size: 18)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Text(lv.name, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(height: 7,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: frac), duration: const Duration(milliseconds: 1400), curve: Curves.easeOutCubic,
              builder: (_, f, __) => Stack(children: [
                Container(color: Colors.white10),
                FractionallySizedBox(widthFactor: f, child: Container(decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFFC97B45), Color(0xFFFFD27A)])))),
              ]),
            )))),
          const SizedBox(width: 8),
          if (next != null) Text('${lv.points}/$next', style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
        if (!t.profileComplete && next != null && onCompleteProfile != null) ...[
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCompleteProfile,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: const Color(0x22FFD27A), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xAAFFD27A))),
              child: Row(children: [
                const Text('🎯', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(child: Text(after >= next
                    ? AppLang.t('Complete your profile: +$prof → you become ${levelName(lv.level + 1)}!',
                        'كمّل بروفايلك: +$prof ← هتبقى ${levelName(lv.level + 1)}!')
                    : AppLang.t('Complete your profile: +$prof → $after/$next, almost ${levelName(lv.level + 1)}',
                        'كمّل بروفايلك: +$prof ← $after/$next، قربت جداً من ${levelName(lv.level + 1)}'),
                    style: const TextStyle(color: Color(0xFFFFD27A), fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.3))),
                const Icon(Icons.chevron_right, color: Color(0xFFFFD27A)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}
