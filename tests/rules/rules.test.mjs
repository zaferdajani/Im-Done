import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, updateDoc, deleteDoc, arrayUnion, arrayRemove, deleteField } from 'firebase/firestore';
import { readFileSync } from 'node:fs';

const env = await initializeTestEnvironment({
  projectId: 'demo-imdone',
  firestore: { rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
});
const db = (uid) => env.authenticatedContext(uid).firestore();
const anon = env.unauthenticatedContext().firestore();
let pass = 0, fail = 0;
async function t(name, fn) { try { await fn(); pass++; console.log('  ok  ' + name); } catch (e) { fail++; console.log('  FAIL ' + name + ': ' + (e.message || e).toString().split('\n')[0]); } }

const owner = 'alice', member = 'bob', stranger = 'carol';
const base = () => ({
  title: 'Water plants', kind: 'shared', ownerUid: owner, ownerName: 'Alice', frequency: 'daily',
  hour: 9, minute: 0, memberUids: [owner], members: [{ uid: owner, name: 'Alice', joinedAt: 'x' }], completions: {}, inviteCode: 'ABCD2345',
});
await env.withSecurityRulesDisabled(async (ctx) => {
  const d = ctx.firestore();
  await setDoc(doc(d, 'tasks/t1'), base());
  await setDoc(doc(d, 'invites/ABCD2345'), { taskId: 't1', createdBy: owner });
  await setDoc(doc(d, 'invites/WRONG000'), { taskId: 'other', createdBy: 'zed' });
  await setDoc(doc(d, 'codes/BOBB1234'), { uid: member, name: 'Bob' });
});
const bobMember = { uid: member, name: 'Bob', joinedAt: 'y' };

console.log('create');
await t('owner creates own shared task', () => assertSucceeds(setDoc(doc(db(owner), 'tasks/t2'), base())));
await t('cannot create a task owned by someone else', () => assertFails(setDoc(doc(db(stranger), 'tasks/t3'), { ...base(), ownerUid: owner })));
await t('cannot create with extra members', () => assertFails(setDoc(doc(db(stranger), 'tasks/t4'), { ...base(), ownerUid: stranger, memberUids: [stranger, member], members: [{ uid: stranger, name: 'C', joinedAt: 'x' }, bobMember] })));
await t('anonymous cannot create', () => assertFails(setDoc(doc(anon, 'tasks/t5'), base())));

console.log('read');
await t('member reads', () => assertSucceeds(getDoc(doc(db(owner), 'tasks/t1'))));
await t('stranger cannot read', () => assertFails(getDoc(doc(db(stranger), 'tasks/t1'))));
await t('invite readable by signed-in', () => assertSucceeds(getDoc(doc(db(stranger), 'invites/ABCD2345'))));
await t('invite not readable anonymously', () => assertFails(getDoc(doc(anon, 'invites/ABCD2345'))));

console.log('workspaces');
const ws = () => ({ name: 'Dajani family', kind: 'family', ownerUid: owner, memberUids: [owner], members: [{ uid: owner, name: 'Alice', joinedAt: 'x' }] });
await t('owner creates a workspace', () => assertSucceeds(setDoc(doc(db(owner), 'workspaces/w1'), ws())));
await t('a workspace cannot declare its own plan', () => assertFails(setDoc(doc(db(owner), 'workspaces/w2'), { ...ws(), plan: 'team' })));
await t('cannot create a workspace for someone else', () => assertFails(setDoc(doc(db(stranger), 'workspaces/w3'), ws())));
await t('member of no workspace cannot read it', () => assertFails(getDoc(doc(db(member), 'workspaces/w1'))));
await t('nobody writes an entitlement from the client', () => assertFails(setDoc(doc(db(owner), 'entitlements/w1'), { plan: 'team', seats: 99, validUntil: new Date(Date.now() + 864e5) })));
await t('nobody flips the billing switch from the client', () => assertFails(setDoc(doc(db(owner), 'config/billing'), { enforced: false })));
await env.withSecurityRulesDisabled(async (ctx) => {
  await setDoc(doc(ctx.firestore(), 'invites/WSJOIN01'), { kind: 'workspace', workspaceId: 'w1', createdBy: owner });
});
const wsJoin = (code) => ({ memberUids: arrayUnion(member), members: arrayUnion(bobMember), joinCode: code, updatedAt: 'now' });
await t('joins a workspace with its invite', () => assertSucceeds(updateDoc(doc(db(member), 'workspaces/w1'), wsJoin('WSJOIN01'))));
await t('a task invite does not open a workspace', () => assertFails(updateDoc(doc(db(stranger), 'workspaces/w1'), { memberUids: arrayUnion(stranger), members: arrayUnion({ uid: stranger, name: 'C', joinedAt: 'z' }), joinCode: 'ABCD2345', updatedAt: 'now' })));
await t('member reads the workspace', () => assertSucceeds(getDoc(doc(db(member), 'workspaces/w1'))));
await t('member leaves the workspace', () => assertSucceeds(updateDoc(doc(db(member), 'workspaces/w1'), { memberUids: arrayRemove(member), members: [{ uid: owner, name: 'Alice', joinedAt: 'x' }], updatedAt: 'now' })));
await t('owner adds a person to the workspace directly', () => assertSucceeds(updateDoc(doc(db(owner), 'workspaces/w1'), { memberUids: arrayUnion(member), members: arrayUnion(bobMember), updatedAt: 'now' })));

console.log('billing enforced');
await env.withSecurityRulesDisabled(async (ctx) => {
  const d = ctx.firestore();
  await setDoc(doc(d, 'config/billing'), { enforced: true });
  await setDoc(doc(d, 'users/alice'), { workspaceId: 'w1' });
  await setDoc(doc(d, 'users/zed'), { workspaceId: 'w1' }); // claims a workspace it is not in
  await setDoc(doc(d, 'tasks/free1'), { ...base(), ownerUid: 'zed', memberUids: ['zed', 'a', 'b'], members: [{ uid: 'zed', name: 'Z', joinedAt: 'x' }, { uid: 'a', name: 'A', joinedAt: 'x' }, { uid: 'b', name: 'B', joinedAt: 'x' }], inviteCode: 'ZEDINV01' });
  await setDoc(doc(d, 'invites/ZEDINV01'), { taskId: 'free1', createdBy: 'zed' });
  await setDoc(doc(d, 'tasks/paid1'), { ...base(), ownerUid: owner, memberUids: [owner, 'a', 'b'], members: [{ uid: owner, name: 'Alice', joinedAt: 'x' }, { uid: 'a', name: 'A', joinedAt: 'x' }, { uid: 'b', name: 'B', joinedAt: 'x' }], inviteCode: 'ALIINV01' });
  await setDoc(doc(d, 'invites/ALIINV01'), { taskId: 'paid1', createdBy: owner });
});
const joinAs = (who, code) => ({ memberUids: arrayUnion(who), members: arrayUnion({ uid: who, name: who, joinedAt: 'y' }), joinCode: code, updatedAt: 'now' });
await t('a fourth person cannot join a free creator\'s task', () => assertFails(updateDoc(doc(db('carol'), 'tasks/free1'), joinAs('carol', 'ZEDINV01'))));
await t('a fourth person cannot join without a live entitlement either', () => assertFails(updateDoc(doc(db('carol'), 'tasks/paid1'), joinAs('carol', 'ALIINV01'))));
await env.withSecurityRulesDisabled(async (ctx) => {
  await setDoc(doc(ctx.firestore(), 'entitlements/w1'), { plan: 'family', seats: 6, validUntil: new Date(Date.now() + 864e5), source: 'trial' });
});
await t('with a live entitlement the fourth person joins', () => assertSucceeds(updateDoc(doc(db('carol'), 'tasks/paid1'), joinAs('carol', 'ALIINV01'))));
await t('claiming a workspace you are not in earns nothing', () => assertFails(updateDoc(doc(db('carol'), 'tasks/free1'), joinAs('carol', 'ZEDINV01'))));
await t('the workspace fills to its seats and no further', async () => {
  for (const who of ['s3', 's4', 's5', 's6']) await assertSucceeds(updateDoc(doc(db(who), 'workspaces/w1'), { memberUids: arrayUnion(who), members: arrayUnion({ uid: who, name: who, joinedAt: 'y' }), joinCode: 'WSJOIN01', updatedAt: 'now' }));
  await assertFails(updateDoc(doc(db('s7'), 'workspaces/w1'), { memberUids: arrayUnion('s7'), members: arrayUnion({ uid: 's7', name: 's7', joinedAt: 'y' }), joinCode: 'WSJOIN01', updatedAt: 'now' }));
});
await t('a member of the paid workspace reads its entitlement, a stranger cannot', async () => {
  await assertSucceeds(getDoc(doc(db(member), 'entitlements/w1')));
  await assertFails(getDoc(doc(db('carol'), 'entitlements/w1')));
});
await env.withSecurityRulesDisabled(async (ctx) => { await setDoc(doc(ctx.firestore(), 'config/billing'), { enforced: false }); });

console.log('group invites');
await t('creator makes a group invite', () => assertSucceeds(setDoc(doc(db(owner), 'invites/GRP00001'), { kind: 'group', group: 'Home', createdBy: owner, taskCodes: ['ABCD2345'] })));
await t('creator grows it', () => assertSucceeds(updateDoc(doc(db(owner), 'invites/GRP00001'), { taskCodes: ['ABCD2345', 'ZZZZ9999'] })));
await t('someone else cannot change it', () => assertFails(updateDoc(doc(db(stranger), 'invites/GRP00001'), { taskCodes: ['EVIL0000'] })));
await t('creator cannot hand it to someone else', () => assertFails(updateDoc(doc(db(owner), 'invites/GRP00001'), { createdBy: stranger })));
await t('a single-task invite cannot be repointed', () => assertFails(updateDoc(doc(db(owner), 'invites/ABCD2345'), { taskId: 'other' })));

console.log('join');
const joinPayload = (code) => ({ memberUids: arrayUnion(member), members: arrayUnion(bobMember), joinCode: code, updatedAt: 'now' });
await t('join with wrong code refused', () => assertFails(updateDoc(doc(db(member), 'tasks/t1'), joinPayload('WRONG000'))));
await t('join adding someone else refused', () => assertFails(updateDoc(doc(db(member), 'tasks/t1'), { memberUids: arrayUnion(stranger), members: arrayUnion({ uid: stranger, name: 'C', joinedAt: 'z' }), joinCode: 'ABCD2345', updatedAt: 'now' })));
await t('join that also edits the title refused', () => assertFails(updateDoc(doc(db(member), 'tasks/t1'), { ...joinPayload('ABCD2345'), title: 'hacked' })));
await t('join with the right code succeeds', () => assertSucceeds(updateDoc(doc(db(member), 'tasks/t1'), joinPayload('ABCD2345'))));
await t('joining twice refused', () => assertFails(updateDoc(doc(db(member), 'tasks/t1'), joinPayload('ABCD2345'))));
await t('member now reads', () => assertSucceeds(getDoc(doc(db(member), 'tasks/t1'))));

console.log('claims');
const claim = (by, extra = {}) => ({ ['completions.2026-09-12']: { byUid: by, byName: 'x', at: 'now', ...extra }, lastClaimKey: '2026-09-12', updatedAt: 'now' });
await t('member claim naming themselves succeeds', () => assertSucceeds(updateDoc(doc(db(member), 'tasks/t1'), claim(member))));
await t('member cannot confirm their own claim', () => assertFails(updateDoc(doc(db(member), 'tasks/t1'), claim(member, { confirmedAt: 'now', confirmedByUid: member }))));
await t('member cannot claim as somebody else', () => assertFails(updateDoc(doc(db(member), 'tasks/t1'), { ['completions.2026-09-13']: { byUid: owner, byName: 'x', at: 'now' }, lastClaimKey: '2026-09-13', updatedAt: 'now' })));
await t('member cannot touch two days at once', () => assertFails(updateDoc(doc(db(member), 'tasks/t1'), { ['completions.2026-09-13']: { byUid: member, byName: 'x', at: 'now' }, ['completions.2026-09-14']: { byUid: member, byName: 'x', at: 'now' }, lastClaimKey: '2026-09-13', updatedAt: 'now' })));
await t('member cannot edit the title', () => assertFails(updateDoc(doc(db(member), 'tasks/t1'), { title: 'nope' })));
await t('stranger cannot claim', () => assertFails(updateDoc(doc(db(stranger), 'tasks/t1'), claim(stranger))));
await t('member withdraws own unconfirmed claim', () => assertSucceeds(updateDoc(doc(db(member), 'tasks/t1'), { ['completions.2026-09-12']: deleteField(), lastClaimKey: '2026-09-12', updatedAt: 'now' })));
await t('member re-claims', () => assertSucceeds(updateDoc(doc(db(member), 'tasks/t1'), claim(member))));
await t('owner confirms', () => assertSucceeds(updateDoc(doc(db(owner), 'tasks/t1'), { ['completions.2026-09-12.confirmedByUid']: owner, ['completions.2026-09-12.confirmedAt']: 'now', updatedAt: 'now' })));
await t('member cannot withdraw a confirmed claim', () => assertFails(updateDoc(doc(db(member), 'tasks/t1'), { ['completions.2026-09-12']: deleteField(), lastClaimKey: '2026-09-12', updatedAt: 'now' })));
await t('member cannot overwrite a confirmed claim', () => assertFails(updateDoc(doc(db(member), 'tasks/t1'), claim(member))));
await t('owner rejects (removes) a claim', () => assertSucceeds(updateDoc(doc(db(owner), 'tasks/t1'), { ['completions.2026-09-12']: deleteField(), updatedAt: 'now' })));
await t('owner cannot hand the task to someone else', () => assertFails(updateDoc(doc(db(owner), 'tasks/t1'), { ownerUid: member })));
await t('owner archives', () => assertSucceeds(updateDoc(doc(db(owner), 'tasks/t1'), { archived: true })));
await t('nobody deletes', () => assertFails(deleteDoc(doc(db(owner), 'tasks/t1'))));

console.log('leave + codes');
await t('member cannot remove the owner', () => assertFails(updateDoc(doc(db(member), 'tasks/t1'), { memberUids: arrayRemove(owner), members: [bobMember], updatedAt: 'now' })));
await t('member leaves', () => assertSucceeds(updateDoc(doc(db(member), 'tasks/t1'), { memberUids: arrayRemove(member), members: [{ uid: owner, name: 'Alice', joinedAt: 'x' }], updatedAt: 'now' })));
await t('owner adds a person by code (direct member add)', () => assertSucceeds(updateDoc(doc(db(owner), 'tasks/t1'), { memberUids: arrayUnion(member), members: arrayUnion(bobMember), updatedAt: 'now' })));
await t('signed-in reads a personal code', () => assertSucceeds(getDoc(doc(db(stranger), 'codes/BOBB1234'))));
await t('cannot register a code for someone else', () => assertFails(setDoc(doc(db(stranger), 'codes/CAROL999'), { uid: member, name: 'x' })));
await t('registers own code', () => assertSucceeds(setDoc(doc(db(stranger), 'codes/CAROL999'), { uid: stranger, name: 'Carol' })));
await t('cannot delete another person\'s code', () => assertFails(deleteDoc(doc(db(stranger), 'codes/BOBB1234'))));
await t('users doc private', () => assertFails(getDoc(doc(db(stranger), 'users/bob'))));

await env.cleanup();
console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
