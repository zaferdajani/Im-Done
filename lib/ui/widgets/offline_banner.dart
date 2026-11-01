import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/connectivity.dart';
import '../../state/providers.dart';

/// Wraps the app and shows a slim banner while offline.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineProvider).value ?? true;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (!online)
          Material(
            color: scheme.errorContainer,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(children: [
                  Icon(Icons.cloud_off_rounded, size: 16, color: scheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(child: Text(ref.watch(l10nProvider).offlineBanner, style: TextStyle(fontSize: 12, color: scheme.onErrorContainer))),
                ]),
              ),
            ),
          ),
        // Tablets (768-1366px): keep lists readable instead of stretching edge to edge.
        Expanded(child: Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: child ?? const SizedBox.shrink()))),
      ],
    );
  }
}
