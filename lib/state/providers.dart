import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../l10n/strings.dart';
import '../l10n/supported.dart';
import '../models/task.dart';
import '../models/task_logic.dart';
import '../services/cloud/cloud.dart';
import '../services/settings_store.dart';
import 'bootstrap.dart';

/// Overridden in main() with the real bootstrap.
final bootstrapProvider = Provider<AppBootstrap>((_) => throw UnimplementedError('bootstrap'));

// ---------------------------------------------------------------- settings
class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(bootstrapProvider).settings;

  Future<void> update(AppSettings s) async {
    state = s;
    await ref.read(bootstrapProvider).settingsStore.write(s);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

/// The effective language code: explicit choice, else the device's.
final languageCodeProvider = Provider<String>((ref) {
  final chosen = ref.watch(settingsProvider).languageCode;
  if (chosen != null) return chosen;
  final device = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  return isSupportedLanguage(device) ? device : 'en';
});

final l10nProvider = Provider<L10n>((ref) => L10n.forCode(ref.watch(languageCodeProvider)));

// ---------------------------------------------------------------- identity
final authUserProvider = StreamProvider<User?>((ref) {
  final b = ref.watch(bootstrapProvider);
  if (!b.cloudAvailable) return Stream.value(null);
  return b.auth.changes;
});

/// Signed-in uid, or the local pseudo-owner when there is no account.
/// True when sharing must first ask who this is: nobody is signed in, or
/// only a nameless anonymous identity (created silently for voice) exists.
bool needsSignIn(User? user) => user == null || (user.isAnonymous && (user.displayName ?? '').trim().isEmpty);

final myUidProvider = Provider<String>((ref) => ref.watch(authUserProvider).value?.uid ?? localOwnerUid);

final myNameProvider = Provider<String>((ref) {
  final user = ref.watch(authUserProvider).value;
  final n = user?.displayName?.trim();
  if (n != null && n.isNotEmpty) return n;
  final s = ref.watch(settingsProvider).displayName.trim();
  if (s.isNotEmpty) return s;
  return ref.watch(l10nProvider).you;
});

// ---------------------------------------------------------------- tasks
class LocalTasksNotifier extends Notifier<List<Task>> {
  @override
  List<Task> build() => ref.read(bootstrapProvider).initialTasks;

  Future<void> reload() async {
    state = await ref.read(bootstrapProvider).localStore.readAll();
  }

  Future<void> upsert(Task t) async {
    final list = [...state];
    final i = list.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      list[i] = t;
    } else {
      list.add(t);
    }
    state = list;
    await ref.read(bootstrapProvider).localStore.writeAll(list);
  }

  Future<void> remove(String id) async {
    state = state.where((x) => x.id != id).toList();
    await ref.read(bootstrapProvider).localStore.writeAll(state);
  }
}

final localTasksProvider = NotifierProvider<LocalTasksNotifier, List<Task>>(LocalTasksNotifier.new);

final cloudTasksProvider = StreamProvider<List<Task>>((ref) {
  final b = ref.watch(bootstrapProvider);
  final user = ref.watch(authUserProvider).value;
  if (!b.cloudAvailable || user == null) return Stream.value(const <Task>[]);
  return b.cloudTasks.watchMine(user.uid);
});

/// Personal + shared, one list, what every screen reads.
final allTasksProvider = Provider<List<Task>>((ref) {
  final local = ref.watch(localTasksProvider);
  final cloud = ref.watch(cloudTasksProvider).value ?? const <Task>[];
  return [...local, ...cloud];
});

/// Shared tasks I created where somebody has claimed today and I have not
/// yet confirmed.
/// Every group name in use, most used first — feeds the editor's suggestions
/// and the home filter. A group exists only while a task carries its name.
final groupNamesProvider = Provider<List<String>>((ref) {
  final counts = <String, int>{};
  for (final t in ref.watch(allTasksProvider)) {
    final g = t.group;
    if (g != null) counts[g] = (counts[g] ?? 0) + 1;
  }
  final names = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  return names;
});

/// The home screen's group filter: null = all, '' = tasks with no group.
class GroupFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? g) => state = g;
}

final groupFilterProvider = NotifierProvider<GroupFilterNotifier, String?>(GroupFilterNotifier.new);

final pendingConfirmationsProvider = Provider<List<Task>>((ref) {
  final uid = ref.watch(myUidProvider);
  final today = DateTime.now();
  return ref
      .watch(allTasksProvider)
      .where((t) => t.isShared && t.ownerUid == uid && isAwaitingConfirmationOn(t, today))
      .toList();
});

// ---------------------------------------------------------------- actions
class TaskActions {
  TaskActions(this.ref);
  final Ref ref;

  AppBootstrap get _b => ref.read(bootstrapProvider);

  Task newDraft({String title = ''}) => Task(
        id: const Uuid().v4(),
        title: title,
        kind: TaskKind.personal,
        ownerUid: localOwnerUid,
        ownerName: ref.read(myNameProvider),
        frequency: Frequency.daily,
        hour: 9,
        minute: 0,
        createdAt: DateTime.now(),
      );

  /// People a group is shared with, from the caller's own tasks.
  List<TaskMember> peopleOfGroup(String group) => groupPeople(ref.read(allTasksProvider), group, ref.read(myUidProvider));

  Future<Task> save(Task t) async {
    // A task filed under a group that is shared with people is shared with
    // them too — that is what sharing a group means.
    final user = ref.read(authUserProvider).value;
    final inherit = t.group != null && user != null ? peopleOfGroup(t.group!) : const <TaskMember>[];
    if (!t.isShared && inherit.isNotEmpty) t = t.copyWith(kind: TaskKind.shared);
    if (t.isShared) {
      if (user == null) throw StateError('sign-in required');
      final me = TaskMember(uid: user.uid, name: ref.read(myNameProvider), joinedAt: DateTime.now());
      final existing = ref.read(allTasksProvider).where((x) => x.id == t.id).firstOrNull;
      if (existing == null || !existing.isShared) {
        // Brand-new shared task (or a personal one being turned shared).
        final shared = t.copyWith(ownerUid: user.uid, ownerName: me.name, members: [me]);
        if (existing != null) await ref.read(localTasksProvider.notifier).remove(t.id);
        final created = await _b.cloudTasks.create(shared);
        await _followGroup(created, inherit);
        return created;
      }
      await _b.cloudTasks.update(t);
      if (t.ownerUid == user.uid) await _followGroup(t, inherit);
      return t;
    }
    await ref.read(localTasksProvider.notifier).upsert(t.copyWith(ownerUid: localOwnerUid));
    return t;
  }

  Future<void> delete(Task t) async {
    if (t.isShared) {
      final uid = ref.read(myUidProvider);
      if (t.ownerUid == uid) {
        await _b.cloudTasks.archive(t);
      } else {
        await _b.cloudTasks.leave(t, uid);
      }
    } else {
      await ref.read(localTasksProvider.notifier).remove(t.id);
    }
    await _b.scheduler.cancelTask(t.id);
  }

  Future<void> markDone(Task t, DateTime day) async {
    final uid = ref.read(myUidProvider);
    final name = ref.read(myNameProvider);
    if (t.isShared) {
      await _b.cloudTasks.claimDone(t, day, uid, name);
      if (uid != t.ownerUid) _b.push.notify('claimed', t.id);
      return;
    }
    final now = DateTime.now();
    final c = Completion(byUid: uid, byName: name, at: now, confirmedByUid: uid, confirmedAt: now);
    final updated = t.copyWith(completions: {...t.completions, occurrenceKey(day): c});
    await ref.read(localTasksProvider.notifier).upsert(updated);
  }

  Future<void> undo(Task t, DateTime day) async {
    if (t.isShared) {
      await _b.cloudTasks.reject(t, day, callerUid: ref.read(myUidProvider));
      return;
    }
    final map = {...t.completions}..remove(occurrenceKey(day));
    await ref.read(localTasksProvider.notifier).upsert(t.copyWith(completions: map));
  }

  Future<void> confirm(Task t, DateTime day) async {
    await _b.cloudTasks.confirm(t, day, ref.read(myUidProvider));
    _b.push.notify('confirmed', t.id);
  }

  Future<void> reject(Task t, DateTime day) async {
    final claimant = completionOn(t, day)?.byUid;
    await _b.cloudTasks.reject(t, day, callerUid: ref.read(myUidProvider));
    _b.push.notify('rejected', t.id, toUid: claimant);
  }

  /// The group's people follow a task into the group; each is told once.
  Future<void> _followGroup(Task t, List<TaskMember> people) async {
    final fresh = people.where((p) => !t.members.any((m) => m.uid == p.uid)).toList();
    if (fresh.isEmpty) return;
    await _b.cloudTasks.addMembers(t, fresh);
    for (final p in fresh) {
      _b.push.notify('added', t.id, toUid: p.uid);
    }
    await _refreshGroupInvite(t.group!);
  }

  /// Joins whatever the code opens: one task, or every task of a group.
  /// Returns the group name when it was a group, else the task id.
  Future<JoinResult> join(String code) async {
    final invite = await _b.cloudTasks.resolveInvite(code);
    if (invite == null) throw StateError('invite not found');
    final uid = ref.read(myUidProvider);
    final name = ref.read(myNameProvider);
    if (!invite.isGroup) {
      final taskId = await _b.cloudTasks.joinByCode(code, uid, name);
      _b.push.notify('joined', taskId);
      return JoinResult(taskId: taskId);
    }
    var joined = 0;
    for (final taskCode in invite.taskCodes) {
      try {
        final taskId = await _b.cloudTasks.joinByCode(taskCode, uid, name);
        _b.push.notify('joined', taskId);
        joined++;
      } catch (_) {
        // A task since archived or deleted: the rest of the group still joins.
      }
    }
    if (joined == 0 && invite.taskCodes.isNotEmpty) throw StateError('invite not found');
    ref.read(groupFilterProvider.notifier).set(invite.group);
    return JoinResult(group: invite.group, joined: joined);
  }

  /// Shares every task the caller created in [group] with the holder of a
  /// personal code, turning personal tasks into shared ones on the way.
  /// Returns how many tasks now include that person.
  Future<int> shareGroupByCode(String group, String code) async {
    final clean = code.trim().toUpperCase();
    final person = await _b.cloudTasks.lookupPersonalCode(clean);
    if (person == null) throw StateError('no such code');
    final uid = ref.read(myUidProvider);
    var count = 0;
    for (final t in ref.read(allTasksProvider).where((t) => t.group == group && !t.archived && (t.ownerUid == uid || t.ownerUid == localOwnerUid))) {
      var shared = t;
      if (!t.isShared) shared = await save(t.copyWith(kind: TaskKind.shared));
      if (shared.members.any((m) => m.uid == person.uid)) {
        count++;
        continue;
      }
      await _b.cloudTasks.addMembers(shared, [person]);
      _b.push.notify('added', shared.id, toUid: person.uid);
      count++;
    }
    await _refreshGroupInvite(group);
    return count;
  }

  /// The link that lets anyone join the whole group. Personal tasks in the
  /// group become shared first, because a link can only open shared tasks.
  Future<String> groupInviteLink(String group) async {
    for (final t in ref.read(allTasksProvider).where((t) => t.group == group && !t.archived && !t.isShared)) {
      await save(t.copyWith(kind: TaskKind.shared));
    }
    final code = await _refreshGroupInvite(group);
    if (code == null) throw StateError('nothing to share');
    return '${Cloud.inviteBaseUrl}/$code';
  }

  Future<String?> _refreshGroupInvite(String group) async {
    final uid = ref.read(myUidProvider);
    final codes = [
      for (final t in ref.read(allTasksProvider))
        if (t.group == group && t.isShared && t.ownerUid == uid && !t.archived && t.inviteCode != null) t.inviteCode!,
    ];
    if (codes.isEmpty) return null;
    return _b.cloudTasks.ensureGroupInvite(uid, group, codes);
  }

  Future<void> deleteAccount() => _b.auth.deleteAccount(_b.cloudTasks.eraseEverythingOf);

  Future<void> addMemberByCode(Task t, String code) async {
    final clean = code.trim().toUpperCase();
    final person = await _b.cloudTasks.lookupPersonalCode(clean);
    await _b.cloudTasks.addMemberByCode(t, clean);
    if (person != null) _b.push.notify('added', t.id, toUid: person.uid);
  }

  Future<User?> signInQuick(String name) => _b.auth.signInQuick(name);
  Future<User?> signInWithEmail(String email, String password, {String? name}) => _b.auth.signInWithEmail(email, password, displayName: name);
  Future<void> sendPasswordReset(String email) => _b.auth.sendPasswordReset(email);
  Future<User?> linkGoogle() => _b.auth.linkGoogle();

  /// Marks a task done from a notification tap, whichever store holds it.
  Future<void> markDoneById(String taskId, String key) async {
    final t = ref.read(allTasksProvider).where((x) => x.id == taskId).firstOrNull;
    if (t == null) return;
    final p = key.split('-').map(int.parse).toList();
    await markDone(t, DateTime(p[0], p[1], p[2]));
  }
}

final taskActionsProvider = Provider<TaskActions>((ref) => TaskActions(ref));

/// Personal code arriving from a link or QR opened outside the app.
final incomingPersonCodeProvider = StreamProvider<String>((ref) {
  final b = ref.watch(bootstrapProvider);
  final ctl = StreamController<String>();
  b.deepLinks.initialPersonCode().then((c) {
    if (c != null && !ctl.isClosed) ctl.add(c);
  });
  final sub = b.deepLinks.personCodes().listen(ctl.add);
  ref.onDispose(() {
    sub.cancel();
    ctl.close();
  });
  return ctl.stream;
});

/// My personal code (allocated on first use once signed in).
final myCodeProvider = FutureProvider<String?>((ref) async {
  final b = ref.watch(bootstrapProvider);
  final user = ref.watch(authUserProvider).value;
  if (!b.cloudAvailable || user == null) return null;
  return b.cloudTasks.ensureMyCode(user.uid, ref.read(myNameProvider));
});

// ---------------------------------------------------------------- permissions
final notificationsEnabledProvider = FutureProvider<bool>((ref) => ref.watch(bootstrapProvider).scheduler.permissionGranted());
final exactAlarmsProvider = FutureProvider<bool>((ref) => ref.watch(bootstrapProvider).scheduler.canScheduleExact());

/// Invite code arriving from a deep link, consumed by the app shell.
final incomingInviteProvider = StreamProvider<String>((ref) {
  final b = ref.watch(bootstrapProvider);
  final ctl = StreamController<String>();
  b.deepLinks.initialCode().then((c) {
    if (c != null && !ctl.isClosed) ctl.add(c);
  });
  final sub = b.deepLinks.codes().listen(ctl.add);
  ref.onDispose(() {
    sub.cancel();
    ctl.close();
  });
  return ctl.stream;
});

class JoinResult {
  const JoinResult({this.taskId, this.group, this.joined = 1});
  final String? taskId;
  final String? group;
  final int joined;
}
