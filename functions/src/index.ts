/**
 * I'm Done backend — three small pieces, all about SHARED tasks.
 *
 *  joinTask(code)      callable  — adds the caller to the task behind an invite code.
 *  deleteAccount()     callable  — App Store 5.1.1(v) / Play policy: erases the user.
 *  onTaskWritten       trigger   — pushes to members: new task, claimed done, confirmed.
 *
 * Reminders themselves are LOCAL on each phone; nothing here schedules time.
 */
import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { getMessaging } from "firebase-admin/messaging";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { onDocumentWritten } from "firebase-functions/v2/firestore";

initializeApp();
const db = getFirestore();

const REGION = "europe-west2"; // London, beside the owner's other backend

type Member = { uid: string; name: string; joinedAt: string };
type Completion = { byUid: string; byName: string; at: string; confirmedByUid?: string; confirmedAt?: string };
type TaskDoc = {
  title: string;
  ownerUid: string;
  ownerName: string;
  memberUids: string[];
  members: Member[];
  completions: Record<string, Completion>;
  hour: number;
  minute: number;
  frequency: string;
  archived?: boolean;
};

const STRINGS = {
  en: {
    newTask: (t: string, who: string) => ({ title: `New shared task from ${who}`, body: t }),
    claimed: (t: string, who: string) => ({ title: `${who} marked it done`, body: `${t} — confirm?` }),
    confirmed: (t: string, who: string) => ({ title: `Confirmed by ${who}`, body: t }),
    rejected: (t: string, who: string) => ({ title: `${who} says: not done yet`, body: t }),
    joined: (t: string, who: string) => ({ title: `${who} joined`, body: t }),
  },
  ar: {
    newTask: (t: string, who: string) => ({ title: `مهمة مشتركة جديدة من ${who}`, body: t }),
    claimed: (t: string, who: string) => ({ title: `${who} علّم المهمة كمُنجزة`, body: `${t} — هل تؤكد؟` }),
    confirmed: (t: string, who: string) => ({ title: `أكّدها ${who}`, body: t }),
    rejected: (t: string, who: string) => ({ title: `${who} يقول: لم تُنجز بعد`, body: t }),
    joined: (t: string, who: string) => ({ title: `انضم ${who}`, body: t }),
  },
};
type Kind = keyof typeof STRINGS.en;

async function notify(uids: string[], kind: Kind, title: string, who: string, taskId: string) {
  if (uids.length === 0) return;
  const users = await db.getAll(...uids.map((u) => db.doc(`users/${u}`)));
  const jobs: Promise<unknown>[] = [];
  for (const u of users) {
    const tokens: string[] = (u.get("tokens") as string[] | undefined) ?? [];
    if (tokens.length === 0) continue;
    const lang = (u.get("languageCode") as string | undefined) === "ar" ? "ar" : "en";
    const msg = STRINGS[lang][kind](title, who);
    jobs.push(
      getMessaging()
        .sendEachForMulticast({
          tokens,
          notification: msg,
          data: { taskId, kind },
          android: { priority: "high", notification: { channelId: "task_reminders_v1" } },
          apns: { payload: { aps: { sound: "default", "thread-id": taskId } } },
        })
        .then(async (res) => {
          // Drop tokens the provider says are dead.
          const dead = res.responses
            .map((r, i) => (r.success ? null : tokens[i]))
            .filter((t): t is string => !!t);
          if (dead.length) await u.ref.update({ tokens: FieldValue.arrayRemove(...dead) });
        })
        .catch((e) => console.error("push failed", e)),
    );
  }
  await Promise.all(jobs);
}

export const joinTask = onCall({ region: REGION }, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "sign in first");
  const code = String(req.data?.code ?? "").toUpperCase().replace(/[^A-Z0-9]/g, "");
  const name = String(req.data?.name ?? "").slice(0, 80).trim() || "Someone";
  if (code.length !== 8) throw new HttpsError("invalid-argument", "bad code");

  const invite = await db.doc(`invites/${code}`).get();
  if (!invite.exists) throw new HttpsError("not-found", "invite not found");
  const taskId = invite.get("taskId") as string;
  const ref = db.doc(`tasks/${taskId}`);

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists || snap.get("archived") === true) throw new HttpsError("not-found", "task gone");
    const t = snap.data() as TaskDoc;
    if (t.memberUids.includes(uid)) return { taskId, alreadyMember: true };
    if (t.memberUids.length >= 50) throw new HttpsError("resource-exhausted", "task is full");
    const member: Member = { uid, name, joinedAt: new Date().toISOString() };
    tx.update(ref, {
      memberUids: FieldValue.arrayUnion(uid),
      members: FieldValue.arrayUnion(member),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { taskId, alreadyMember: false, ownerUid: t.ownerUid, title: t.title };
  });

  if (!result.alreadyMember && result.ownerUid) {
    await notify([result.ownerUid], "joined", result.title ?? "", name, taskId);
  }
  return { taskId };
});

/** A member reports an occurrence done. The creator's own report is also its confirmation. */
export const claimDone = onCall({ region: REGION }, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "sign in first");
  const taskId = String(req.data?.taskId ?? "");
  const key = String(req.data?.key ?? "");
  const name = String(req.data?.name ?? "").slice(0, 80).trim() || "Someone";
  if (!/^\d{4}-\d{2}-\d{2}$/.test(key) || !taskId) throw new HttpsError("invalid-argument", "bad args");
  const ref = db.doc(`tasks/${taskId}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "task gone");
    const t = snap.data() as TaskDoc;
    if (!t.memberUids.includes(uid)) throw new HttpsError("permission-denied", "not a member");
    const existing = t.completions?.[key];
    if (existing?.confirmedAt) return; // already done — nothing to claim
    const now = new Date().toISOString();
    const c: Completion = { byUid: uid, byName: name, at: now };
    if (uid === t.ownerUid) {
      c.confirmedByUid = uid;
      c.confirmedAt = now;
    }
    tx.update(ref, { [`completions.${key}`]: c, updatedAt: FieldValue.serverTimestamp() });
  });
  return { ok: true };
});

/** A member withdraws their OWN unconfirmed claim. */
export const undoClaim = onCall({ region: REGION }, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "sign in first");
  const taskId = String(req.data?.taskId ?? "");
  const key = String(req.data?.key ?? "");
  const ref = db.doc(`tasks/${taskId}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "task gone");
    const t = snap.data() as TaskDoc;
    const c = t.completions?.[key];
    if (!c) return;
    if (c.byUid !== uid && t.ownerUid !== uid) throw new HttpsError("permission-denied", "not your claim");
    if (c.confirmedAt && t.ownerUid !== uid) throw new HttpsError("failed-precondition", "already confirmed");
    tx.update(ref, { [`completions.${key}`]: FieldValue.delete(), updatedAt: FieldValue.serverTimestamp() });
  });
  return { ok: true };
});

/** A member leaves a task (the creator archives instead). */
export const leaveTask = onCall({ region: REGION }, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "sign in first");
  const taskId = String(req.data?.taskId ?? "");
  const ref = db.doc(`tasks/${taskId}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return;
    const t = snap.data() as TaskDoc;
    if (t.ownerUid === uid) throw new HttpsError("failed-precondition", "the creator archives instead");
    tx.update(ref, {
      memberUids: FieldValue.arrayRemove(uid),
      members: (t.members ?? []).filter((m) => m.uid !== uid),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return { ok: true };
});

export const deleteAccount = onCall({ region: REGION }, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "sign in first");

  // 1. Tasks I own → archived and emptied (members keep nothing of mine).
  const owned = await db.collection("tasks").where("ownerUid", "==", uid).get();
  // 2. Tasks I belong to → leave.
  const member = await db.collection("tasks").where("memberUids", "array-contains", uid).get();
  const batch = db.batch();
  for (const d of owned.docs) {
    batch.update(d.ref, { archived: true, memberUids: [], members: [], completions: {}, title: "[deleted]", note: FieldValue.delete() });
  }
  for (const d of member.docs) {
    if (d.get("ownerUid") === uid) continue;
    const members = ((d.get("members") as Member[]) ?? []).filter((m) => m.uid !== uid);
    batch.update(d.ref, { memberUids: FieldValue.arrayRemove(uid), members });
  }
  // 3. Invites I created.
  const invites = await db.collection("invites").where("createdBy", "==", uid).get();
  for (const d of invites.docs) batch.delete(d.ref);
  // 4. Profile + tokens.
  batch.delete(db.doc(`users/${uid}`));
  await batch.commit();
  // 5. The Auth user itself, last, so a failure above leaves a retryable state.
  await getAuth().deleteUser(uid);
  return { ok: true };
});

export const onTaskWritten = onDocumentWritten({ region: REGION, document: "tasks/{taskId}" }, async (event) => {
  const before = event.data?.before.data() as TaskDoc | undefined;
  const after = event.data?.after.data() as TaskDoc | undefined;
  const taskId = event.params.taskId;
  if (!after || after.archived) return;

  // New task → tell every member except the creator (usually nobody yet;
  // people who join later are told at join time via the invite flow).
  if (!before) {
    const others = after.memberUids.filter((u) => u !== after.ownerUid);
    await notify(others, "newTask", after.title, after.ownerName, taskId);
    return;
  }

  // Completion changes.
  const bc = before.completions ?? {};
  const ac = after.completions ?? {};
  for (const key of Object.keys(ac)) {
    const now = ac[key];
    const was = bc[key];
    if (!was && now.byUid !== after.ownerUid && !now.confirmedAt) {
      await notify([after.ownerUid], "claimed", after.title, now.byName, taskId);
    } else if (was && !was.confirmedAt && now.confirmedAt) {
      const others = after.memberUids.filter((u) => u !== after.ownerUid);
      await notify(others, "confirmed", after.title, after.ownerName, taskId);
    }
  }
  for (const key of Object.keys(bc)) {
    if (!ac[key] && !bc[key].confirmedAt && bc[key].byUid !== after.ownerUid) {
      // The creator removed a claim: tell the claimant it is not done yet.
      await notify([bc[key].byUid], "rejected", after.title, after.ownerName, taskId);
    }
  }
});
