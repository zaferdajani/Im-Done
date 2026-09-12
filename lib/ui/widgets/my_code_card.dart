import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/strings.dart';
import '../../services/cloud/cloud.dart';
import '../../state/providers.dart';

/// "My code": the personal code as text and as a QR that opens the
/// add-this-person screen when scanned by the app or by a phone camera.
class MyCodeCard extends ConsumerWidget {
  const MyCodeCard({super.key});

  static String linkFor(String code) => '${Cloud.personBaseUrl}/$code';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final code = ref.watch(myCodeProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: code.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
          error: (e, _) => Text('${l.error}: $e', style: TextStyle(color: scheme.error)),
          data: (c) => c == null
              ? Text(l.cloudUnavailable, style: TextStyle(color: scheme.onSurfaceVariant))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l.myCode, style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: QrImageView(data: linkFor(c), size: 180, backgroundColor: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: SelectableText(
                        '${c.substring(0, 4)}-${c.substring(4)}',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 3),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(l.myCodeHint, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: c));
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.linkCopied)));
                          },
                          icon: const Icon(Icons.copy_rounded),
                          label: Text(l.copyLink),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () => SharePlus.instance.share(ShareParams(text: '${l.shareMyCodeMessage.fill({'code': c})} ${linkFor(c)}')),
                          icon: const Icon(Icons.share_rounded),
                          label: Text(l.invite),
                        ),
                      ),
                    ]),
                  ],
                ),
        ),
      ),
    );
  }
}
