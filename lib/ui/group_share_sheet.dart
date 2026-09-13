import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/strings.dart';
import '../models/task.dart';
import '../state/providers.dart';
import 'scan_code_screen.dart';
import 'sign_in_sheet.dart';

/// Share every task of a group with someone: by their personal code (typed
/// or scanned) or with one invite link that joins the whole group. Tasks
/// the person creates in the group later follow automatically.
Future<void> showGroupShareSheet(BuildContext context, String group) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => GroupShareSheet(group: group),
    );

class GroupShareSheet extends ConsumerStatefulWidget {
  const GroupShareSheet({super.key, required this.group});
  final String group;

  @override
  ConsumerState<GroupShareSheet> createState() => _GroupShareSheetState();
}

class _GroupShareSheetState extends ConsumerState<GroupShareSheet> {
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

  Future<void> _addByCode(String raw) async {
    final l = ref.read(l10nProvider);
    final clean = raw.replaceAll('-', '').trim().toUpperCase();
    if (clean.length != 8 || _busy) return;
    if (!await _ready()) return;
    setState(() => _busy = true);
    try {
      final person = await ref.read(bootstrapProvider).cloudTasks.lookupPersonalCode(clean);
      final n = await ref.read(taskActionsProvider).shareGroupByCode(widget.group, clean);
      if (!mounted) return;
      _code.clear();
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(n == 0 ? l.groupOnlyOwn : l.groupShareDone.fill({'name': person?.name ?? clean})),
      ));
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('no such code') ? l.codeNotFound : '${l.error}: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String question, String action) async {
    final l = ref.read(l10nProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(question),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _remove(TaskMember p) async {
    final l = ref.read(l10nProvider);
    if (_busy || !await _confirm(l.removeFromGroup.fill({'name': p.name}), l.delete)) return;
    setState(() => _busy = true);
    try {
      await ref.read(taskActionsProvider).removeFromGroup(widget.group, p.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.removedFromGroup.fill({'name': p.name}))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.error}: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    final l = ref.read(l10nProvider);
    if (_busy || !await _confirm(l.leaveGroupConfirm.fill({'group': widget.group}), l.leaveGroup)) return;
    setState(() => _busy = true);
    try {
      await ref.read(taskActionsProvider).leaveGroup(widget.group);
      if (!mounted) return;
      ref.read(groupFilterProvider.notifier).set(null);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.leftGroup)));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.error}: $e')));
      }
    }
  }

  Future<void> _shareLink() async {
    final l = ref.read(l10nProvider);
    if (_busy || !await _ready()) return;
    setState(() => _busy = true);
    try {
      final link = await ref.read(taskActionsProvider).groupInviteLink(widget.group);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(ShareParams(
        text: '${l.groupInviteMessage.fill({'group': widget.group})} $link',
        subject: l.appName,
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().contains('nothing to share') ? l.groupOnlyOwn : '${l.error}: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    ref.watch(allTasksProvider);
    final people = ref.read(taskActionsProvider).peopleOfGroup(widget.group);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 4, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.folder_shared_outlined, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text('${l.shareGroup} · ${widget.group}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 16),
          Text(l.groupPeople, style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (people.isEmpty)
            Text(l.groupNobodyYet, style: TextStyle(color: scheme.onSurfaceVariant))
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final p in people)
                  InputChip(
                    avatar: const Icon(Icons.person_rounded, size: 18),
                    label: Text(p.name),
                    onDeleted: _busy ? null : () => _remove(p),
                    deleteButtonTooltipMessage: l.delete,
                  ),
              ],
            ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(hintText: l.addByCodeHint, prefixIcon: const Icon(Icons.tag_rounded)),
                onSubmitted: _addByCode,
              ),
            ),
            IconButton(
              tooltip: l.scanCode,
              onPressed: _busy
                  ? null
                  : () async {
                      final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const ScanCodeScreen()));
                      if (code != null) await _addByCode(code);
                    },
              icon: const Icon(Icons.qr_code_scanner_rounded),
            ),
            FilledButton(onPressed: _busy ? null : () => _addByCode(_code.text), child: Text(l.addByCode)),
          ]),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _shareLink,
            icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.link_rounded),
            label: Text(l.shareInviteLink),
          ),
          const SizedBox(height: 6),
          Text(l.groupSharedHint.fill({'n': people.length}), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, height: 1.4)),
          if (ref.read(taskActionsProvider).othersTasksInGroup(widget.group) > 0) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _busy ? null : _leave,
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              icon: const Icon(Icons.logout_rounded),
              label: Text(l.leaveGroup),
            ),
          ],
        ],
      ),
    );
  }
}
