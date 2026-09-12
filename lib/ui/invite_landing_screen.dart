import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/platform.dart';
import '../l10n/strings.dart';
import '../services/cloud/cloud.dart';
import '../state/providers.dart';
import 'sign_in_sheet.dart';
import 'task_detail_screen.dart';

/// What an invite link opens: on the web for people who may not have the app
/// yet (open in app / download / continue here), and in the app as the
/// confirmation step before joining.
class InviteLandingScreen extends ConsumerStatefulWidget {
  const InviteLandingScreen({super.key, required this.code});
  final String code;

  @override
  ConsumerState<InviteLandingScreen> createState() => _InviteLandingScreenState();
}

class _InviteLandingScreenState extends ConsumerState<InviteLandingScreen> {
  bool _busy = false;

  Future<void> _join() async {
    final l = ref.read(l10nProvider);
    final b = ref.read(bootstrapProvider);
    if (!b.cloudAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.cloudUnavailable)));
      return;
    }
    if (ref.read(authUserProvider).value == null) {
      final user = await showSignInSheet(context);
      if (user == null || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final taskId = await ref.read(taskActionsProvider).join(widget.code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.joined)));
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: taskId)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.joinFailed)));
    }
  }

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              Icon(Icons.group_add_rounded, size: 64, color: scheme.primary),
              const SizedBox(height: 18),
              Text(l.inviteTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(l.inviteBody, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45)),
              const SizedBox(height: 18),
              Center(
                child: Chip(
                  avatar: const Icon(Icons.key_rounded, size: 18),
                  label: Text('${l.inviteCodeLabel}: ${widget.code}', style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _busy ? null : _join,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_rounded),
                label: Text(l.inviteContinue),
              ),
              if (isWeb) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _open('imdone://join/${widget.code}'),
                  icon: const Icon(Icons.phone_iphone_rounded),
                  label: Text(l.inviteOpenApp),
                ),
                const SizedBox(height: 18),
                Text(l.inviteNoAppHint, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, height: 1.4)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextButton.icon(onPressed: () => _open(Cloud.playStoreUrl), icon: const Icon(Icons.android_rounded), label: Text(l.inviteGetAndroid))),
                  Expanded(child: TextButton.icon(onPressed: () => _open(Cloud.appStoreUrl), icon: const Icon(Icons.apple), label: Text(l.inviteGetIos))),
                ]),
              ],
              const SizedBox(height: 6),
              TextButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(l.notNow)),
            ],
          ),
        ),
      ),
    );
  }
}
