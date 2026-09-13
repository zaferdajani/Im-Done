import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../../models/plan.dart';
import '../../models/task.dart' show TaskMember;
import 'cloud.dart';
import 'cloud_tasks.dart';

/// The family / team environment and what was paid for it.
class WorkspaceService {
  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('workspaces');

  /// The one workspace this person belongs to (a person is in at most one).
  Stream<Workspace?> watchMine(String uid) => _col.where('memberUids', arrayContains: uid).limit(1).snapshots().map(
        (s) => s.docs.isEmpty ? null : Workspace.fromJson(s.docs.first.id, s.docs.first.data()),
      );

  Stream<Entitlement?> watchEntitlement(String wsId) => _db.collection('entitlements').doc(wsId).snapshots().map((d) => Entitlement.fromJson(d.data()));

  Stream<bool> watchBillingEnforced() => _db.collection('config').doc('billing').snapshots().map((d) => d.data()?['enforced'] == true);

  Future<Workspace> create(String name, WorkspaceKind kind, TaskMember me) async {
    final ref = _col.doc();
    final code = CloudTasks.newInviteCode();
    final batch = _db.batch();
    batch.set(ref, {
      'name': name,
      'kind': kind.name,
      'ownerUid': me.uid,
      'memberUids': [me.uid],
      'members': [me.toJson()],
      'inviteCode': code,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_db.collection('invites').doc(code), {'kind': 'workspace', 'workspaceId': ref.id, 'createdBy': me.uid, 'createdAt': FieldValue.serverTimestamp()});
    batch.set(_db.collection('users').doc(me.uid), {'workspaceId': ref.id}, SetOptions(merge: true));
    await batch.commit();
    return Workspace(id: ref.id, name: name, kind: kind, ownerUid: me.uid, members: [me], inviteCode: code);
  }

  /// Every member's own profile names the workspace (the rules read it
  /// there, and only the member may write it), so the app keeps it in step.
  Future<void> claimMembership(String uid, String? wsId) =>
      _db.collection('users').doc(uid).set({'workspaceId': wsId}, SetOptions(merge: true));

  Future<void> join(String wsId, String code, TaskMember me) async {
    try {
      await _col.doc(wsId).update({
        'memberUids': FieldValue.arrayUnion([me.uid]),
        'members': FieldValue.arrayUnion([me.toJson()]),
        'joinCode': code,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' && (await _col.doc(wsId).get()).exists) {
        // already a member
      } else {
        rethrow;
      }
    }
    await claimMembership(me.uid, wsId);
  }

  Future<void> addMember(Workspace ws, TaskMember person) async {
    if (ws.members.any((m) => m.uid == person.uid)) return;
    await _col.doc(ws.id).update({
      'memberUids': FieldValue.arrayUnion([person.uid]),
      'members': FieldValue.arrayUnion([person.toJson()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeMember(Workspace ws, String uid) => _col.doc(ws.id).update({
        'memberUids': FieldValue.arrayRemove([uid]),
        'members': ws.members.where((m) => m.uid != uid).map((m) => m.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> leave(Workspace ws, String uid) async {
    await removeMember(ws, uid);
    await claimMembership(uid, null);
  }

  Future<void> rename(Workspace ws, String name) => _col.doc(ws.id).update({'name': name, 'updatedAt': FieldValue.serverTimestamp()});

  /// The server grants one 30-day family trial per person.
  Future<Entitlement> startTrial(String wsId, String idToken) async {
    final res = await http
        .post(Uri.parse('${Cloud.pushEndpoint}/workspace/trial'), headers: {'Authorization': 'Bearer $idToken', 'Content-Type': 'application/json'}, body: jsonEncode({'workspaceId': wsId}))
        .timeout(const Duration(seconds: 20));
    final j = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    if (res.statusCode == 409) throw StateError('trial already used');
    if (res.statusCode != 200) throw StateError((j['error'] as String?) ?? 'HTTP ${res.statusCode}');
    return Entitlement.fromJson(Map<String, dynamic>.from(j['entitlement'] as Map))!;
  }
}
