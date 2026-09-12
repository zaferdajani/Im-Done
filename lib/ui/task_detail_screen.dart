import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/task.dart';
import '../models/task_logic.dart';
import '../services/cloud/cloud.dart';
import '../state/providers.dart';
import 'format.dart';
import 'task_editor_sheet.dart';

class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId, this.openInvite = false});
  final String taskId;
  final bool openInvite;

  static String inviteLink(Task t) => '${Cloud.inviteBaseUrl}/${t.inviteCode}';

  static Future<void> share(BuildContext context, Task t) async {
    final l = L10n.of(context);
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      text: '${l.inviteMessage.fill({'title': t.title})} ${inviteLink(t)}',
      subject: l.appName,
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final lang = ref.watch(languageCodeProvider);
    final scheme = Theme.of(context).colorScheme;
    final task = ref.watch(allTasksProvider).where((t) => t.id == taskId).firstOrNull;
    if (task == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    final uid = ref.watch(myUidProvider);
    final actions = ref.read(taskActionsProvider);
    final today = DateTime.now();
    final dueToday = isDueOn(task, today);
    final done = isDoneOn(task, today);
    final awaiting = isAwaitingConfirmationOn(task, today);
    final completion = completionOn(task, today);
    final isCreator = task.ownerUid == uid;

    if (openInvite) {
      WidgetsBinding.instance.addPostFrameCallback((_) => share(context, task));
    }

    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showTaskEditor(context, draft: task, isNew: false),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l.deleteTaskConfirm),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.delete)),
                    ],
                  ),
                );
                if (ok == true) {
                  await actions.delete(task);
                  if (context.mounted) Navigator.of(context).pop();
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'delete', child: Text(l.delete, style: TextStyle(color: scheme.error))),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          Text(task.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.15)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Pill(icon: Icons.schedule_rounded, text: formatTime(context, task.hour, task.minute)),
              _Pill(icon: Icons.repeat_rounded, text: frequencySummary(l, lang, task)),
              if (task.periodStart != null && task.frequency != Frequency.once)
                _Pill(icon: Icons.today_rounded, text: l.fromDate.fill({'date': formatDateShort(lang, task.periodStart!)})),
              _Pill(
                icon: Icons.notifications_active_rounded,
                text: task.nagEveryMinutes == 0 ? l.nagOff : '${l.nagEvery} ${task.nagEveryMinutes} min × ${task.nagRepeats}',
              ),
              _Pill(icon: task.isShared ? Icons.group_rounded : Icons.person_rounded, text: task.isShared ? l.kindShared : l.kindPersonal),
            ],
          ),
          if (task.note?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 14),
            Text(task.note!.trim(), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15, height: 1.4)),
          ],
          const SizedBox(height: 24),
          // ------------------------------------------------ today's status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.today, style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  if (!dueToday)
                    Text(l.nothingToday, style: const TextStyle(fontSize: 16))
                  else if (done) ...[
                    Row(children: [
                      Icon(Icons.check_circle_rounded, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l.done, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                    ]),
                    if (task.isShared && completion != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('${l.claimedBy} ${completion.byName} · ${l.confirmedBy} ${_nameOf(task, completion.confirmedByUid, l)}',
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                      ),
                    const SizedBox(height: 10),
                    OutlinedButton(onPressed: () => actions.undo(task, today), child: Text(l.undo)),
                  ] else if (awaiting) ...[
                    Row(children: [
                      const Icon(Icons.hourglass_top_rounded, color: DonebyTheme.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isCreator ? l.needsYourConfirmation : '${l.claimedBy} ${completion?.byName ?? ''} · ${l.awaitingConfirmation}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    if (isCreator)
                      Row(children: [
                        Expanded(child: OutlinedButton(onPressed: () => actions.reject(task, today), child: Text(l.notDone))),
                        const SizedBox(width: 10),
                        Expanded(child: FilledButton(onPressed: () => actions.confirm(task, today), child: Text(l.confirmDone))),
                      ])
                    else if (completion?.byUid == uid)
                      OutlinedButton(onPressed: () => actions.undo(task, today), child: Text(l.undo)),
                  ] else
                    FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        actions.markDone(task, today);
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: Text(l.markDone),
                    ),
                ],
              ),
            ),
          ),
          // ------------------------------------------------ people
          if (task.isShared) ...[
            const SizedBox(height: 22),
            Text(l.members, style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final m in task.members)
                    ListTile(
                      leading: CircleAvatar(child: Text(m.name.isEmpty ? '?' : m.name.characters.first.toUpperCase())),
                      title: Text(m.uid == uid ? '${m.name} (${l.you})' : m.name),
                      subtitle: m.uid == task.ownerUid ? Text(l.creator) : null,
                    ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_1_rounded),
                    title: Text(l.invite),
                    subtitle: Text(l.inviteHint, style: const TextStyle(fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy_rounded),
                      tooltip: l.copyLink,
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: inviteLink(task)));
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.linkCopied)));
                      },
                    ),
                    onTap: () => share(context, task),
                  ),
                ],
              ),
            ),
          ],
          // ------------------------------------------------ history
          if (task.completions.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text(l.doneToday.replaceAll(l.today, '').trim().isEmpty ? l.done : l.done, style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final e in (task.completions.entries.toList()..sort((a, b) => b.key.compareTo(a.key))).take(14))
                    ListTile(
                      dense: true,
                      leading: Icon(e.value.confirmed ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                          color: e.value.confirmed ? scheme.primary : DonebyTheme.accent),
                      title: Text(e.key),
                      subtitle: task.isShared ? Text(e.value.byName) : null,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _nameOf(Task t, String? uid, L10n l) {
    if (uid == null) return '';
    if (uid == t.ownerUid) return t.ownerName.isEmpty ? l.creator : t.ownerName;
    return t.members.where((m) => m.uid == uid).firstOrNull?.name ?? '';
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: scheme.primary),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
