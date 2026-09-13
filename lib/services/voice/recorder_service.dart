import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'wav.dart';

/// Records the microphone as 16 kHz mono PCM while the button is held and
/// hands back a WAV. Nothing is written to disk: the samples are kept in
/// memory, uploaded, and dropped.
class RecorderService {
  static const sampleRate = 16000;
  static const maxSeconds = 45;

  AudioRecorder? _rec;
  StreamSubscription<Uint8List>? _sub;
  final BytesBuilder _buf = BytesBuilder(copy: false);
  Timer? _cap;
  void Function()? _onCap;

  bool get recording => _sub != null;

  Future<bool> hasPermission() async {
    _rec ??= AudioRecorder();
    try {
      return await _rec!.hasPermission();
    } catch (_) {
      return false;
    }
  }

  /// Starts capturing. [onCap] fires when the maximum length is reached so
  /// the UI can stop as if the finger had been lifted.
  Future<void> start({void Function()? onCap}) async {
    if (recording) return;
    _rec ??= AudioRecorder();
    _buf.clear();
    _onCap = onCap;
    final stream = await _rec!.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: 1,
      autoGain: true,
      noiseSuppress: true,
      echoCancel: true,
    ));
    _sub = stream.listen(_buf.add);
    _cap = Timer(const Duration(seconds: maxSeconds), () => _onCap?.call());
  }

  /// Stops and returns the WAV, or null when nothing usable was captured.
  Future<Uint8List?> stop() async {
    _cap?.cancel();
    _cap = null;
    final sub = _sub;
    _sub = null;
    if (sub == null) return null;
    try {
      await _rec?.stop();
    } catch (_) {}
    await sub.cancel();
    final pcm = _buf.takeBytes();
    if (pcm16Seconds(pcm.length, sampleRate: sampleRate) < 0.4) return null;
    return wavFromPcm16(pcm, sampleRate: sampleRate);
  }

  Future<void> cancel() async {
    _cap?.cancel();
    _cap = null;
    final sub = _sub;
    _sub = null;
    try {
      await _rec?.stop();
    } catch (_) {}
    await sub?.cancel();
    _buf.clear();
  }

  Future<void> dispose() async {
    await cancel();
    await _rec?.dispose();
    _rec = null;
  }
}
