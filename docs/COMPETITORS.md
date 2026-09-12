# I'm Done — Competitive Landscape & Free Alternatives

*Compiled 2026-09-12 from 20+ live store/vendor/GitHub lookups. "unverified" = not confirmable
from a primary source.*

## 1. The answer

**No shipping app does all three well:** hold-to-speak capture **+** nag-until-done reminders
**+** shared tasks where the **creator confirms** completion. The pieces exist separately; the
combination, and specifically creator-confirmed completion between adults (not parent → child),
is unoccupied.

If you want something to use TODAY while I'm Done is built:

| Need | Best free option today | What it lacks |
|---|---|---|
| Closest overall | **Galarm** (iOS/Android; free = 1 group alarm + 1 buddy alarm; Premium $0.99/mo, $9.99/yr, $24.99 lifetime) | No voice capture; alarm-shaped rather than task-shaped; recent reviews report missed alarms |
| Voice + shared, iOS only | **Apple Reminders** (free; Siri dictation, shared lists, assignment, "Notify when completing items") | No nag loop, no confirmation step, iOS only |
| Nag until done, iOS | **Due** ($7.99 once) — auto-snooze every 1–60 min, up to 10 repeats | Single-user, no voice, no Android |
| Nag until done, Android | **nag reminder** / **Againly** (free tiers) | Tiny (~6k installs), reliability complaints, no sharing |
| Shared chores with approval | **Sweepy**, **DoMore** (free tiers) | Parent-validates-child model with points and stars; no voice, no nag |

## 2. The landscape

### 2a. Voice-first capture (crowded, new, small)

| App | What it does | Price | Hold-to-speak | Nag | Shared + confirm |
|---|---|---|---|---|---|
| [VoiceTask AI](https://voicetask.app/) | Voice → parsed tasks, 39 languages | Free 10 notes/day; Pro $9.99/mo | unverified | No | No |
| [SpeakDo](https://apps.apple.com/us/app/speakdo-smart-voice-reminders/id6765878225) | On-device Apple Intelligence voice → reminder | $3.99 | unverified | No | No |
| [Voiset](https://play.google.com/store/apps/details?id=com.unionsmarttechnology.voiset) | "Press and speak", 55 languages | unverified | Yes | unverified | unverified |
| [Braintoss](https://apps.apple.com/us/app/braintoss/id576226036) | Speak → emailed to inbox | $2.99 once | Yes | No | No |
| Todoist + Ramble | Voice-to-task in 38 languages (2026) | Free 5 projects; Pro $5/mo | No | No | Shared, no confirm |
| TickTick 8.x | AI voice input (2026) | Premium $35.99/yr | No | Premium reminders ring until done | Shared, no confirm |
| Apple Reminders | Siri, shared lists, assignment | Free | Siri | No | Notify only |
| [Taskitos](https://www.taskitos.com/) | "Persistent nagging" | Free tier, web only | coming soon | Yes | No |

### 2b. Nag-until-done (commoditized on iOS, empty on Android)

| App | Price | Platform | Mechanism |
|---|---|---|---|
| [Due](https://apps.apple.com/us/app/due-reminders-timers/id390017969) | $7.99 once | iOS/Mac | Auto-snooze 1/5/10/15/30/60 min, up to 10 repeats |
| [Timely – Repeat Notifications](https://apps.apple.com/us/app/timely-repeat-notifications/id6759700975) | Free + $9.99/yr | iOS/Mac | Per-task 5/15/60 min, breaks Silent & Focus |
| [Nag: constant reminder](https://apps.apple.com/us/app/-/id6760954480) | Free | iOS 26.2+ | Custom interval until complete |
| [nag reminder](https://play.google.com/store/apps/details?id=com.robinkunz.nag) | ~$11/yr | Android | Nag intervals; ~6.2k installs |
| [Againly](https://play.google.com/store/apps/details?id=com.againly) | Free + Premium | Android | Priority-based nudges |

### 2c. Shared / chores / approval

| App | Price | Confirmation step |
|---|---|---|
| [Galarm](https://apps.apple.com/us/app/galarm-alarms-and-reminders/id1187849174) | Free 1+1; $9.99/yr | Participants confirm/decline group alarms; buddy alarms report completion. 4.7★ / 4.4K (iOS), ~5M downloads claimed |
| [Cozi](https://www.cozi.com/compare-plans/) | Free w/ ads; Gold $39/yr | No |
| [Sweepy](https://www.commonsensemedia.org/app-reviews/sweepy-home-cleaning-schedule) | Free 1 user; Premium ~$13–20/yr (unverified) | Parent validates child |
| [DoMore](https://www.do-more.io/best-chore-apps-for-families/) | Free + IAP | Parent approves, tied to rewards |
| OurHome | **Dead** (unpublished 2023) | Had adult approval. Cautionary tale: launched free with no revenue model |
| Microsoft To Do | Free | Assign yes, confirm no |
| Google Tasks | Free | No sharing at all |
| Any.do | Family $8.33/mo (4 members) | No |

Accountability apps (Focusmate, Beeminder, StickK, HabitShare) track *your* streak, not a task you
assigned to someone else. Habit trackers (Loop, Habitica, Streaks, Habitify, Fabulous) are a
different job: self-directed repetition, no delegation.

## 3. The gap, stated honestly

Unoccupied:
1. Voice + nag + shared-with-confirmation in one app on both platforms (zero products).
2. **Creator confirmation between peers.** Every shipping confirmation flow is parent → child with
   stars. "I asked my brother to renew the insurance; he says he did; I approve" has no home.
3. Nag-until-done on Android at all (the category leader has ~6,200 installs; Due never shipped there).
4. Nagging a *shared* task — every nag app is single-user.

Not a gap:
- Voice-to-task is being absorbed by incumbents (Todoist Ramble, TickTick, Apple Intelligence).
  Table stakes by 2027, not a moat.
- Nag intervals are trivially copyable.
- Apple could close most of this with one Reminders toggle.

The defensible thing is the **loop**: spoken in two seconds → nagged until acted on → confirmed
by the person who asked. It creates two-sided usage (the assigner returns to confirm), which none
of the single-player nag apps have. And OurHome's death says: price from day one.

**Engineering warning from the market:** Galarm, with 5M users and 9 years of work, still draws
reviews about alarms not firing. Alarm reliability under Doze, battery optimisation and iOS
background limits is the actual product risk, not the interface.

## 4. Open-source you could build on

| Repo | What | License | Note |
|---|---|---|---|
| [tasks/tasks](https://tasks.org/) | Mature Android to-do, recurring, CalDAV | GPL-3.0 | Best reference for reliable Android alarms; GPL is viral, read it, do not link it |
| [rxlabz/sytody](https://github.com/rxlabz/sytody) | Flutter speech-to-todo proof of concept | none declared | Reference only |
| [dominikdoric/house-work-app](https://github.com/dominikdoric/house-work-app) | Flutter + Firebase family chores | MIT | Usable skeleton |
| [csdcorp/speech_to_text](https://github.com/csdcorp/speech_to_text) | The Flutter STT plugin | BSD-3 (unverified) | **Used by I'm Done** |
| [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) | Local scheduling | BSD-3 (unverified) | **Used by I'm Done** |
| [alarm](https://pub.dev/packages/alarm) | Foreground-service alarms, survives termination | MIT (unverified) | Stronger nag engine if reliability complaints appear; needs Play permission review |

## 5. Name

"SayDone" is crowded: a Lovable site at say-done.lovable.app, an unrelated saydone.net, and two
App Store apps **SayDo** and **Saydo AI** (a voice task app for ADHD, a direct near-namesake).
The project therefore ships as **I'm Done** ("done by Tuesday", "done by Sara" — deadline and
delegation in one word), which returned no store or product hits. Alternatives that also came
back clean: Naggo, Yapdone, Blurtly, Nagster. Before store submission: trademark search
(USPTO/EUIPO), exact-match store search, `.com`/`.app` domain check — all **unverified** beyond
web search.
