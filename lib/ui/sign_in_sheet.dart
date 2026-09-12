import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../services/cloud/auth_service.dart';
import '../state/providers.dart';

/// Returns the signed-in user, or null if the person backed out.
Future<User?> showSignInSheet(BuildContext context) => showModalBottomSheet<User?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _SignInSheet(),
    );

class _SignInSheet extends ConsumerStatefulWidget {
  const _SignInSheet();
  @override
  ConsumerState<_SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends ConsumerState<_SignInSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<User?> Function() f) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await f();
      if (!mounted) return;
      Navigator.of(context).pop(user);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final b = ref.watch(bootstrapProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.signInTitle, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(l.signInWhy, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4)),
          const SizedBox(height: 22),
          if (!b.cloudAvailable)
            Text(l.cloudUnavailable, style: TextStyle(color: Theme.of(context).colorScheme.error))
          else ...[
            if (AuthService.appleAvailable) ...[
              FilledButton.icon(
                onPressed: _busy ? null : () => _run(b.auth.signInWithApple),
                icon: const Icon(Icons.apple),
                label: Text(l.signInApple),
                style: FilledButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _run(b.auth.signInWithGoogle),
              icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
              label: Text(l.signInGoogle),
            ),
          ],
          if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('${l.error}: $_error', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 8),
          TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: Text(l.cancel)),
        ],
      ),
    );
  }
}
