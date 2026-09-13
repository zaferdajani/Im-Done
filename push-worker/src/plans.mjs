// Plans, pure and unit-tested. A WORKSPACE is a payer's environment (a
// family or a team); an ENTITLEMENT is what was paid for it, and is the
// only thing here the server writes on its own authority.

export const PLANS = {
  free: { seats: 1, voicePerDay: 10 },
  family: { seats: 6 },
  team: { seatsMin: 5 },
};

export const TRIAL_DAYS = 30;

/** Map store product ids to a plan. Configurable via the PRODUCTS env
 *  var (JSON of {productId: {plan, seats}}); these are the defaults. */
export const DEFAULT_PRODUCTS = {
  imdone_family_monthly: { plan: 'family', seats: 6 },
  imdone_family_yearly: { plan: 'family', seats: 6 },
  imdone_team_5_monthly: { plan: 'team', seats: 5 },
  imdone_team_10_monthly: { plan: 'team', seats: 10 },
  imdone_team_25_monthly: { plan: 'team', seats: 25 },
};

export function dayKey(now = new Date()) {
  return now.toISOString().slice(0, 10);
}

export function trialEntitlement(now = new Date()) {
  return {
    plan: 'family',
    seats: PLANS.family.seats,
    source: 'trial',
    validUntil: new Date(now.getTime() + TRIAL_DAYS * 86400e3).toISOString(),
    grantedAt: now.toISOString(),
  };
}

export function isActive(entitlement, now = new Date()) {
  if (!entitlement || !entitlement.validUntil) return false;
  const until = new Date(entitlement.validUntil);
  return !Number.isNaN(until.getTime()) && until.getTime() > now.getTime();
}

/**
 * A RevenueCat webhook event → an entitlement (or null when the event
 * ends access). Only the fields we rely on are read; anything odd yields
 * null rather than a guess.
 */
export function entitlementFromEvent(event, products = DEFAULT_PRODUCTS, now = new Date()) {
  if (!event || typeof event !== 'object') return null;
  const product = products[event.product_id];
  if (!product) return null;
  const ending = ['CANCELLATION', 'EXPIRATION', 'BILLING_ISSUE'].includes(event.type) && !event.expiration_at_ms;
  if (ending) return null;
  const until = Number(event.expiration_at_ms);
  if (!Number.isFinite(until) || until <= 0) return null;
  const store = String(event.store ?? '').toLowerCase();
  return {
    plan: product.plan,
    seats: product.seats,
    source: store.includes('app_store') ? 'apple' : store.includes('play') ? 'google' : 'store',
    validUntil: new Date(until).toISOString(),
    grantedAt: now.toISOString(),
    productId: event.product_id,
  };
}

/** Whether a free caller may still use cloud voice today. */
export function voiceAllowance(usedToday, hasPlan) {
  if (hasPlan) return { allowed: true, remaining: null };
  const remaining = Math.max(0, PLANS.free.voicePerDay - usedToday);
  return { allowed: remaining > 0, remaining };
}
