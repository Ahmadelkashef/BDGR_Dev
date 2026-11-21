import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compressor_plus/video_compressor_plus.dart';

import '../app_lang.dart';
import '../brand.dart';
import '../web/iframe_view.dart' show webVideoInfo;
import 'ugc_api.dart';
import '../web/web_layout.dart' show WebStage;

/// بوست جديد: صور وفيديوهات بأي خليط (لحد 10 في البوست). الحد الوحيد = مساحة اليوزر (100 ميجا).
/// الفيديو بيتضغط على الموبايل قبل الرفع، والصور بتتصغّر — علشان الرفع أسرع والمساحة تكفّي.
Future<UgcItem?> openUgcComposer(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push<UgcItem>(
    MaterialPageRoute(builder: (_) => const WebStage(maxWidth: 680, background: Color(0xFF050507), showClose: false, child: UgcComposerPage()), fullscreenDialog: true),
  );
}

class _Picked {
  _Picked({required this.x, required this.type, this.durationS, this.thumb, this.bytes, this.w, this.h});
  final XFile x;
  final String type; // image | video
  final double? durationS;
  final Uint8List? thumb; // صورة صغيرة للفيديو في المعاينة (وعلى الويب = الغلاف اللي هيترفع)
  final Uint8List? bytes; // الويب: الصورة نفسها
  final int? w, h;
  File get file => File(x.path);   // الموبايل بس
}

const _videoExt = ['.mp4', '.mov', '.m4v', '.3gp', '.webm', '.mkv'];

class UgcComposerPage extends StatefulWidget {
  const UgcComposerPage({super.key});
  @override
  State<UgcComposerPage> createState() => _UgcComposerPageState();
}

class _UgcComposerPageState extends State<UgcComposerPage> {
  final _picker = ImagePicker();
  final _caption = TextEditingController();
  final List<_Picked> _files = [];
  UgcLimits? _lim;
  String? _limErr;
  bool _busy = false;
  String _step = '';
  double? _progress;

  bool get _ar => AppLang.isArabic;
  String _t(String en, String ar) => _ar ? ar : en;
  int get _maxFiles => _lim?.postMaxFiles ?? 10;

  @override
  void initState() {
    super.initState();
    UgcApi.limits().then((l) {
      if (mounted) setState(() => _lim = l);
    }).catchError((_) {
      if (mounted) setState(() => _limErr = _t("Couldn't load your space", 'مقدرناش نجيب مساحتك'));
    });
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  /// زرار واحد: يختار صور أو فيديوهات مع بعض
  Future<void> _pick() async {
    final room = _maxFiles - _files.length;
    if (room <= 0 || _busy) return;
    try {
      final picked = room == 1
          ? [await _picker.pickMedia(maxWidth: 1440, maxHeight: 1440, imageQuality: 82)]
          : await _picker.pickMultipleMedia(maxWidth: 1440, maxHeight: 1440, imageQuality: 82, limit: room);
      final maxS = _lim?.postVideoMaxS ?? 60;
      var tooLong = 0;
      for (final x in picked.whereType<XFile>().take(room)) {
        final isVideo = _videoExt.any((e) => x.path.toLowerCase().endsWith(e)) ||
            (x.mimeType ?? '').startsWith('video/');
        if (kIsWeb) {
          // الويب: مفيش ضغط فيديو؛ المدة والغلاف من المتصفح
          if (!isVideo) {
            _files.add(_Picked(x: x, type: 'image', bytes: await x.readAsBytes()));
            continue;
          }
          final info = await webVideoInfo(x.path);
          final secs = info?.secs ?? 0;
          if (secs > maxS + 0.5) { tooLong++; continue; }
          _files.add(_Picked(x: x, type: 'video', durationS: secs,
              thumb: info?.poster == null ? null : Uint8List.fromList(info!.poster!),
              w: info?.w, h: info?.h));
          continue;
        }
        if (!isVideo) {
          _files.add(_Picked(x: x, type: 'image'));
          continue;
        }
        final info = await VideoCompress.getMediaInfo(x.path);
        final secs = (info.duration ?? 0) / 1000;
        if (secs > maxS + 0.5) { tooLong++; continue; }
        Uint8List? thumb;
        try { thumb = await VideoCompress.getByteThumbnail(x.path, quality: 40, position: 1000); } catch (_) {}
        _files.add(_Picked(x: x, type: 'video', durationS: secs, thumb: thumb));
      }
      if (mounted) setState(() {});
      if (tooLong > 0) {
        _snack(_t('Videos must be $maxS seconds or less — $tooLong skipped.',
            'الفيديو لازم يكون $maxS ثانية أو أقل — اتشال $tooLong.'));
      }
    } catch (e) {
      _snack(_t("Couldn't open your gallery", 'مقدرناش نفتح المعرض'));
    }
  }

  Future<UgcUploadFile> _prepare(_Picked p) async {
    if (kIsWeb) {
      final name = p.x.name.isNotEmpty ? p.x.name : (p.type == 'video' ? 'v.mp4' : 'i.jpg');
      return UgcUploadFile(
        type: p.type,
        name: name,
        bytes: p.bytes ?? await p.x.readAsBytes(),
        posterBytes: p.type == 'video' ? p.thumb : null,
        durationS: p.durationS,
        width: p.w,
        height: p.h,
      );
    }
    if (p.type == 'image') {
      return UgcUploadFile(file: p.file, type: 'image');
    }
    setState(() { _step = _t('Compressing the video…', 'بنضغط الفيديو…'); _progress = 0; });
    final sub = VideoCompress.compressProgress$.subscribe((v) {
      if (mounted) setState(() => _progress = (v / 100).clamp(0.0, 1.0).toDouble());
    });
    MediaInfo? out;
    try {
      out = await VideoCompress.compressVideo(p.file.path,
          quality: VideoQuality.MediumQuality, deleteOrigin: false, includeAudio: true);
    } finally {
      sub.unsubscribe();
    }
    var file = p.file;
    if (out?.file != null && (out!.filesize ?? 1 << 40) < await p.file.length()) file = out.file!;
    final poster = await VideoCompress.getFileThumbnail(file.path, quality: 70, position: 1000);
    return UgcUploadFile(
      file: file,
      type: 'video',
      poster: poster,
      durationS: ((out?.duration ?? (p.durationS ?? 0) * 1000) / 1000),
      width: out?.width,
      height: out?.height,
    );
  }

  Future<void> _publish() async {
    if (_files.isEmpty || _busy) return;
    final lim = _lim;
    if (lim != null && lim.banned) { _snack(UgcError('ugc_banned').message); return; }
    setState(() { _busy = true; _progress = null; });
    try {
      final ready = <UgcUploadFile>[];
      for (final f in _files) {
        ready.add(await _prepare(f));
      }
      var bytes = 0;
      for (final f in ready) {
        bytes += await f.size();
      }
      if (lim != null && bytes > lim.freeBytes) throw UgcError('quota_full');
      setState(() { _step = _t('Uploading…', 'بنرفع…'); _progress = 0; });
      final item = await UgcApi.publish(
        kind: 'post',
        files: ready,
        caption: _caption.text.trim().isEmpty ? null : _caption.text.trim(),
        onProgress: (d, t) { if (mounted) setState(() => _progress = d / t); },
      );
      if (!kIsWeb) VideoCompress.deleteAllCache();
      if (mounted) Navigator.of(context).pop(item);
    } on UgcError catch (e) {
      if (mounted) { setState(() => _busy = false); _snack(e.message); }
    } catch (e) {
      if (mounted) { setState(() => _busy = false); _snack(UgcError('unknown').message); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lim = _lim;
    return Directionality(
      textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Brand.background,
        appBar: AppBar(
          backgroundColor: Brand.background,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(_t('New post', 'بوست جديد'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: _busy ? null : () => Navigator.pop(context)),
        ),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
            if (lim != null) _quota(lim) else if (_limErr != null)
              Text(_limErr!, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            if (lim?.banned == true) ...[
              const SizedBox(height: 10),
              _note(UgcError('ugc_banned').message, Brand.navAccent),
            ],
            const SizedBox(height: 14),
            if (_files.isEmpty) _emptyPicker() else _pickedStrip(),
            const SizedBox(height: 8),
            Text(
              _t('Photos and videos, any mix (up to $_maxFiles per post, videos up to ${lim?.postVideoMaxS ?? 60} s).',
                  'صور وفيديوهات زي ما تحب (لحد $_maxFiles في البوست، والفيديو لحد ${lim?.postVideoMaxS ?? 60} ثانية).'),
              style: const TextStyle(color: Colors.white38, fontSize: 11.5, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _caption,
              enabled: !_busy,
              maxLength: 300,
              minLines: 2,
              maxLines: 5,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: _t('Write something (optional)', 'اكتب حاجة (اختياري)'),
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF16171C),
                counterStyle: const TextStyle(color: Colors.white24, fontSize: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),
            if (_busy) ...[
              Text(_step, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: _progress, minHeight: 4,
                    color: Brand.navAccent, backgroundColor: Colors.white10),
              ),
              const SizedBox(height: 14),
            ],
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _files.isEmpty || _busy || lim?.banned == true ? null : _publish,
                style: FilledButton.styleFrom(
                  backgroundColor: Brand.navAccent,
                  disabledBackgroundColor: Colors.white10,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(_t('Post', 'انشر'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _t('Only post what you have the right to post. Reported posts can be hidden or removed.',
                  'نزّل بس اللي من حقك تنزّله. البوستات اللي عليها بلاغات ممكن تستخبى أو تتمسح.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white30, fontSize: 11, height: 1.5),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _quota(UgcLimits l) {
    final used = l.usedBytes / (l.quotaBytes == 0 ? 1 : l.quotaBytes);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_t('Your space: ${UgcApi.mb(l.usedBytes)} of ${UgcApi.mb(l.quotaBytes)} MB',
              'مساحتك: ${UgcApi.mb(l.usedBytes)} من ${UgcApi.mb(l.quotaBytes)} ميجا'),
          style: const TextStyle(color: Colors.white60, fontSize: 12)),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(value: used.clamp(0.0, 1.0).toDouble(), minHeight: 4,
            color: used > 0.9 ? Brand.navAccent : Colors.white54, backgroundColor: Colors.white10),
      ),
    ]);
  }

  Widget _note(String text, Color c) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.withValues(alpha: 0.4))),
        child: Text(text, style: TextStyle(color: c, fontSize: 12.5, height: 1.5)),
      );

  // مفيش ملفات لسه: خانة واحدة كبيرة واضحة
  Widget _emptyPicker() => InkWell(
        onTap: _busy ? null : _pick,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 220,
          decoration: BoxDecoration(color: const Color(0xFF16171C), borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: Brand.navAccent.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(Icons.add_photo_alternate_outlined, color: Brand.navAccent, size: 28),
            ),
            const SizedBox(height: 12),
            Text(_t('Add photos or videos', 'ضيف صور أو فيديوهات'),
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(_t('From your gallery', 'من المعرض بتاعك'),
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ]),
        ),
      );

  // الملفات اللي اختارها + خانة "ضيف" لو لسه فيه مكان
  Widget _pickedStrip() {
    final canAdd = _files.length < _maxFiles && !_busy;
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _files.length + (canAdd ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == _files.length) {
            return InkWell(
              onTap: _pick,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 110,
                decoration: BoxDecoration(color: const Color(0xFF16171C), borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add_rounded, color: Colors.white70, size: 30),
                  const SizedBox(height: 4),
                  Text(_t('Add', 'ضيف'), style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                ]),
              ),
            );
          }
          final f = _files[i];
          return SizedBox(
            width: 150,
            child: Stack(fit: StackFit.expand, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: f.type == 'image'
                    ? (kIsWeb
                        ? Image.memory(f.bytes!, fit: BoxFit.cover, cacheWidth: 400)
                        : Image.file(f.file, fit: BoxFit.cover, cacheWidth: 400))
                    : (f.thumb != null
                        ? Image.memory(f.thumb!, fit: BoxFit.cover)
                        : const ColoredBox(color: Color(0xFF16171C),
                            child: Center(child: Icon(Icons.videocam_rounded, color: Colors.white54, size: 32)))),
              ),
              if (f.type == 'video')
                PositionedDirectional(
                  start: 8, bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
                      Text(' ${(f.durationS ?? 0).round()}s', style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ]),
                  ),
                ),
              if (!_busy)
                PositionedDirectional(
                  top: 6, end: 6,
                  child: GestureDetector(
                    onTap: () => setState(() => _files.removeAt(i)),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}
