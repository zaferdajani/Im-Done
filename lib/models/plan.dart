/// A WORKSPACE is a payer's environment — a family or a team — whose
/// members get the plan's access. What was PAID lives in a separate
/// entitlement the server alone writes. Nothing is gated until the server
/// switches billing on, so the product stays fully usable meanwhile.
library;

import 'task.dart' show TaskMember;

enum WorkspaceKind { family, team }

class Workspace {
  const Workspace({required this.id, required this.name, required this.kind, required this.ownerUid, required this.members, this.inviteCode});
  final String id;
  final String name;
  final WorkspaceKind kind;
  final String ownerUid;
  final List<TaskMember> members;
  final String? inviteCode;

  List<String> get memberUids => members.map((m) => m.uid).toList();

  static Workspace fromJson(String id, Map<String, dynamic> j) => Workspace(
        id: id,
        name: (j['name'] as String?) ?? '',
        kind: j['kind'] == 'team' ? WorkspaceKind.team : WorkspaceKind.family,
        ownerUid: (j['ownerUid'] as String?) ?? '',
        members: ((j['members'] as List?) ?? const []).map((e) => TaskMember.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        inviteCode: j['inviteCode'] as String?,
      );
}

class Entitlement {
  const Entitlement({required this.plan, required this.seats, required this.validUntil, required this.source});
  final String plan; // family | team
  final int seats;
  final DateTime validUntil;
  final String source; // trial | apple | google | store | manual

  bool get active => validUntil.isAfter(DateTime.now());
  bool get isTrial => source == 'trial';

  static Entitlement? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final v = j['validUntil'];
    DateTime? until;
    if (v is DateTime) until = v;
    if (v is String) until = DateTime.tryParse(v);
    // cloud_firestore Timestamp exposes toDate(); avoid a hard import here.
    if (until == null && v != null) {
      try {
        until = (v as dynamic).toDate() as DateTime;
      } catch (_) {}
    }
    if (until == null) return null;
    return Entitlement(
      plan: (j['plan'] as String?) ?? 'family',
      seats: ((j['seats'] as num?) ?? 1).toInt(),
      validUntil: until.toLocal(),
      source: (j['source'] as String?) ?? 'store',
    );
  }
}

/// What the app shows as the current plan.
enum PlanLevel { free, trial, family, team }

PlanLevel planLevel(Workspace? ws, Entitlement? ent) {
  if (ws == null || ent == null || !ent.active) return PlanLevel.free;
  if (ent.isTrial) return PlanLevel.trial;
  return ent.plan == 'team' ? PlanLevel.team : PlanLevel.family;
}
