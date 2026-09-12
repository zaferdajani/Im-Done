import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/task.dart';
import '../../models/task_logic.dart';

/// Shared tasks live in Firestore. The document shape is Task.toJson() plus
/// `memberUids` (a flat array the security rules filter on) and
/// `updatedAt`. Members read the same document; reminders are scheduled
/// locally on every member's phone from it.
class CloudTasks {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('tasks');

  Stream<List<Task>> watchMine(String uid) => _col
      .where('memberUids', arrayContains: uid)
      .snapshots()
      .map((s) => s.docs.map((d) => Task.fromJson(_withId(d))).where((t) => !t.archived).toList());

  Map<String, dynamic> _withId(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = Map<String, dynamic>.from(d.data() ?? {});
    m['id'] = d.id;
    return m;
  }

  static String newInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /// Creates the task with the creator as first member and an invite code.
  Future<Task> create(Task task) async {
    final code = task.inviteCode ?? newInviteCode();
    final withCode = task.copyWith(inviteCode: code);
    final data = withCode.toJson()
      ..remove('id')
      ..['updatedAt'] = FieldValue.serverTimestamp();
    final batch = _db.batch();
    batch.set(_col.doc(task.id), data);
    batch.set(_db.collection('invites').doc(code), {
      'taskId': task.id,
      'createdBy': task.ownerUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return withCode;
  }

  Future<void> update(Task task) async {
    final data = task.toJson()
      ..remove('id')
      ..['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(task.id).set(data, SetOptions(merge: true));
  }

  Future<void> archive(Task task) => _col.doc(task.id).update({'archived': true, 'updatedAt': FieldValue.serverTimestamp()});

  /// A member reports the occurrence done. Written directly; the security
  /// rules (`isClaim`) accept exactly one new completion naming the caller
  /// and never a confirmation — only the creator's write may carry one.
  Future<void> claimDone(Task task, DateTime day, String uid, String name) async {
    final key = occurrenceKey(day);
    final now = DateTime.now();
    final mine = uid == task.ownerUid;
    final c = Completion(
      byUid: uid,
      byName: name,
      at: now,
      confirmedByUid: mine ? uid : null,
      confirmedAt: mine ? now : null,
    );
    await _col.doc(task.id).update({
      'completions.$key': c.toJson(),
      'lastClaimKey': key,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// The creator confirms a member's claim.
  Future<void> confirm(Task task, DateTime day, String creatorUid) async {
    final key = occurrenceKey(day);
    await _col.doc(task.id).update({
      'completions.$key.confirmedByUid': creatorUid,
      'completions.$key.confirmedAt': DateTime.now().toUtc().toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Removes a claim. The creator may remove any (rejecting it, the nag
  /// resumes); a member only their own unconfirmed one (`isUndo`).
  Future<void> reject(Task task, DateTime day, {required String callerUid}) async {
    final key = occurrenceKey(day);
    await _col.doc(task.id).update({
      'completions.$key': FieldValue.delete(),
      'lastClaimKey': key,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Joining: the invite document names the task; the update appends the
  /// caller and nothing else, which is all the rules (`isJoin`) accept.
  Future<String> joinByCode(String code, String uid, String displayName) async {
    final invite = await _db.collection('invites').doc(code).get();
    final taskId = invite.data()?['taskId'] as String?;
    if (taskId == null) throw StateError('invite not found');
    final ref = _col.doc(taskId);
    final member = TaskMember(uid: uid, name: displayName, joinedAt: DateTime.now());
    try {
      await ref.update({
        'memberUids': FieldValue.arrayUnion([uid]),
        'members': FieldValue.arrayUnion([member.toJson()]),
        'joinCode': code,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      // Already a member: the rules refuse a second join, but the task is
      // readable, which is the proof.
      if (e.code == 'permission-denied' && (await ref.get()).exists) return taskId;
      rethrow;
    }
    return taskId;
  }

  // ------------------------------------------------------------ personal codes
  /// Every account carries a short personal code others can type to add
  /// them to a task. Created once; `codes/{code}` maps back to the person.
  Future<String> ensureMyCode(String uid, String displayName) async {
    final me = _db.collection('users').doc(uid);
    final snap = await me.get();
    final existing = snap.data()?['code'] as String?;
    if (existing != null) return existing;
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = newInviteCode();
      final codeRef = _db.collection('codes').doc(code);
      try {
        await _db.runTransaction((tx) async {
          final taken = await tx.get(codeRef);
          if (taken.exists) throw StateError('taken');
          tx.set(codeRef, {'uid': uid, 'name': displayName, 'createdAt': FieldValue.serverTimestamp()});
          tx.set(me, {'code': code, 'displayName': displayName}, SetOptions(merge: true));
        });
        return code;
      } on StateError {
        continue;
      }
    }
    throw StateError('could not allocate a code');
  }

  /// Who owns a personal code (null if nobody).
  Future<TaskMember?> lookupPersonalCode(String code) async {
    final snap = await _db.collection('codes').doc(code).get();
    final d = snap.data();
    if (d == null) return null;
    return TaskMember(uid: d['uid'] as String, name: (d['name'] as String?) ?? '', joinedAt: DateTime.now());
  }

  /// The creator adds a person directly by their personal code.
  Future<void> addMemberByCode(Task task, String code) async {
    final person = await lookupPersonalCode(code);
    if (person == null) throw StateError('no such code');
    if (task.members.any((m) => m.uid == person.uid)) return;
    await _col.doc(task.id).update({
      'memberUids': FieldValue.arrayUnion([person.uid]),
      'members': FieldValue.arrayUnion([person.toJson()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> leave(Task task, String uid) async {
    await _col.doc(task.id).update({
      'memberUids': FieldValue.arrayRemove([uid]),
      'members': task.members.where((m) => m.uid != uid).map((m) => m.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Account deletion, client side: leave every task, archive the ones I
  /// own, drop my profile. The Auth user itself is deleted by AuthService.
  Future<void> eraseEverythingOf(String uid) async {
    final mine = await _col.where('memberUids', arrayContains: uid).get();
    for (final d in mine.docs) {
      final t = Task.fromJson({...d.data(), 'id': d.id});
      if (t.ownerUid == uid) {
        await d.reference.update({
          'archived': true,
          'title': '[deleted]',
          'note': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await leave(t, uid);
      }
    }
    final invites = await _db.collection('invites').where('createdBy', isEqualTo: uid).get();
    for (final d in invites.docs) {
      await d.reference.delete();
    }
    final me = await _db.collection('users').doc(uid).get();
    final code = me.data()?['code'] as String?;
    if (code != null) await _db.collection('codes').doc(code).delete();
    await _db.collection('users').doc(uid).delete();
  }
}
