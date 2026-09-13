import { test } from 'node:test';
import assert from 'node:assert/strict';
import { recipients, message, KINDS } from '../src/logic.mjs';

const task = { ownerUid: 'alice', ownerName: 'Alice', memberUids: ['alice', 'bob', 'sara'], title: 'Water plants' };

test('added: only the creator, only to a current member, never to herself', () => {
  assert.deepEqual(recipients('added', task, 'alice', 'bob'), ['bob']);
  assert.deepEqual(recipients('added', task, 'alice', 'zed'), []);
  assert.deepEqual(recipients('added', task, 'alice', 'alice'), []);
  assert.deepEqual(recipients('added', task, 'bob', 'sara'), []);
});
test('joined and claimed go to the creator, never from the creator', () => {
  assert.deepEqual(recipients('joined', task, 'bob'), ['alice']);
  assert.deepEqual(recipients('claimed', task, 'sara'), ['alice']);
  assert.deepEqual(recipients('claimed', task, 'alice'), []);
});
test('confirmed goes from the creator to everyone else', () => {
  assert.deepEqual(recipients('confirmed', task, 'alice'), ['bob', 'sara']);
  assert.deepEqual(recipients('confirmed', task, 'bob'), []);
});
test('rejected targets the claimant when named, else everyone else', () => {
  assert.deepEqual(recipients('rejected', task, 'alice', 'sara'), ['sara']);
  assert.deepEqual(recipients('rejected', task, 'alice'), ['bob', 'sara']);
  assert.deepEqual(recipients('rejected', task, 'alice', 'zed'), ['bob', 'sara']);
});
test('a stranger gets nothing sent, whatever they ask', () => {
  for (const k of KINDS) assert.deepEqual(recipients(k, task, 'mallory', 'bob'), []);
  assert.deepEqual(recipients('nonsense', task, 'alice', 'bob'), []);
});
test('messages follow the recipient language and fall back to English', () => {
  assert.equal(message('claimed', 'ar', 'Water plants', 'Bob').title, 'Bob علّم المهمة كمُنجزة');
  assert.equal(message('claimed', 'fr', 'Water plants', 'Bob').title, "Bob l'a marquée comme faite");
  assert.equal(message('claimed', 'sw', 'Water plants', 'Bob').title, 'Bob marked it done');
  assert.equal(message('added', 'en', 'Water plants', 'Alice').body, 'Water plants');
});

test('push messages come from the shared language tables', () => {
  assert.deepEqual(message('claimed', 'ar', 'Water plants', 'Bob'), { title: 'Bob علّم المهمة كمُنجزة', body: 'Water plants — هل تؤكد؟' });
  assert.equal(message('added', 'es', 'Regar', 'Ana').title, 'Ana compartió una tarea contigo');
  assert.equal(message('joined', 'xx', 'T', 'Zed').title, 'Zed joined');
  assert.equal(message('rejected', 'ja', 'T', '花子').title, '花子 さん：まだ完了していません');
});
