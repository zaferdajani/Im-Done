import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/languages.dart';
import '../models/task.dart';
import '../models/task_logic.dart';
import '../state/providers.dart';
import 'format.dart';

class TaskTile extends ConsumerWidget {
  const TaskTile({super.key, required this.task, required this.day, required this.onOpen});
  final Task task;
  final DateTime day;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final lang = ref.watch(languageCodeProvider);
    final scheme = Theme.of(context).colorScheme;
    final done = isDoneOn(task, day);
    final awaiting = isAwaitingConfirmationOn(task, day);
    final actions = ref.read(taskActionsProvider);
    final due = dueAtOn(task, day);
    final overdue = !done && !awaiting && DateTime.now().isAfter(due) && dateOnly(day) == dateOnly(DateTime.now());

    Future<void> toggle() async {
      HapticFeedback.selectionClick();
      if (done || awaiting) {
        await actions.undo(task, day);
      } else {
        await actions.markDone(task, day);
      }
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          child: Row(
            children: [
              _CheckButton(done: done, awaiting: awaiting, onTap: toggle),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done ? scheme.onSurfaceVariant : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          formatTime(context, task.hour, task.minute),
                          style: TextStyle(fontWeight: FontWeight.w600, color: overdue ? scheme.error : scheme.primary),
                        ),
                        Text(frequencySummary(l, lang, task), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                        if (task.importance != Importance.medium)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(importanceIcon(task.importance), size: 14, color: importanceColor(scheme, task.importance)),
                              const SizedBox(width: 2),
                              Text(importanceName(l, task.importance), style: TextStyle(color: importanceColor(scheme, task.importance), fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        if (languageLabel(task.language, task.dialect, lang) case final spoken?)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.translate_rounded, size: 14, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 3),
                              Text(spoken, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                            ],
                          ),
                        if (task.isShared)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.group_rounded, size: 15, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 3),
                              Text('${task.members.length}', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                            ],
                          ),
                      ],
                    ),
                    if (awaiting)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${l.claimedBy} ${completionOn(task, day)?.byName ?? ''} · ${l.awaitingConfirmation}',
                          style: TextStyle(color: ImDoneTheme.accent, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.done, required this.awaiting, required this.onTap});
  final bool done;
  final bool awaiting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = done ? scheme.primary : (awaiting ? ImDoneTheme.accent : scheme.outline);
    return InkResponse(
      onTap: onTap,
      radius: 26,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? scheme.primary : Colors.transparent,
          border: Border.all(color: color, width: 2.2),
        ),
        child: Icon(
          done ? Icons.check_rounded : (awaiting ? Icons.hourglass_top_rounded : null),
          color: done ? scheme.onPrimary : ImDoneTheme.accent,
          size: 22,
        ),
      ),
    );
  }
}
