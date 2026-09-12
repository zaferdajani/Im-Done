// Pure decisions, unit-tested: who gets told what, in which language.

export const KINDS = ['added', 'joined', 'claimed', 'confirmed', 'rejected'];

const STRINGS = {
  en: {
    added: (t, who) => ({ title: `${who} shared a task with you`, body: t }),
    joined: (t, who) => ({ title: `${who} joined`, body: t }),
    claimed: (t, who) => ({ title: `${who} marked it done`, body: `${t} — confirm?` }),
    confirmed: (t, who) => ({ title: `Confirmed by ${who}`, body: t }),
    rejected: (t, who) => ({ title: `${who} says: not done yet`, body: t }),
  },
  ar: {
    added: (t, who) => ({ title: `${who} شارك مهمة معك`, body: t }),
    joined: (t, who) => ({ title: `انضم ${who}`, body: t }),
    claimed: (t, who) => ({ title: `${who} علّم المهمة كمُنجزة`, body: `${t} — هل تؤكد؟` }),
    confirmed: (t, who) => ({ title: `أكّدها ${who}`, body: t }),
    rejected: (t, who) => ({ title: `${who} يقول: لم تُنجز بعد`, body: t }),
  },
};

export function message(kind, lang, title, who) {
  const l = lang === 'ar' ? 'ar' : 'en';
  return STRINGS[l][kind](title, who);
}

/**
 * Which member uids may be told, given who is asking. Returns [] when the
 * request is not one the product allows — the sender is not a member, or
 * asks for a recipient the kind does not permit.
 *
 *  added     creator → the person just added (must be a member now)
 *  joined    new member → the creator
 *  claimed   member → the creator
 *  confirmed / rejected   creator → everyone else (rejected: the claimant only, if named)
 */
export function recipients(kind, task, senderUid, toUid) {
  const members = task.memberUids ?? [];
  if (!members.includes(senderUid)) return [];
  const owner = task.ownerUid;
  switch (kind) {
    case 'added':
      return senderUid === owner && toUid && toUid !== owner && members.includes(toUid) ? [toUid] : [];
    case 'joined':
    case 'claimed':
      return senderUid !== owner ? [owner] : [];
    case 'confirmed':
      return senderUid === owner ? members.filter((u) => u !== owner) : [];
    case 'rejected':
      if (senderUid !== owner) return [];
      return toUid && members.includes(toUid) && toUid !== owner ? [toUid] : members.filter((u) => u !== owner);
    default:
      return [];
  }
}
