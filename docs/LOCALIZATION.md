# The translation pipeline

Every word the app shows passes through one door. Nothing is typed into a
screen; screens read `L10n.of(context)`, and the tables behind it are
generated from one JSON file per language.

```
l10n/en.json  ──┐
l10n/ar.json  ──┤   python3 tool/gen_l10n.py   ┌─► lib/l10n/tables.g.dart      (the app)
l10n/es.json  ──┼──────────────────────────────┤
…               │                              └─► push-worker/src/push-strings.g.json  (notifications between phones)
l10n/ko.json  ──┘
```

- **`l10n/<code>.json`** is the source of truth for a language: the same keys
  as `en.json`, localized as native product wording (the terms an app in that
  language uses), not word-for-word. Sixteen today: English, Arabic, Spanish,
  French, Portuguese, Italian, Turkish, Russian, Ukrainian, Hindi, Urdu,
  Gujarati, Persian, Chinese, Japanese, Korean.
- **The generator refuses** a table that is missing a key, has an empty
  value, or drops a `{placeholder}` the English carries. A language cannot
  half-exist and a screen can never fall back to English by accident.
- **`lib/l10n/supported.dart`** lists what the picker offers, with each
  language's own name, and which languages read right to left (Arabic, Urdu,
  Persian). Flutter mirrors the whole layout for those from the locale.
- **`test/l10n_pipeline_test.dart`** fails the build if a listed language has
  no table, if the generated Dart is stale, or if a placeholder went missing.
- **The push worker** speaks the same tables: `logic.mjs` imports the
  generated JSON and never carries strings of its own.

## Where the language is chosen

- The welcome screen, once, at first launch: tapping a language switches the
  screen to it immediately. The sign-up sheet carries the same picker.
- Settings → Language, any time. "Follow phone" uses the device language when
  it is one of the sixteen, else English.
- The choice also guides the listener: the voice route receives it as the
  preferred language and checks it first when a guess is doubtful (Urdu vs
  Hindi, Ukrainian vs Russian, Malay vs Indonesian…).

## Adding a language

1. Copy `l10n/en.json` to `l10n/<code>.json` and localize every value.
2. Add the code and its native name to `supportedLanguages` (and to
   `rtlLanguages` if it reads right to left).
3. `python3 tool/gen_l10n.py` then `flutter test`.
