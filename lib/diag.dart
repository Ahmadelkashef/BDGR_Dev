// Diagnostics (animation branch only, temporary): find why the app closes.
// - Breadcrumbs are written to a file SYNCHRONOUSLY, so they survive a hard crash.
// - Flutter/Dart errors are saved to the same file.
// - On the next open, Android's own record of the last exits (ApplicationExitInfo:
//   crash / native crash / out of memory / ANR + trace) is read via MainActivity and
//   sent with the breadcrumbs to the server (diag_report → app_diag_reports).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Diag {
  static const _ch = MethodChannel('bdgr/diag');
  static const build = 'diag-2';
  static File? _file;
  static bool _sent = false;

  /// Call once in main() after ensureInitialized.
  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      final dir = await _ch.invokeMethod<String>('dir');
      if (dir != null) {
        _file = File('$dir/bdgr_crumbs.txt');
        // keep the previous run's crumbs for the report, start a new file for this run
        final prev = File('$dir/bdgr_crumbs_prev.txt');
        if (_file!.existsSync()) {
          if (prev.existsSync()) prev.deleteSync();
          _file!.renameSync(prev.path);
        }
      }
    } catch (_) {}
    crumb('app start');
    final prevOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      crumb('FLUTTER ERROR: ${d.exceptionAsString()}\n${d.stack.toString().split('\n').take(25).join('\n')}');
      prevOnError?.call(d);
    };
    PlatformDispatcher.instance.onError = (e, st) {
      crumb('DART ERROR: $e\n${st.toString().split('\n').take(25).join('\n')}');
      return false;
    };
  }

  /// Short line, written to disk right away (survives a crash).
  static void crumb(String s) {
    final f = _file;
    if (f == null) return;
    try {
      f.writeAsStringSync('${DateTime.now().toIso8601String().substring(11, 23)} $s\n',
          mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  static String _last = '';
  /// Same as crumb, but skips a line identical to the previous one (for build methods).
  static void step(String s) { if (s == _last) return; _last = s; crumb(s); }

  /// Call after login (MainShell). Sends Android's record of the last exits once.
  static Future<void> sendPending() async {
    if (kIsWeb || _sent) return;
    _sent = true;
    try {
      final sp = await SharedPreferences.getInstance();
      final lastTs = sp.getInt('diag_last_exit_ts') ?? 0;
      final dir = await _ch.invokeMethod<String>('dir');
      String prevCrumbs = '';
      if (dir != null) {
        final prev = File('$dir/bdgr_crumbs_prev.txt');
        if (prev.existsSync()) {
          final t = prev.readAsStringSync();
          prevCrumbs = t.length > 7000 ? t.substring(t.length - 7000) : t;
        }
      }
      final exits = await _ch.invokeListMethod<dynamic>('lastExits') ?? const [];
      var newest = lastTs;
      var first = true;
      for (final raw in exits) {
        final e = Map<String, dynamic>.from(raw as Map);
        final ts = (e['ts'] as num?)?.toInt() ?? 0;
        if (ts <= lastTs) continue;
        if (ts > newest) newest = ts;
        await Supabase.instance.client.rpc('diag_report', params: {'p': {
          'app_id': 'com.bdgr.app',
          'build': build,
          'kind': 'exit',
          'reason': e['reason'],
          'description': e['description'],
          'exit_ts': ts,
          'trace': e['trace'],
          'crumbs': first ? prevCrumbs : null,
          'extra': {'status': e['status'], 'importance': e['importance'], 'pss': e['pss'], 'rss': e['rss'],
                    'trace_b64': e['b64'] == true, 'sdk': e['sdk']},
        }});
        first = false;
      }
      // no Android record (old Android) but the last run left crumbs with an error → send them too
      if (first && prevCrumbs.contains('ERROR')) {
        await Supabase.instance.client.rpc('diag_report', params: {'p': {
          'app_id': 'com.bdgr.app', 'build': build, 'kind': 'crumbs', 'crumbs': prevCrumbs,
          'extra': {'note': jsonEncode(exits.length)},
        }});
      }
      if (newest > lastTs) await sp.setInt('diag_last_exit_ts', newest);
    } catch (e) {
      crumb('diag send failed: $e');
    }
  }
}
