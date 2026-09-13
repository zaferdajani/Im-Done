import '../core/platform.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/strings.dart';
import '../services/cloud/cloud.dart';
import '../services/settings_store.dart';
import '../state/providers.dart';
import 'sign_in_sheet.dart';
import 'widgets/my_code_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final b = ref.watch(bootstrapProvider);
    final user = ref.watch(authUserProvider).value;
    final notifOn = ref.watch(notificationsEnabledProvider).value ?? false;
    final exactOn = ref.watch(exactAlarmsProvider).value ?? true;

    Future<void> open(String url) async {
      final u = Uri.parse(url);
      if (!await launchUrl(u, mode: LaunchMode.externalApplication) && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.error)));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _Section(l.language),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'system', label: Text(l.languageSystem)),
              const ButtonSegment(value: 'en', label: Text('English')),
              const ButtonSegment(value: 'ar', label: Text('العربية')),
            ],
            selected: {settings.languageCode ?? 'system'},
            onSelectionChanged: (s) {
              final v = s.first;
              ref.read(settingsProvider.notifier).update(
                    v == 'system' ? settings.copyWith(clearLanguage: true) : settings.copyWith(languageCode: v),
                  );
            },
          ),
          _Section(l.voiceSection),
          Card(
            child: RadioGroup<VoiceEngine>(
              groupValue: settings.voiceEngine,
              onChanged: (v) => ref.read(settingsProvider.notifier).update(settings.copyWith(voiceEngine: v)),
              child: Column(
                children: [
                  RadioListTile<VoiceEngine>(
                    value: VoiceEngine.cloud,
                    title: Text(l.voiceCloudTitle),
                    subtitle: Text(l.voiceCloudBody),
                    isThreeLine: true,
                  ),
                  RadioListTile<VoiceEngine>(
                    value: VoiceEngine.device,
                    title: Text(l.voiceDeviceTitle),
                    subtitle: Text(l.voiceDeviceBody),
                    isThreeLine: true,
                  ),
                ],
              ),
            ),
          ),
          _Section(l.notifications),
          Card(
            child: Column(children: [
              ListTile(
                leading: Icon(notifOn ? Icons.notifications_active_rounded : Icons.notifications_off_rounded, color: notifOn ? scheme.primary : scheme.error),
                title: Text(notifOn ? l.notifications : l.notificationsOff),
                subtitle: Text(isWeb ? l.webRemindersNote : l.notificationsHint),
                trailing: notifOn
                    ? null
                    : FilledButton.tonal(
                        onPressed: () async {
                          await b.scheduler.requestPermission();
                          ref.invalidate(notificationsEnabledProvider);
                        },
                        child: Text(l.enable),
                      ),
              ),
              if (isAndroid) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.alarm_on_rounded, color: exactOn ? scheme.primary : scheme.onSurfaceVariant),
                  title: Text(l.exactReminders),
                  subtitle: Text(l.exactRemindersHint),
                  trailing: exactOn
                      ? const Icon(Icons.check_rounded)
                      : FilledButton.tonal(
                          onPressed: () async {
                            await b.scheduler.requestExact();
                            ref.invalidate(exactAlarmsProvider);
                          },
                          child: Text(l.enable),
                        ),
                ),
              ],
            ]),
          ),
          if (user != null) ...[
            _Section(l.myCode),
            const MyCodeCard(),
          ],
          _Section(l.account),
          Card(
            child: Column(children: [
              if (!b.cloudAvailable)
                ListTile(leading: const Icon(Icons.cloud_off_rounded), title: Text(l.cloudUnavailable))
              else if (user == null)
                ListTile(
                  leading: const Icon(Icons.login_rounded),
                  title: Text(l.signInTitle),
                  onTap: () => showSignInSheet(context),
                )
              else ...[
                ListTile(
                  leading: CircleAvatar(child: Text((user.displayName ?? user.email ?? '?').characters.first.toUpperCase())),
                  title: Text(user.displayName ?? ''),
                  subtitle: Text(user.isAnonymous ? l.guestAccount : (user.email ?? '')),
                ),
                if (user.isAnonymous) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.mail_outline_rounded),
                    title: Text(l.linkEmail),
                    subtitle: Text(l.linkGoogleHint),
                    onTap: () async {
                      // The sheet links email to the quick account (see AuthService).
                      await showSignInSheet(context);
                      ref.invalidate(authUserProvider);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.g_mobiledata_rounded, size: 30),
                    title: Text(l.linkGoogle),
                    subtitle: Text(l.linkGoogleHint),
                    onTap: () async {
                      try {
                        await ref.read(taskActionsProvider).linkGoogle();
                        ref.invalidate(authUserProvider);
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.error}: $e')));
                      }
                    },
                  ),
                ],
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: Text(l.signOut),
                  onTap: () async {
                    await b.push.unregister(user.uid);
                    await b.auth.signOut();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.delete_forever_rounded, color: scheme.error),
                  title: Text(l.deleteAccount, style: TextStyle(color: scheme.error)),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l.deleteAccount),
                        content: Text(l.deleteAccountConfirm),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: scheme.error),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(l.delete),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    try {
                      try {
                        await ref.read(taskActionsProvider).deleteAccount();
                      } on FirebaseAuthException catch (e) {
                        // Firebase wants a fresh sign-in before deleting an account.
                        if (e.code != 'requires-recent-login' || !context.mounted) rethrow;
                        final again = await showSignInSheet(context);
                        if (again == null) return;
                        await ref.read(taskActionsProvider).deleteAccount();
                      }
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.deleteAccountDone)));
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.error}: $e')));
                    }
                  },
                ),
              ],
            ]),
          ),
          const SizedBox(height: 20),
          Card(
            child: Column(children: [
              ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: Text(l.privacyPolicy), onTap: () => open(Cloud.privacyPolicyUrl)),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.description_outlined), title: Text(l.terms), onTap: () => open(Cloud.termsUrl)),
            ]),
          ),
          const SizedBox(height: 20),
          Center(child: Text('${l.appName} · ${l.version} 0.1.0', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12))),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
        child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}
