import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../l10n/strings.dart';
import '../l10n/supported.dart';
import '../state/providers.dart';

/// The first screen, once: which language the app speaks back in. Tapping
/// a language switches the whole screen to it immediately, so the person
/// reads the confirmation in their own words before continuing. The same
/// choice guides the listener (it checks that language first when a guess
/// is doubtful) and is what the app is shown in from then on.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final current = ref.watch(languageCodeProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: ImDoneTheme.accent.withValues(alpha: 0.15)),
                    child: const Icon(Icons.mic_rounded, size: 38, color: ImDoneTheme.accent),
                  ),
                  const SizedBox(height: 18),
                  Text(l.welcomeTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(l.welcomeBody, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                children: [
                  for (final lang in supportedLanguages)
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      child: ListTile(
                        title: Text(lang.$2, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                        trailing: current == lang.$1 ? Icon(Icons.check_circle_rounded, color: scheme.primary) : null,
                        selected: current == lang.$1,
                        onTap: () => ref.read(settingsProvider.notifier).update(settings.copyWith(languageCode: lang.$1)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: () => ref.read(settingsProvider.notifier).update(settings.copyWith(languageCode: current, setupDone: true)),
                child: Text(l.continueLabel, style: const TextStyle(fontSize: 17)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
