import { test } from 'node:test';
import assert from 'node:assert/strict';
import { PLANS, TRIAL_DAYS, entitlementFromEvent, isActive, trialEntitlement, voiceAllowance, dayKey } from '../src/plans.mjs';

const now = new Date('2026-09-13T10:00:00Z');

test('a trial is a family plan for thirty days', () => {
  const t = trialEntitlement(now);
  assert.equal(t.plan, 'family');
  assert.equal(t.seats, PLANS.family.seats);
  assert.equal(t.source, 'trial');
  assert.equal(t.validUntil, new Date(now.getTime() + TRIAL_DAYS * 86400e3).toISOString());
  assert.ok(isActive(t, now));
  assert.ok(!isActive(t, new Date(now.getTime() + (TRIAL_DAYS + 1) * 86400e3)));
  assert.ok(!isActive(null, now));
  assert.ok(!isActive({ validUntil: 'garbage' }, now));
});

test('store events map to entitlements, unknown products to nothing', () => {
  const e = entitlementFromEvent({ type: 'INITIAL_PURCHASE', product_id: 'imdone_family_yearly', expiration_at_ms: now.getTime() + 1000, store: 'APP_STORE' }, undefined, now);
  assert.equal(e.plan, 'family');
  assert.equal(e.seats, 6);
  assert.equal(e.source, 'apple');
  assert.equal(entitlementFromEvent({ type: 'INITIAL_PURCHASE', product_id: 'imdone_team_10_monthly', expiration_at_ms: 1, store: 'PLAY_STORE' }, undefined, now).seats, 10);
  assert.equal(entitlementFromEvent({ type: 'INITIAL_PURCHASE', product_id: 'mystery', expiration_at_ms: 1 }, undefined, now), null);
  assert.equal(entitlementFromEvent({ type: 'EXPIRATION', product_id: 'imdone_family_monthly' }, undefined, now), null);
  assert.equal(entitlementFromEvent({ type: 'RENEWAL', product_id: 'imdone_family_monthly', expiration_at_ms: 'soon' }, undefined, now), null);
  assert.equal(entitlementFromEvent(null), null);
});

test('free callers get a daily voice allowance, plan holders do not run out', () => {
  assert.deepEqual(voiceAllowance(0, false), { allowed: true, remaining: PLANS.free.voicePerDay });
  assert.deepEqual(voiceAllowance(PLANS.free.voicePerDay, false), { allowed: false, remaining: 0 });
  assert.deepEqual(voiceAllowance(999, true), { allowed: true, remaining: null });
  assert.equal(dayKey(now), '2026-09-13');
});
