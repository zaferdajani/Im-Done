import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../services/cloud/auth_service.dart';
import '../state/providers.dart';

/// Returns the signed-in user, or null if the person backed out.
/// The fast door is "type your name, start now" (an instant account with no
/// email or password); Google / Apple are offered to keep the account across
/// phones. Apple is required on iOS whenever Google is shown (guideline 4.8).
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
  late final TextEditingController _name = TextEditingController(text: ref.read(settingsProvider).displayName);
  late final TextEditingController _email = TextEditingController();
  late final TextEditingController _password = TextEditingController();
  bool _busy = false;
  bool _emailMode = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<User?> Function() f) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await f();
      if (!mounted) return;
      final name = _name.text.trim();
      if (name.isNotEmpty) {
        final s = ref.read(settingsProvider);
        await ref.read(settingsProvider.notifier).update(s.copyWith(displayName: name));
      }
      if (mounted) Navigator.of(context).pop(user);
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.quickStartTitle, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(l.quickStartHint, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4)),
            const SizedBox(height: 16),
            if (!b.cloudAvailable)
              Text(l.cloudUnavailable, style: TextStyle(color: scheme.error))
            else ...[
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(hintText: l.yourName, prefixIcon: const Icon(Icons.person_outline_rounded)),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy || _name.text.trim().isEmpty ? null : () => _run(() => b.auth.signInQuick(_name.text)),
                icon: const Icon(Icons.bolt_rounded),
                label: Text(l.startNow),
              ),
              const SizedBox(height: 20),
              Text(l.keepAccountHint, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, height: 1.4)),
              const SizedBox(height: 10),
              if (AuthService.appleAvailable) ...[
                FilledButton.icon(
                  onPressed: _busy ? null : () => _run(b.auth.signInWithApple),
                  icon: const Icon(Icons.apple),
                  label: Text(l.signInApple),
                  style: FilledButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _run(b.auth.signInWithGoogle),
                icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                label: Text(l.signInGoogle),
              ),
              const SizedBox(height: 10),
              if (!_emailMode)
                TextButton.icon(
                  onPressed: _busy ? null : () => setState(() => _emailMode = true),
                  icon: const Icon(Icons.mail_outline_rounded),
                  label: Text(l.useEmail),
                )
              else ...[
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(hintText: l.emailLabel, prefixIcon: const Icon(Icons.mail_outline_rounded)),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(hintText: l.passwordLabel, prefixIcon: const Icon(Icons.lock_outline_rounded)),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 6),
                Text(l.emailHint, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: _busy || !_email.text.contains('@') || _password.text.length < 6
                      ? null
                      : () => _run(() => b.auth.signInWithEmail(_email.text, _password.text, displayName: _name.text)),
                  icon: const Icon(Icons.mail_rounded),
                  label: Text(l.emailContinue),
                ),
                TextButton(
                  onPressed: _busy || !_email.text.contains('@')
                      ? null
                      : () async {
                          try {
                            await b.auth.sendPasswordReset(_email.text);
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.resetSent)));
                          } catch (e) {
                            if (mounted) setState(() => _error = e.toString());
                          }
                        },
                  child: Text(l.forgotPassword),
                ),
              ],
            ],
            if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('${l.error}: $_error', style: TextStyle(color: scheme.error)),
              ),
            const SizedBox(height: 8),
            TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: Text(l.cancel)),
          ],
        ),
      ),
    );
  }
}
