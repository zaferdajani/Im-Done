import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../l10n/strings.dart';
import '../models/task.dart';
import '../models/task_logic.dart';
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
  return device == 'ar' ? 'ar' : 'en';
});

final l10nProvider = Provider<L10n>((ref) => L10n.forCode(ref.watch(languageCodeProvider)));

// ---------------------------------------------------------------- identity
final authUserProvider = StreamProvider<User?>((ref) {
  final b = ref.watch(bootstrapProvider);
  if (!b.cloudAvailable) return Stream.value(null);
  return b.auth.changes;
});

/// Signed-in uid, or the local pseudo-owner when there is no account.
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

  Future<Task> save(Task t) async {
    if (t.isShared) {
      final user = ref.read(authUserProvider).value;
      if (user == null) throw StateError('sign-in required');
      final me = TaskMember(uid: user.uid, name: ref.read(myNameProvider), joinedAt: DateTime.now());
      final existing = ref.read(allTasksProvider).where((x) => x.id == t.id).firstOrNull;
      if (existing == null || !existing.isShared) {
        // Brand-new shared task (or a personal one being turned shared).
        final shared = t.copyWith(ownerUid: user.uid, ownerName: me.name, members: [me]);
        if (existing != null) await ref.read(localTasksProvider.notifier).remove(t.id);
        return _b.cloudTasks.create(shared);
      }
      await _b.cloudTasks.update(t);
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

  Future<String> join(String code) async {
    final taskId = await _b.cloudTasks.joinByCode(code, ref.read(myUidProvider), ref.read(myNameProvider));
    _b.push.notify('joined', taskId);
    return taskId;
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
