import 'package:flutter_test/flutter_test.dart';
import 'package:imdone/models/task.dart';
import 'package:imdone/models/task_logic.dart';

Task make({
  Frequency f = Frequency.daily,
  Set<int> wd = const {},
  int n = 2,
  DateTime? start,
  DateTime? end,
  TaskKind kind = TaskKind.personal,
  Map<String, Completion> completions = const {},
  int nagEvery = 10,
  int nagRepeats = 3,
}) =>
    Task(
      id: 't1',
      title: 'x',
      kind: kind,
      ownerUid: 'me',
      ownerName: 'Me',
      frequency: f,
      weekdays: wd,
      everyNDays: n,
      hour: 9,
      minute: 0,
      createdAt: DateTime(2026, 9, 1),
      periodStart: start,
      periodEnd: end,
      completions: completions,
      nagEveryMinutes: nagEvery,
      nagRepeats: nagRepeats,
    );

void main() {
  test('daily inside a period', () {
    final t = make(start: DateTime(2026, 9, 10), end: DateTime(2026, 9, 12));
    expect(isDueOn(t, DateTime(2026, 9, 9)), false);
    expect(isDueOn(t, DateTime(2026, 9, 10)), true);
    expect(isDueOn(t, DateTime(2026, 9, 12)), true);
    expect(isDueOn(t, DateTime(2026, 9, 13)), false);
  });

  test('weekly on chosen days', () {
    final t = make(f: Frequency.weekly, wd: {1, 4});
    expect(isDueOn(t, DateTime(2026, 9, 14)), true); // Monday
    expect(isDueOn(t, DateTime(2026, 9, 15)), false);
    expect(isDueOn(t, DateTime(2026, 9, 17)), true); // Thursday
  });

  test('every 3 days from the start', () {
    final t = make(f: Frequency.everyNDays, n: 3, start: DateTime(2026, 9, 10));
    expect(isDueOn(t, DateTime(2026, 9, 10)), true);
    expect(isDueOn(t, DateTime(2026, 9, 11)), false);
    expect(isDueOn(t, DateTime(2026, 9, 13)), true);
  });

  test('once is due only on its date', () {
    final t = make(f: Frequency.once, start: DateTime(2026, 9, 20));
    expect(isDueOn(t, DateTime(2026, 9, 19)), false);
    expect(isDueOn(t, DateTime(2026, 9, 20)), true);
    expect(isDueOn(t, DateTime(2026, 9, 21)), false);
  });

  test('a shared claim is not done until the creator confirms', () {
    final claim = Completion(byUid: 'u2', byName: 'Sara', at: DateTime(2026, 9, 12, 9, 5));
    final t = make(kind: TaskKind.shared, completions: {'2026-09-12': claim});
    expect(isDoneOn(t, DateTime(2026, 9, 12)), false);
    expect(isAwaitingConfirmationOn(t, DateTime(2026, 9, 12)), true);
    final confirmed = t.copyWith(completions: {
      '2026-09-12': claim.copyWith(confirmedByUid: 'u1', confirmedAt: DateTime(2026, 9, 12, 10)),
    });
    expect(isDoneOn(confirmed, DateTime(2026, 9, 12)), true);
  });

  test('upcoming occurrences skip done days and keep a still-nagging past due', () {
    final done = Completion(byUid: 'me', byName: 'Me', at: DateTime(2026, 9, 12, 9, 1));
    final t = make(completions: {'2026-09-12': done});
    final from = DateTime(2026, 9, 12, 9, 15);
    final occ = upcomingOccurrences(t, from, maxCount: 2);
    expect(occ, [DateTime(2026, 9, 13, 9), DateTime(2026, 9, 14, 9)]);

    final t2 = make(); // not done; due 09:00, nag 3×10 min → window ends 09:30
    expect(upcomingOccurrences(t2, from, maxCount: 1), [DateTime(2026, 9, 12, 9)]);
    expect(upcomingOccurrences(t2, DateTime(2026, 9, 12, 9, 31), maxCount: 1), [DateTime(2026, 9, 13, 9)]);
  });

  test('reminder moments drop the past and include every nag', () {
    final t = make(nagEvery: 15, nagRepeats: 2);
    final due = DateTime(2026, 9, 12, 9);
    expect(reminderMoments(t, due, DateTime(2026, 9, 12, 8)),
        [due, DateTime(2026, 9, 12, 9, 15), DateTime(2026, 9, 12, 9, 30)]);
    expect(reminderMoments(t, due, DateTime(2026, 9, 12, 9, 16)), [DateTime(2026, 9, 12, 9, 30)]);
  });

  test('notification ids are stable, positive and distinct per index', () {
    final a = notificationId('abc', 0, 0);
    final b = notificationId('abc', 0, 1);
    final c = notificationId('abc', 1, 0);
    expect(a, notificationId('abc', 0, 0));
    expect(a, isNot(b));
    expect(a, isNot(c));
    expect(a, greaterThan(0));
    expect(a, lessThan(0x7fffffff));
  });

  test('a group is shared with everyone on my shared tasks in it, never me', () {
    Task mk(String id, {String? group, bool shared = true, String owner = 'me', List<String> members = const []}) => Task(
          id: id, title: id, kind: shared ? TaskKind.shared : TaskKind.personal, ownerUid: owner, ownerName: owner,
          frequency: Frequency.daily, hour: 9, minute: 0, createdAt: DateTime(2026), group: group,
          members: [for (final m in [owner, ...members]) TaskMember(uid: m, name: m.toUpperCase(), joinedAt: DateTime(2026))],
        );
    final tasks = [
      mk('a', group: 'Home', members: ['bob', 'sara']),
      mk('b', group: 'Home', members: ['sara', 'tom']),
      mk('c', group: 'Work', members: ['zed']),
      mk('d', group: 'Home', owner: 'bob', members: ['me', 'eve']), // not mine: eve does not follow
      mk('e', group: 'Home', shared: false),
    ];
    final people = groupPeople(tasks, 'Home', 'me').map((m) => m.uid).toList();
    expect(people, unorderedEquals(['bob', 'sara', 'tom']));
    expect(groupPeople(tasks, 'Work', 'me').map((m) => m.uid), ['zed']);
    expect(groupPeople(tasks, 'Nope', 'me'), isEmpty);
  });

  test('json round trip', () {
    final t = make(f: Frequency.weekly, wd: {2, 5}, start: DateTime(2026, 9, 10), kind: TaskKind.shared,
        completions: {'2026-09-12': Completion(byUid: 'u2', byName: 'S', at: DateTime(2026, 9, 12, 9))});
    final back = Task.decode(t.encode());
    expect(back.weekdays, {2, 5});
    expect(back.periodStart, DateTime(2026, 9, 10));
    expect(back.kind, TaskKind.shared);
    expect(back.completions['2026-09-12']!.byName, 'S');
  });
}
