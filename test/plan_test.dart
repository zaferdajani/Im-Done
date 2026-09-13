import 'package:flutter_test/flutter_test.dart';
import 'package:imdone/models/plan.dart';
import 'package:imdone/models/task.dart';

void main() {
  final me = TaskMember(uid: 'me', name: 'Me', joinedAt: DateTime(2026));
  final ws = Workspace(id: 'w', name: 'Family', kind: WorkspaceKind.family, ownerUid: 'me', members: [me]);

  test('no workspace or no live entitlement is the free level', () {
    expect(planLevel(null, null), PlanLevel.free);
    expect(planLevel(ws, null), PlanLevel.free);
    final expired = Entitlement(plan: 'family', seats: 6, validUntil: DateTime.now().subtract(const Duration(days: 1)), source: 'trial');
    expect(planLevel(ws, expired), PlanLevel.free);
  });

  test('a trial, a family and a team are told apart', () {
    final soon = DateTime.now().add(const Duration(days: 10));
    expect(planLevel(ws, Entitlement(plan: 'family', seats: 6, validUntil: soon, source: 'trial')), PlanLevel.trial);
    expect(planLevel(ws, Entitlement(plan: 'family', seats: 6, validUntil: soon, source: 'apple')), PlanLevel.family);
    expect(planLevel(ws, Entitlement(plan: 'team', seats: 10, validUntil: soon, source: 'google')), PlanLevel.team);
  });

  test('entitlements parse from strings and refuse garbage', () {
    final e = Entitlement.fromJson({'plan': 'team', 'seats': 5, 'validUntil': '2099-01-01T00:00:00Z', 'source': 'store'});
    expect(e!.seats, 5);
    expect(e.active, isTrue);
    expect(Entitlement.fromJson({'plan': 'team', 'validUntil': 'never'}), isNull);
    expect(Entitlement.fromJson(null), isNull);
  });

  test('a workspace reads its members', () {
    final w = Workspace.fromJson('x', {'name': 'Clinic', 'kind': 'team', 'ownerUid': 'a', 'members': [{'uid': 'a', 'name': 'A', 'joinedAt': '2026-01-01T00:00:00Z'}, {'uid': 'b', 'name': 'B', 'joinedAt': '2026-01-01T00:00:00Z'}]});
    expect(w.kind, WorkspaceKind.team);
    expect(w.memberUids, ['a', 'b']);
  });
}
