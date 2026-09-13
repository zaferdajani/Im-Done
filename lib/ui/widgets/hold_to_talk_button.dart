import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform.dart';
import '../../core/theme.dart';
import '../../l10n/strings.dart';
import '../../services/settings_store.dart';
import '../../services/voice/understanding_service.dart';
import '../../state/providers.dart';

/// The whole point of the app: press, hold, talk, release.
///
/// Two ways of hearing. CLOUD (default): the recording goes to the worker,
/// which detects the language — any of 99, Arabic in every dialect — and
/// returns the task fields ([onUnderstood]). DEVICE: the phone's own
/// recogniser in the app language, nothing leaves the phone, and the plain
/// transcript is parsed locally ([onTranscript]). The device path is also
/// the fallback whenever the cloud cannot be reached.
class HoldToTalkButton extends ConsumerStatefulWidget {
  const HoldToTalkButton({super.key, required this.onTranscript, required this.onUnderstood, required this.onTypeInstead});

  final void Function(String text) onTranscript;
  final void Function(Understanding understood) onUnderstood;
  final VoidCallback onTypeInstead;

  @override
  ConsumerState<HoldToTalkButton> createState() => _HoldToTalkButtonState();
}

class _HoldToTalkButtonState extends ConsumerState<HoldToTalkButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  bool _listening = false;
  bool _understanding = false;
  bool _busy = false;
  bool _cloudThisTime = false;
  /// Set when the server said voice is not switched on; saves a round trip
  /// per hold for the rest of the session.
  static bool _cloudDown = false;
  String _partial = '';

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  bool get _wantCloud {
    final b = ref.read(bootstrapProvider);
    return ref.read(settingsProvider).voiceEngine == VoiceEngine.cloud && b.cloudAvailable && b.understanding.configured && !_cloudDown;
  }

  /// Play policy "prominent disclosure": explain the microphone BEFORE the
  /// system prompt appears, in our own dialog. Shown once.
  Future<bool> _prepare() async {
    final b = ref.read(bootstrapProvider);
    final l = ref.read(l10nProvider);
    final settings = ref.read(settingsProvider);
    if (!settings.onboarded) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.mic_rounded, size: 36),
          title: Text(l.micPermissionTitle),
          content: Text(l.micPermissionBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.micPermissionAllow)),
          ],
        ),
      );
      if (go != true) return false;
      await ref.read(settingsProvider.notifier).update(settings.copyWith(onboarded: true));
    }
    if (_wantCloud) {
      if (await b.recorder.hasPermission()) return true;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.micDenied)));
      return false;
    }
    if (b.speech.available) return true;
    final ok = await b.speech.init();
    if (!ok && mounted) {
      // On the web a failed initialise means the browser has no speech API
      // (Firefox); permission is only asked later, when listening starts.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isWeb ? l.speechUnavailableWeb : l.micDenied),
        duration: const Duration(seconds: 6),
      ));
    }
    return ok;
  }

  Future<void> _start() async {
    if (_busy) return;
    _busy = true;
    try {
      if (_understanding) return;
      if (!await _prepare()) return;
      final b = ref.read(bootstrapProvider);
      _cloudThisTime = _wantCloud;
      HapticFeedback.mediumImpact();
      setState(() {
        _listening = true;
        _partial = '';
      });
      if (_cloudThisTime) {
        await b.recorder.start(onCap: () => _stop());
      } else {
        final locale = await b.speech.localeFor(ref.read(languageCodeProvider));
        await b.speech.start(localeId: locale, onPartial: (t) => setState(() => _partial = t));
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _stop({bool cancelled = false}) async {
    if (!_listening) return;
    final b = ref.read(bootstrapProvider);
    HapticFeedback.lightImpact();
    if (_cloudThisTime) {
      final wav = cancelled ? null : await b.recorder.stop();
      if (cancelled) await b.recorder.cancel();
      if (!mounted) return;
      setState(() => _listening = false);
      if (wav != null) await _understand(wav);
      return;
    }
    final text = cancelled ? '' : await b.speech.stop();
    if (cancelled) await b.speech.cancel();
    if (!mounted) return;
    setState(() => _listening = false);
    if (text.trim().isNotEmpty) {
      widget.onTranscript(text.trim());
    }
  }

  Future<void> _understand(Uint8List wav) async {
    final b = ref.read(bootstrapProvider);
    final l = ref.read(l10nProvider);
    setState(() => _understanding = true);
    String? problem;
    Understanding? result;
    try {
      // The worker serves signed-in callers only; a nameless anonymous
      // identity is enough for that, and sharing still asks for a name.
      await b.auth.ensureSignedIn();
      final token = await b.auth.idToken();
      if (token == null) throw UnderstandingException('offline');
      result = await b.understanding.understand(wav, idToken: token, uiLanguage: ref.read(languageCodeProvider));
    } on UnderstandingException catch (e) {
      problem = switch (e.code) {
        'offline' => l.voiceOffline,
        'nothing_heard' => l.voiceNothingHeard,
        'unconfigured' => l.voiceUnconfigured,
        _ => l.voiceFailed,
      };
      if (e.code == 'unconfigured') _cloudDown = true;
    } catch (_) {
      problem = l.voiceFailed;
    }
    if (!mounted) return;
    setState(() => _understanding = false);
    if (result != null) {
      widget.onUnderstood(result);
    } else if (problem != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem), duration: const Duration(seconds: 5)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _listening || _understanding
              ? Container(
                  key: const ValueKey('transcript'),
                  margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_understanding) ...[
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 12),
                      ],
                      Flexible(
                        child: Text(
                          _understanding ? l.understanding : (_partial.isEmpty ? l.listening : _partial),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 17, color: _partial.isEmpty || _understanding ? scheme.onSurfaceVariant : scheme.onSurface),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(height: 0, key: ValueKey('none')),
        ),
        GestureDetector(
          onLongPressStart: (_) => _start(),
          onLongPressEnd: (_) => _stop(),
          onLongPressCancel: () => _stop(cancelled: true),
          onTap: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.holdToSpeak), duration: const Duration(seconds: 1)));
          },
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) {
              final scale = _listening ? 1.0 + _pulse.value * 0.12 : 1.0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  if (_listening)
                    Container(
                      width: 120 * (1 + _pulse.value * 0.5),
                      height: 120 * (1 + _pulse.value * 0.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ImDoneTheme.accent.withValues(alpha: 0.18 * (1 - _pulse.value)),
                      ),
                    ),
                  Transform.scale(scale: scale, child: child),
                ],
              );
            },
            child: Semantics(
              button: true,
              label: l.holdToSpeak,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _listening
                        ? [const Color(0xFFFF6A3D), const Color(0xFFFF9F5A)]
                        : [scheme.primary, scheme.primary.withValues(alpha: 0.8)],
                  ),
                  boxShadow: [
                    BoxShadow(color: (_listening ? ImDoneTheme.accent : scheme.primary).withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
                  ],
                ),
                child: Icon(_listening ? Icons.graphic_eq_rounded : Icons.mic_rounded, color: Colors.white, size: 42),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(_listening ? l.releaseToFinish : l.holdToSpeak, style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
        TextButton.icon(
          onPressed: widget.onTypeInstead,
          icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
          label: Text(l.typeInstead),
        ),
      ],
    );
  }
}
