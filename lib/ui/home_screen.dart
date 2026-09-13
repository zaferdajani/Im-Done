import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../models/task.dart';
import '../models/task_logic.dart';
import '../services/voice/understanding_service.dart';
import '../state/providers.dart';
import 'format.dart';
import 'settings_screen.dart';
import 'task_detail_screen.dart';
import 'task_editor_sheet.dart';
import 'task_tile.dart';
import 'widgets/hold_to_talk_button.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref, {String? spoken, Understanding? understood}) async {
    final actions = ref.read(taskActionsProvider);
    var draft = actions.newDraft();
    if (understood != null) {
      draft = applyUnderstanding(draft, understood);
    } else if (spoken != null) {
      draft = draftFromSpeech(draft, spoken);
    }
    final saved = await showTaskEditor(context, draft: draft, isNew: true);
    if (saved != null && saved.isShared && context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: saved.id, openInvite: true)));
    }
  }

  void _open(BuildContext context, Task t) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: t.id)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final lang = ref.watch(languageCodeProvider);
    final scheme = Theme.of(context).colorScheme;
    final tasks = ref.watch(allTasksProvider);
    final pending = ref.watch(pendingConfirmationsProvider);
    final notifOn = ref.watch(notificationsEnabledProvider).value ?? true;
    final today = DateTime.now();

    final dueToday = tasks.where((t) => isDueOn(t, today)).toList()
      ..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    final open = dueToday.where((t) => !isDoneOn(t, today)).toList();
    final doneList = dueToday.where((t) => isDoneOn(t, today)).toList();

    // Next 7 days, excluding today.
    final upcoming = <(Task, DateTime)>[];
    for (final t in tasks) {
      for (var i = 1; i <= 7; i++) {
        final d = dateOnly(today).add(Duration(days: i));
        if (isDueOn(t, d)) {
          upcoming.add((t, d));
          break;
        }
      }
    }
    upcoming.sort((a, b) => dueAtOn(a.$1, a.$2).compareTo(dueAtOn(b.$1, b.$2)));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.today),
            Text(formatDate(lang, today), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: tasks.isEmpty
                ? _Empty(l: l)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: [
                      if (!notifOn)
                        Card(
                          color: scheme.errorContainer,
                          child: ListTile(
                            leading: Icon(Icons.notifications_off_rounded, color: scheme.onErrorContainer),
                            title: Text(l.notificationsOff, style: TextStyle(color: scheme.onErrorContainer)),
                            trailing: TextButton(
                              onPressed: () async {
                                await ref.read(bootstrapProvider).scheduler.requestPermission();
                                ref.invalidate(notificationsEnabledProvider);
                              },
                              child: Text(l.enable),
                            ),
                          ),
                        ),
                      if (pending.isNotEmpty) ...[
                        _Header(l.pendingConfirmations, color: scheme.tertiary),
                        for (final t in pending) _gap(TaskTile(task: t, day: today, onOpen: () => _open(context, t))),
                      ],
                      if (open.isEmpty && doneList.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text(l.nothingToday, style: TextStyle(color: scheme.onSurfaceVariant))),
                        ),
                      for (final t in open.where((t) => !pending.contains(t)))
                        _gap(TaskTile(task: t, day: today, onOpen: () => _open(context, t))),
                      if (doneList.isNotEmpty) ...[
                        _Header(l.doneToday),
                        for (final t in doneList) _gap(Opacity(opacity: 0.7, child: TaskTile(task: t, day: today, onOpen: () => _open(context, t)))),
                      ],
                      if (upcoming.isNotEmpty) ...[
                        _Header(l.later),
                        for (final (t, d) in upcoming)
                          _gap(ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            leading: Icon(t.isShared ? Icons.group_rounded : Icons.circle_outlined, color: scheme.outline, size: 20),
                            title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${formatDate(lang, d)} · ${formatTime(context, t.hour, t.minute)}'),
                            onTap: () => _open(context, t),
                          )),
                      ],
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 6),
              child: HoldToTalkButton(
                onTranscript: (text) => _create(context, ref, spoken: text),
                onUnderstood: (u) => _create(context, ref, understood: u),
                onTypeInstead: () => _create(context, ref),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gap(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 10), child: w);
}

class _Header extends StatelessWidget {
  const _Header(this.text, {this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: color ?? Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.l});
  final L10n l;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.record_voice_over_rounded, size: 64, color: scheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 18),
            Text(l.emptyTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(l.emptyBody, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45)),
          ],
        ),
      ),
    );
  }
}
