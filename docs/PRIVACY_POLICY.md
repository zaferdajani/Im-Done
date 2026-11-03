# I'm Done — Privacy Policy

> **DRAFT for owner and counsel review — not legal advice.** Replace every `[BRACKET]` before
> publishing. The same text, in HTML, is `web/privacy.html`; keep the two in step and bump
> `Cloud.policyVersion` (`lib/services/cloud/cloud.dart`) when the substance changes.

Version: 2026-11-03 · Controller: [OWNER LEGAL NAME], [ADDRESS], Amman, Jordan ·
Privacy requests: **privacy@[YOUR-DOMAIN]** · EU/UK representative (if required): [NAME / N/A]

## 1. What I'm Done does
I'm Done turns what you say into tasks, reminds you until they are done, and lets you share a task
with people you invite. This policy applies to the app (iOS, Android, web) and the services behind it.

## 2. What we collect, why, and on what legal basis

| Data | Purpose | Legal basis (GDPR / PDPL) | Kept |
|---|---|---|---|
| Personal tasks, reminders, settings | Run the app | Contract / necessity. **Stored only on your device**, never sent to us | Until you delete them or uninstall |
| Voice recording (when you hold the microphone, default engine) | Turn speech into task text | **Your consent** (you start each recording; you can switch to on-device speech in Settings → Voice) | **Not stored.** Processed in memory, discarded at once |
| Transcript text, detected language, today's date/weekday, UI language | Read the task and schedule out of your words | Consent / contract | Sent with the request only; not kept by us. Task fields you save are kept with the task |
| Account: user ID, display name, email (Google/Apple/email sign-in), sign-in method | Sharing, sync, notifications | Contract | Until you delete your account |
| Shared tasks: text, schedule, completion records, names of members | Let invited people see and complete a task | Contract | Until the owner archives/you delete your account (archived content is emptied on deletion) |
| Device push token, language | Send push notifications about shared tasks | Contract / consent (you allow notifications in the OS) | Until sign-out or account deletion |
| Consent log (policy version, time, age confirmation, marketing yes/no) | Prove consent | Legal obligation / legitimate interest | Until account deletion |
| Reports about other users (reporter, reported user, task, reason) | Moderation (required by app stores) | Legitimate interest | 12 months, then deleted automatically |
| Per-day voice usage counter | Apply plan limits | Contract | 35 days (deleted automatically) |
| Subscription status (when plans go on sale) | Provide paid features | Contract | While the plan is active + legal retention for invoices |
| Optional product news/offers | Marketing, **only if you tick the separate box** | Consent (withdraw any time) | Until you withdraw |

We do **not** use advertising or analytics SDKs, we do not track you across apps or sites, and we
never sell your data.

## 3. Who receives data (service providers)
Full, current list: **/subprocessors**.

- **Google Firebase** (Authentication, Cloud Firestore, Cloud Messaging) — accounts, shared tasks,
  notifications. Data location: **London (europe-west2)**.
- **Cloudflare, Inc.** (Workers) — our small server that relays notifications and voice requests.
  It does not store audio or tasks.
- **Groq, Inc.** (US) — speech-to-text (Whisper) and the language model that reads the task out of
  your words. Receives the audio and transcript for that request.
- **Google (Gemini API)** — fallback speech/understanding provider, used only if the primary
  provider fails. Receives the audio/transcript for that request.
- **OpenAI** — some Groq-hosted models (e.g. `gpt-oss`) are OpenAI open-weight models running on
  Groq's servers; no data is sent to OpenAI itself. If we ever call OpenAI directly this section
  and /subprocessors will be updated first.
- **Apple / Google** — sign-in providers; and, only if you choose the on-device speech option,
  your phone's speech service (Apple Speech / Google speech recognition), under their policies.
- **GitHub Pages** (GitHub, Inc.) — hosts the web app and invitation links; sees ordinary web
  request data (IP address).
- **RevenueCat / Apple App Store / Google Play** — only once paid plans are enabled.

Other people on a shared task can see your display name and your actions on that task.

## 4. International transfers
Firebase data is held in London. Voice requests are processed by providers in the **United States**
(Groq, Google, Cloudflare's network). Transfers rely on your explicit consent (starting a voice
recording, with an on-device alternative always available) and on the providers' Standard
Contractual Clauses / data-processing terms (GDPR Art. 46 / 49(1)(a); Saudi PDPL Art. 29 and
Transfer Regulations; Jordanian PDPL). You may avoid all voice transfers by choosing
Settings → Voice → on-device.

## 5. How long we keep data
Personal tasks: on your device only. Account data: until you delete the account. Reports: 12 months.
Voice audio: not kept. Inactive accounts: deleted after 24 months without sign-in [OWNER: schedule the purge in docs/RETENTION.md before publishing, or delete this sentence]. Backups at
Google age out on Google's own deletion schedule. We may keep minimal records where the law requires.

## 6. Your rights
Under the Saudi Personal Data Protection Law (PDPL), the EU/UK GDPR and the Jordanian PDPL (No. 24 of
2023) you may: be informed; **access** your data (Settings → Account → *Download my data*);
**correct** it; **erase** it (Settings → Account → *Delete my account*, or /delete-account);
**restrict or object** to processing; **port** your data; **withdraw consent** at any time
(sign out/delete, change Settings → Voice, or email us to stop marketing); and **complain** to
the regulator — in Saudi Arabia the Saudi Data & AI Authority (SDAIA); in the EU your national
supervisory authority; in the UK the ICO.

Email **privacy@[YOUR-DOMAIN]**. We reply within **30 days** (and tell you if we need longer for a
complex request). We may ask you to prove it is your account.

## 7. Children
You must be **16 or older** to create an account; sign-up asks you to confirm this and does not
proceed otherwise. If we learn that someone under 16 has an account we delete it. The app without
an account (personal tasks on the device) collects nothing.

## 8. Security
Encrypted connections; access rules that let you read only tasks you belong to; no audio storage; push
credentials held only on our server. No system is perfectly secure. If a breach puts your rights at risk
we notify the authorities within 72 hours and tell you without undue delay (see our incident response plan).

## 9. Changes
We post changes here with the date and, for material changes, ask you to agree again.

## 10. Contact
[OWNER LEGAL NAME] · privacy@[YOUR-DOMAIN] · [POSTAL ADDRESS]

---

## العربية (ملخص — يلزم اعتماد ترجمة قانونية كاملة)
**المسؤول:** [الاسم القانوني]، عمّان، الأردن — **privacy@[YOUR-DOMAIN]**.
المهام الشخصية تبقى على جهازك فقط. عند استخدام الميكروفون بالمحرك الافتراضي يُرسل الصوت (ولا يُخزَّن)
إلى مزوّدين في الولايات المتحدة (Groq، وGoogle Gemini احتياطيًا، عبر Cloudflare) لتحويله إلى مهمة، وذلك
بموافقتك الصريحة؛ ويمكنك اختيار التعرّف على الكلام داخل الجهاز من الإعدادات. تُخزَّن بيانات الحساب
والمهام المشتركة لدى Google Firebase في لندن. لا إعلانات ولا تتبّع ولا بيع للبيانات.
**حقوقك** بموجب نظام حماية البيانات الشخصية السعودي (PDPL) واللائحة الأوروبية (GDPR) والقانون الأردني:
الاطلاع، والتصحيح، والحذف، والاعتراض، ونقل البيانات، وسحب الموافقة، والشكوى إلى الهيئة السعودية للبيانات
والذكاء الاصطناعي (سدايا). نردّ خلال 30 يومًا. الحد الأدنى للعمر 16 عامًا. مدة الاحتفاظ: الحساب حتى الحذف،
والبلاغات 12 شهرًا، والصوت لا يُحفظ.
