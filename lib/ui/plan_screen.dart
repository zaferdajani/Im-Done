import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/strings.dart';
import '../models/plan.dart';
import '../models/task.dart' show TaskMember;
import '../state/providers.dart';
import 'format.dart';
import 'scan_code_screen.dart';
import 'sign_in_sheet.dart';

/// Plan & people: the family or team environment whose members get the
/// plan's access, and the plan itself. Purchases arrive with the store
/// listings; until then a 30-day trial exists and nothing is gated.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<bool> _ready() async {
    final l = ref.read(l10nProvider);
    if (!ref.read(bootstrapProvider).cloudAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.cloudUnavailable)));
      return false;
    }
    if (needsSignIn(ref.read(authUserProvider).value)) {
      final user = await showSignInSheet(context);
      if (user == null || !mounted) return false;
    }
    return true;
  }

  Future<void> _run(Future<void> Function() body) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await body();
    } catch (e) {
      if (mounted) {
        final l = ref.read(l10nProvider);
        final msg = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg.contains('no such code') ? l.codeNotFound : msg.contains('trial already used') ? l.trialUsed : '${l.error}: $e'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create(WorkspaceKind kind) async {
    final l = ref.read(l10nProvider);
    if (!await _ready() || !mounted) return;
    final ctl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(kind == WorkspaceKind.family ? l.createFamily : l.createTeam),
        content: TextField(controller: ctl, autofocus: true, textCapitalization: TextCapitalization.words, decoration: InputDecoration(hintText: l.workspaceNameHint), onSubmitted: (v) => Navigator.pop(ctx, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: Text(l.save)),
        ],
      ),
    );
    ctl.dispose();
    if (name == null || name.trim().isEmpty) return;
    await _run(() => ref.read(planActionsProvider).create(name, kind));
  }

  Future<bool> _confirm(String question, String action) async {
    final l = ref.read(l10nProvider);
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(question),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
            ],
          ),
        ) ==
        true;
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final lang = ref.watch(languageCodeProvider);
    final scheme = Theme.of(context).colorScheme;
    final uid = ref.watch(myUidProvider);
    final ws = ref.watch(workspaceProvider).value;
    final ent = ref.watch(entitlementProvider).value;
    final level = ref.watch(planLevelProvider);
    final enforced = ref.watch(billingEnforcedProvider).value ?? false;
    final actions = ref.read(planActionsProvider);
    final isOwner = ws != null && ws.ownerUid == uid;
    final seats = ent != null && ent.active ? ent.seats : (enforced ? 1 : 50);

    final levelName = switch (level) {
      PlanLevel.free => l.planFree,
      PlanLevel.trial => l.planTrial,
      PlanLevel.family => l.planFamily,
      PlanLevel.team => l.planTeam,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l.planSection)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          // ------------------------------------------------ current plan
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(levelName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer)),
                  if (ent != null && ent.active)
                    Text(l.planUntil.fill({'date': formatDateShort(lang, ent.validUntil)}), style: TextStyle(color: scheme.onPrimaryContainer)),
                  if (!enforced) ...[
                    const SizedBox(height: 8),
                    Text(l.whileFree, style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 13, height: 1.4)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ------------------------------------------------ the environment
          if (ws == null) ...[
            Text(l.planFamilyBody, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4)),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: _busy ? null : () => _create(WorkspaceKind.family), icon: const Icon(Icons.family_restroom_rounded), label: Text(l.createFamily)),
            const SizedBox(height: 18),
            Text(l.planTeamBody, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4)),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(onPressed: _busy ? null : () => _create(WorkspaceKind.team), icon: const Icon(Icons.groups_rounded), label: Text(l.createTeam)),
          ] else ...[
            Row(children: [
              Icon(ws.kind == WorkspaceKind.family ? Icons.family_restroom_rounded : Icons.groups_rounded, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(ws.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
              if (isOwner)
                IconButton(
                  tooltip: l.renameWorkspace,
                  onPressed: _busy
                      ? null
                      : () async {
                          final ctl = TextEditingController(text: ws.name);
                          final name = await showDialog<String>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(l.renameWorkspace),
                              content: TextField(controller: ctl, autofocus: true, onSubmitted: (v) => Navigator.pop(ctx, v)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
                                FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: Text(l.save)),
                              ],
                            ),
                          );
                          ctl.dispose();
                          if (name != null && name.trim().isNotEmpty) await _run(() => actions.rename(ws, name));
                        },
                  icon: const Icon(Icons.edit_outlined),
                ),
            ]),
            const SizedBox(height: 4),
            Text(l.seatsUsed.fill({'used': ws.members.length, 'seats': seats}), style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Text(l.workspacePeople, style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final TaskMember m in ws.members)
                  InputChip(
                    avatar: Icon(m.uid == ws.ownerUid ? Icons.star_rounded : Icons.person_rounded, size: 18),
                    label: Text(m.name.isEmpty ? l.you : m.name),
                    onDeleted: isOwner && m.uid != ws.ownerUid && !_busy
                        ? () async {
                            if (await _confirm(l.workspaceRemove.fill({'name': m.name}), l.delete)) await _run(() => actions.remove(ws, m.uid));
                          }
                        : null,
                  ),
              ],
            ),
            if (isOwner) ...[
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(hintText: l.addByCodeHint, prefixIcon: const Icon(Icons.tag_rounded)),
                    onSubmitted: (v) => _run(() async {
                      await actions.addByCode(ws, v);
                      _code.clear();
                    }),
                  ),
                ),
                IconButton(
                  tooltip: l.scanCode,
                  onPressed: _busy
                      ? null
                      : () async {
                          final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const ScanCodeScreen()));
                          if (code != null) await _run(() => actions.addByCode(ws, code));
                        },
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                ),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                            await actions.addByCode(ws, _code.text);
                            _code.clear();
                          }),
                  child: Text(l.addByCode),
                ),
              ]),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          final link = await actions.inviteLink(ws);
                          if (!mounted) return;
                          final box = this.context.findRenderObject() as RenderBox?;
                          await SharePlus.instance.share(ShareParams(
                            text: '${l.groupInviteMessage.fill({'group': ws.name})} $link',
                            subject: l.appName,
                            sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
                          ));
                        }),
                icon: const Icon(Icons.link_rounded),
                label: Text(l.shareInviteLink),
              ),
              if (ent == null || !ent.active) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                            await actions.startTrial(ws);
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(l.trialStarted)));
                          }),
                  icon: const Icon(Icons.card_giftcard_rounded),
                  label: Text(l.startTrial),
                ),
              ],
            ] else ...[
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        if (await _confirm(l.leaveWorkspaceConfirm.fill({'name': ws.name}), l.leaveWorkspace)) await _run(() => actions.leave(ws));
                      },
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                icon: const Icon(Icons.logout_rounded),
                label: Text(l.leaveWorkspace),
              ),
            ],
          ],
          const SizedBox(height: 24),
          // ------------------------------------------------ the plans
          _PlanCard(title: l.planFree, body: l.planFreeBody, icon: Icons.person_outline_rounded, current: level == PlanLevel.free),
          _PlanCard(title: l.planFamily, body: l.planFamilyBody, icon: Icons.family_restroom_rounded, current: level == PlanLevel.family || level == PlanLevel.trial),
          _PlanCard(title: l.planTeam, body: l.planTeamBody, icon: Icons.groups_rounded, current: level == PlanLevel.team),
          const SizedBox(height: 8),
          Text(l.purchasesSoon, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.title, required this.body, required this.icon, required this.current});
  final String title;
  final String body;
  final IconData icon;
  final bool current;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: current ? BorderSide(color: scheme.primary, width: 2) : BorderSide.none),
      child: ListTile(
        leading: Icon(icon, color: scheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(body),
        trailing: current ? Icon(Icons.check_circle_rounded, color: scheme.primary) : null,
      ),
    );
  }
}
