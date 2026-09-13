# Voice in every language — what was compared and what I'm Done uses

*Researched 2026-09-13. Constraint from the owner: no paid plan, ever.*

## The two jobs

Turning a held-button recording into a task is two separate jobs, and the second
is where "Arabic in any dialect" is actually decided:

1. **Hear the words and tell which language they are in** (speech-to-text with
   language identification).
2. **Read a schedule out of the words** ("every day at half five in the evening",
   "كل يوم الساعة خمسة ونص المسا") and, for Arabic, **name the dialect**.

Before this change the app did job 1 with the phone's own recogniser (Apple
Speech / Android SpeechRecognizer), which must be told the language *before* it
listens, and job 2 with hand-written English/Arabic patterns. Neither scales to
"whatever language is spoken".

## Engines compared for job 1

| Engine | Auto language detection | Arabic dialects | Cost on a zero plan | Verdict |
|---|---|---|---|---|
| **Whisper large-v3-turbo on Groq** | Yes, returns the language | Trained on dialectal speech; fine-tunes show Egyptian/Levantine/Gulf/Iraqi/Maghrebi all recognised; it reports `ar`, not the dialect | **Free**: 20 req/min, 2,000 req/day, 8 h audio/day, 25 MB per file | **Chosen** |
| ElevenLabs Scribe v2 | Yes | Best published code-switching and Arabic results | Paid ($0.22/h); free plan credits are small | Best accuracy, not free |
| Deepgram Nova-3 | Yes (multilingual mode) | Good | $200 credit then paid | Not free |
| Gemini 2.5 Flash (AI Studio key) | Yes; can also do job 2 in the same call | Good | Free tier: ~250 req/day, 10 req/min | **Kept as the fallback** |
| Qwen3-ASR (open source) | Yes, 52 languages + dialects | Strong | Free to run, but needs a GPU server — not on a zero plan | No |
| On-device whisper.cpp (`whisper_ggml`) | `auto` | Only the *small*/*medium* models are usable for Arabic (0.5–1.5 GB download, slow on phones) | Free | Too heavy for a phone; kept in mind for offline later |
| Phone's own recogniser (existing) | No — language chosen in advance | Locale-level only | Free | Kept as the **offline / "nothing leaves the phone"** option |

## Job 2

A free language model on Groq (`openai/gpt-oss-120b`, falling back to
`llama-3.3-70b-versatile`) is given the transcript and the speaker's local
date/time and returns strict JSON: title (never translated), language, Arabic
dialect from a fixed list, frequency, weekdays, time, start date, period, note.
The worker validates every field and drops anything it does not recognise, so a
confused answer degrades to "a one-off task titled with the words heard" rather
than an invented schedule (`push-worker/src/understand.mjs`, unit-tested).

Dialects the model may name: Standard Arabic, Egyptian, Sudanese, Levantine
(Jordanian, Palestinian, Syrian, Lebanese), Gulf (Saudi, Hejazi, Najdi, Emirati,
Kuwaiti, Qatari, Bahraini, Omani), Iraqi, Yemeni, Maghrebi (Moroccan, Algerian,
Tunisian, Libyan). Languages named on screen: English, Arabic, Spanish, Chinese,
Urdu, Gujarati, Portuguese, French, Italian, Russian, Ukrainian, Korean,
Japanese, Hindi, German, Turkish, Persian, Bengali, Indonesian, Malay, Punjabi,
Tamil, Telugu, Malayalam, Filipino, Dutch, Polish, Swedish, Hebrew, Swahili,
Somali — anything else Whisper hears is still transcribed and stored by its code.

## How it is wired

- The phone records 16 kHz mono PCM while the button is held (max 45 s), wraps it
  as WAV in memory and POSTs it to the worker's `/transcribe` with the Firebase
  sign-in token. Nothing is written to disk on the phone or the server.
- The worker only serves signed-in callers. To keep the microphone free of a
  login wall, the app signs in **anonymously and silently** the first time voice
  is used; sharing still asks for a name.
- Settings → Voice offers "Every language and accent" (default) or "This phone
  only" (the old path, English/Arabic, offline).
- The task remembers `language`, `dialect` and the `transcript`; the list shows
  "Arabic · Jordanian" under the task and the detail screen shows what was heard.

## Limits to know

- Groq's free tier caps the whole app at 2,000 recordings a day; beyond that the
  worker answers with an error and the app tells the user to try again.
- Whisper does not itself say *which* Arabic dialect; the language model infers
  it from the words and may leave it blank when unsure. That is honest, not a bug.
- Both keys (`GROQ_API_KEY`, optional `GEMINI_API_KEY`) live only as Cloudflare
  Worker secrets.

Sources: Groq speech-to-text docs and rate-limit table; Northflank and Gladia
open-source STT round-ups (2026); ElevenLabs Scribe v2 announcement and the
arXiv code-switching benchmark (2605.19069); "Overcoming Data Scarcity in
Multi-Dialectal Arabic ASR via Whisper Fine-Tuning" (Interspeech 2025);
Casablanca multidialectal Arabic ASR (2410.04527); Qwen3-ASR release notes;
pub.dev `whisper_ggml` / `whisper_kit`.
