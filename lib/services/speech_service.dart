import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

/// Thin wrapper over the platform speech recogniser (Apple Speech on iOS,
/// Android SpeechRecognizer). Audio is handled by the OS service and is never
/// written to disk by this app.
class SpeechService {
  final SpeechToText _stt = SpeechToText();
  bool _initialised = false;
  bool _available = false;
  String _last = '';
  Completer<void>? _finalDone;

  bool get available => _available;
  bool get listening => _stt.isListening;

  /// Initialises the recogniser. Triggers the OS microphone/speech prompts on
  /// first call, which is why the UI shows its own explanation dialog first.
  Future<bool> init() async {
    if (_initialised) return _available;
    _initialised = true;
    try {
      _available = await _stt.initialize(
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') {
            _finalDone?.complete();
            _finalDone = null;
          }
        },
        onError: (_) {
          _finalDone?.complete();
          _finalDone = null;
        },
      );
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  /// Best matching locale id for the app language ("ar" / "en").
  Future<String?> localeFor(String languageCode) async {
    try {
      final all = await _stt.locales();
      String norm(String s) => s.toLowerCase().replaceAll('-', '_');
      final preferred = languageCode == 'ar' ? ['ar_jo', 'ar_sa', 'ar_ae', 'ar_eg', 'ar'] : ['en_us', 'en_gb', 'en'];
      for (final p in preferred) {
        final hit = all.where((l) => norm(l.localeId).startsWith(p)).firstOrNull;
        if (hit != null) return hit.localeId;
      }
      return all.where((l) => norm(l.localeId).startsWith(languageCode)).firstOrNull?.localeId;
    } catch (_) {
      return null;
    }
  }

  Future<void> start({String? localeId, required void Function(String text) onPartial}) async {
    _last = '';
    _finalDone = Completer<void>();
    await _stt.listen(
      onResult: (r) {
        _last = r.recognizedWords;
        onPartial(_last);
        if (r.finalResult) {
          _finalDone?.complete();
          _finalDone = null;
        }
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 4),
        localeId: localeId,
      ),
    );
  }

  /// Stops listening and returns the final transcript, waiting briefly for the
  /// recogniser to flush its last words.
  Future<String> stop() async {
    final done = _finalDone;
    await _stt.stop();
    if (done != null) {
      await done.future.timeout(const Duration(milliseconds: 1500), onTimeout: () {});
    }
    return _last.trim();
  }

  Future<void> cancel() async {
    _finalDone = null;
    await _stt.cancel();
  }
}
