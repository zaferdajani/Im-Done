import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

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

  /// A member reports the occurrence done. Goes through the server so that
  /// nobody can confirm their own work: the function stamps confirmation
  /// only when the caller IS the creator.
  Future<void> claimDone(Task task, DateTime day, String uid, String name) async {
    await FirebaseFunctions.instance
        .httpsCallable('claimDone')
        .call<void>({'taskId': task.id, 'key': occurrenceKey(day), 'name': name});
  }

  /// The creator confirms a member's claim (direct write — rules allow only
  /// the creator to write the task document).
  Future<void> confirm(Task task, DateTime day, String creatorUid) async {
    final key = occurrenceKey(day);
    await _col.doc(task.id).update({
      'completions.$key.confirmedByUid': creatorUid,
      'completions.$key.confirmedAt': DateTime.now().toUtc().toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Removes a claim. The creator may remove any claim (rejecting it, and the
  /// nag resumes); a member may withdraw only their own unconfirmed one.
  Future<void> reject(Task task, DateTime day, {required String callerUid}) async {
    if (callerUid == task.ownerUid) {
      final key = occurrenceKey(day);
      await _col.doc(task.id).update({
        'completions.$key': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }
    await FirebaseFunctions.instance
        .httpsCallable('undoClaim')
        .call<void>({'taskId': task.id, 'key': occurrenceKey(day)});
  }

  /// Joining goes through a server function: a stranger holding a code may
  /// not read the task until the server has added them to it.
  Future<String> joinByCode(String code, String displayName) async {
    final res = await FirebaseFunctions.instance
        .httpsCallable('joinTask')
        .call<Map<dynamic, dynamic>>({'code': code, 'name': displayName});
    return (res.data['taskId'] as String?) ?? '';
  }

  Future<void> leave(Task task, String uid) async {
    await FirebaseFunctions.instance.httpsCallable('leaveTask').call<void>({'taskId': task.id});
  }
}
