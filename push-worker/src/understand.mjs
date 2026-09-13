// Pure, unit-tested half of the voice pipeline: what we ask the language
// model, and how strictly we read its answer. The network half (Whisper,
// the chat model, Gemini) lives in index.mjs and is deliberately thin.

/** Languages the product names on screen. Whisper recognises 99; anything
 *  outside this list is still transcribed and stored by its ISO code. */
export const LANGUAGES = {
  en: 'English', ar: 'Arabic', es: 'Spanish', zh: 'Chinese', ur: 'Urdu', gu: 'Gujarati',
  pt: 'Portuguese', fr: 'French', it: 'Italian', ru: 'Russian', uk: 'Ukrainian', ko: 'Korean',
  ja: 'Japanese', hi: 'Hindi', de: 'German', tr: 'Turkish', fa: 'Persian', bn: 'Bengali',
  id: 'Indonesian', ms: 'Malay', pa: 'Punjabi', ta: 'Tamil', te: 'Telugu', ml: 'Malayalam',
  tl: 'Filipino', nl: 'Dutch', pl: 'Polish', sv: 'Swedish', he: 'Hebrew', sw: 'Swahili', so: 'Somali',
};

/** Arabic varieties, most specific first inside each region. The model
 *  picks the most specific one it is confident about, else the region,
 *  else `msa`; anything unlisted is dropped rather than invented. */
export const ARABIC_DIALECTS = [
  'msa',
  'egyptian', 'sudanese',
  'levantine', 'jordanian', 'palestinian', 'syrian', 'lebanese',
  'gulf', 'saudi', 'hejazi', 'najdi', 'emirati', 'kuwaiti', 'qatari', 'bahraini', 'omani',
  'iraqi', 'yemeni',
  'maghrebi', 'moroccan', 'algerian', 'tunisian', 'libyan',
];

export const FREQUENCIES = ['once', 'daily', 'weekdays', 'weekly', 'everyNDays'];
export const CATEGORIES = ['health', 'work', 'home', 'shopping', 'family', 'money', 'study', 'errands', 'fitness'];

/** Whisper reports language NAMES in verbose_json ("arabic"); map to codes. */
const NAME_TO_CODE = Object.fromEntries(Object.entries(LANGUAGES).map(([c, n]) => [n.toLowerCase(), c]));
const EXTRA_NAMES = { mandarin: 'zh', cantonese: 'zh', tagalog: 'tl', farsi: 'fa', dutch: 'nl', norwegian: 'no', danish: 'da', finnish: 'fi', greek: 'el', czech: 'cs', romanian: 'ro', hungarian: 'hu', thai: 'th', vietnamese: 'vi', hebrew: 'he' };
export function languageCode(whisperLanguage) {
  if (!whisperLanguage) return null;
  const s = String(whisperLanguage).trim().toLowerCase();
  if (/^[a-z]{2,3}$/.test(s)) return s;
  return NAME_TO_CODE[s] ?? EXTRA_NAMES[s] ?? null;
}

/**
 * The instruction for the structuring model. `now` is the caller's local
 * time as an ISO string with weekday, so "tomorrow" and "next Monday" are
 * resolved in THEIR calendar, not the worker's.
 */
export function buildSystemPrompt({ now, weekday, uiLanguage, preferred }) {
  const pref = preferred && preferred !== 'en'
    ? `The speaker's preferred language is "${preferred}" (${LANGUAGES[preferred] ?? preferred}); they usually speak it or English. When the words could belong to more than one language, prefer that one.`
    : "The speaker's preferred language is English.";
  return [
    'You turn one spoken sentence into a reminder task. Reply with ONE JSON object and nothing else.',
    'The sentence may be in any language, in any accent or dialect, and may mix languages. Do not translate the task: keep the title in the language it was spoken.',
    `The speaker's current local date and time is ${now} (${weekday}). Resolve relative dates against it.`,
    `The app is displayed in "${uiLanguage}".`,
    pref,
    '',
    'Fields:',
    '  "title": the task itself, short, in the spoken language, without the schedule words ("call the pharmacy", not "call the pharmacy every day at 9").',
    `  "language": ISO 639-1 code of the language spoken (${Object.keys(LANGUAGES).join(', ')} or any other).`,
    `  "dialect": only when language is "ar": one of ${ARABIC_DIALECTS.join(', ')}. Choose the most specific one you are confident about; "msa" for Modern Standard Arabic; null if unsure.`,
    `  "frequency": one of ${FREQUENCIES.join(', ')}. "once" when a single date or no repetition is meant; "weekdays" means Monday-Friday; "weekly" needs "weekdays"; "everyNDays" needs "everyNDays".`,
    '  "weekdays": array of ISO weekday numbers 1=Monday .. 7=Sunday (only for weekly).',
    '  "everyNDays": integer >= 2 (only for everyNDays).',
    '  "hour", "minute": 24-hour time of day, or null when none was spoken. Understand local conventions: Arabic "الساعة ٥ المغرب/العصر/المسا" is afternoon or evening, "الصبح/الفجر" morning; "half past", "و نص", "quarter to".',
    '  "date": ISO date (YYYY-MM-DD) for a one-off or for the first day of a repeating task, or null when it starts today.',
    '  "periodDays": integer number of days the task runs ("for two weeks" = 14), or null.',
    '  "note": anything spoken that is not the task or its schedule, else null.',
    '  "group": a group the speaker files the task under ("for work", "in my home list", "للشغل", "para la casa") — the group name only, in the spoken language, else null. Never invent one.',
    `  "category": what kind of task it is, one of ${CATEGORIES.join(', ')} (medicine and doctors are health; bills and bank are money; groceries are shopping; the gym is fitness; driving somewhere to get something done is errands), or null when none fits clearly.`,
    '  "importance": "high" when the speaker says it is urgent, very important, a must, critical ("ضروري", "مهم جدًا", "urgente", "急ぎ"); "low" when they say it is not important, whenever, if there is time, low priority ("مش مهم", "لو فضيت"); otherwise "medium".',
    '',
    'Never invent a schedule the speaker did not say. When nothing is scheduled, frequency is "once" with hour and minute null.',
  ].join('\n');
}

export function buildUserPrompt(transcript, detectedLanguage) {
  const hint = detectedLanguage ? ` (speech recogniser thinks the language is "${detectedLanguage}")` : '';
  return `Spoken sentence${hint}:\n${transcript}`;
}

const int = (v, lo, hi) => {
  const n = Number(v);
  return Number.isInteger(n) && n >= lo && n <= hi ? n : null;
};

/**
 * Reads the model's JSON strictly: every field is validated, anything odd
 * is dropped, and a missing title falls back to the transcript so a task
 * is ALWAYS produced from a non-empty sentence.
 */
export function parseUnderstanding(raw, transcript, detectedLanguage) {
  let j = {};
  try {
    const text = typeof raw === 'string' ? raw : JSON.stringify(raw ?? {});
    const m = text.match(/\{[\s\S]*\}/);
    j = m ? JSON.parse(m[0]) : {};
  } catch {
    j = {};
  }
  const title = typeof j.title === 'string' && j.title.trim() ? j.title.trim().slice(0, 200) : String(transcript ?? '').trim().slice(0, 200);
  let language = languageCode(j.language) ?? languageCode(detectedLanguage);
  if (language && !/^[a-z]{2,3}$/.test(language)) language = null;
  const dialect = language === 'ar' && ARABIC_DIALECTS.includes(j.dialect) ? j.dialect : null;
  let frequency = FREQUENCIES.includes(j.frequency) ? j.frequency : 'once';
  let weekdays = Array.isArray(j.weekdays) ? [...new Set(j.weekdays.map((d) => int(d, 1, 7)).filter((d) => d !== null))].sort() : [];
  let everyNDays = int(j.everyNDays, 2, 365);
  if (frequency === 'weekly' && weekdays.length === 0) frequency = 'once';
  if (frequency !== 'weekly') weekdays = [];
  if (frequency === 'everyNDays' && everyNDays === null) frequency = 'daily';
  if (frequency !== 'everyNDays') everyNDays = null;
  const hour = int(j.hour, 0, 23);
  const minute = hour === null ? null : (int(j.minute, 0, 59) ?? 0);
  const date = typeof j.date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(j.date) ? j.date : null;
  const periodDays = int(j.periodDays, 1, 3660);
  const note = typeof j.note === 'string' && j.note.trim() ? j.note.trim().slice(0, 500) : null;
  const importance = ['high', 'medium', 'low'].includes(j.importance) ? j.importance : 'medium';
  const group = typeof j.group === 'string' && j.group.trim() ? j.group.trim().slice(0, 40) : null;
  const category = CATEGORIES.includes(j.category) ? j.category : null;
  return { title, language, dialect, frequency, weekdays, everyNDays, hour, minute, date, periodDays, note, importance, group, category, transcript: String(transcript ?? '').trim() };
}

/** Audio the endpoint accepts: bounded so one caller cannot eat the day's quota. */
export const MAX_AUDIO_BYTES = 4 * 1024 * 1024; // ~2 min of 16 kHz mono WAV
export function audioAcceptable(bytes, contentType) {
  if (!bytes || bytes < 1000) return { ok: false, reason: 'empty' };
  if (bytes > MAX_AUDIO_BYTES) return { ok: false, reason: 'too long' };
  const ct = String(contentType ?? '').toLowerCase();
  if (ct && !/^audio\/|^video\/(mp4|webm)|octet-stream/.test(ct)) return { ok: false, reason: 'not audio' };
  return { ok: true };
}
