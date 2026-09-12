/// Pure scheduling logic for tasks: which day is due, when the next reminder
/// fires, and whether an occurrence counts as done. No Flutter imports so it
/// can be unit-tested on a plain Dart VM.
library;

import 'task.dart';

/// yyyy-MM-dd key of a calendar day (local time).
String occurrenceKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whether [day] (date only) is a day on which [task] is due.
bool isDueOn(Task task, DateTime day) {
  final d = dateOnly(day);
  if (task.archived) return false;
  final start = task.periodStart == null ? null : dateOnly(task.periodStart!);
  final end = task.periodEnd == null ? null : dateOnly(task.periodEnd!);
  if (start != null && d.isBefore(start)) return false;
  if (end != null && d.isAfter(end)) return false;
  switch (task.frequency) {
    case Frequency.once:
      final target = start ?? dateOnly(task.createdAt);
      return d == target;
    case Frequency.daily:
      return true;
    case Frequency.weekdays:
      return d.weekday >= DateTime.monday && d.weekday <= DateTime.friday;
    case Frequency.weekly:
      if (task.weekdays.isEmpty) {
        return d.weekday == (start ?? dateOnly(task.createdAt)).weekday;
      }
      return task.weekdays.contains(d.weekday);
    case Frequency.everyNDays:
      final anchor = start ?? dateOnly(task.createdAt);
      final n = task.everyNDays < 1 ? 1 : task.everyNDays;
      final diff = d.difference(anchor).inDays;
      return diff >= 0 && diff % n == 0;
  }
}

/// The due moment on a given day.
DateTime dueAtOn(Task task, DateTime day) =>
    DateTime(day.year, day.month, day.day, task.hour, task.minute);

/// The completion for a given day, if any.
Completion? completionOn(Task task, DateTime day) =>
    task.completions[occurrenceKey(day)];

/// Done = there is a completion and (for shared tasks) it was confirmed.
bool isDoneOn(Task task, DateTime day) {
  final c = completionOn(task, day);
  if (c == null) return false;
  return task.isShared ? c.confirmed : true;
}

/// A member claimed completion and the creator has not yet confirmed.
bool isAwaitingConfirmationOn(Task task, DateTime day) {
  final c = completionOn(task, day);
  return c != null && task.isShared && !c.confirmed;
}

/// Occurrences (due moments) of [task] from [from] onwards, at most
/// [maxCount], searching up to [horizonDays] days ahead. Occurrences that are
/// already done, or already claimed and awaiting confirmation, are skipped —
/// nobody should be nagged about work that has been reported.
List<DateTime> upcomingOccurrences(
  Task task,
  DateTime from, {
  int maxCount = 3,
  int horizonDays = 60,
}) {
  final out = <DateTime>[];
  var day = dateOnly(from);
  for (var i = 0; i <= horizonDays && out.length < maxCount; i++) {
    if (isDueOn(task, day) &&
        !isDoneOn(task, day) &&
        !isAwaitingConfirmationOn(task, day)) {
      final due = dueAtOn(task, day);
      // A due moment in the past still counts for TODAY (the nag keeps going),
      // but only if the whole nag window has not already elapsed.
      final lastNag = due.add(Duration(minutes: task.nagEveryMinutes * task.nagRepeats));
      if (!lastNag.isBefore(from)) out.add(due);
    }
    day = day.add(const Duration(days: 1));
  }
  return out;
}

/// The reminder moments for ONE occurrence: the due time, then every
/// [Task.nagEveryMinutes] for [Task.nagRepeats] repeats. Moments already in
/// the past (relative to [now]) are dropped.
List<DateTime> reminderMoments(Task task, DateTime due, DateTime now) {
  final out = <DateTime>[];
  if (!due.isBefore(now)) out.add(due);
  if (task.nagEveryMinutes > 0) {
    for (var i = 1; i <= task.nagRepeats; i++) {
      final t = due.add(Duration(minutes: task.nagEveryMinutes * i));
      if (!t.isBefore(now)) out.add(t);
    }
  }
  return out;
}

/// Stable, small, non-negative integer derived from a task id — used to build
/// notification ids that survive app restarts. FNV-1a, folded to 20 bits so
/// that `hash * 64 + i` stays well inside a signed 32-bit int.
int stableHash(String id) {
  var h = 0x811c9dc5;
  for (final c in id.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h & 0xfffff;
}

/// Notification id for the [index]-th reminder of an occurrence.
/// [dayOrdinal] separates occurrences so two days of one task never collide.
int notificationId(String taskId, int dayOrdinal, int index) =>
    ((stableHash(taskId) * 8 + (dayOrdinal % 8)) * 64 + (index % 64)) &
    0x7fffffff;
