import { test } from 'node:test';
import assert from 'node:assert/strict';
import { ARABIC_DIALECTS, LANGUAGES, audioAcceptable, buildSystemPrompt, languageCode, parseUnderstanding } from '../src/understand.mjs';

test('whisper language names and codes both map to codes', () => {
  assert.equal(languageCode('arabic'), 'ar');
  assert.equal(languageCode('Arabic'), 'ar');
  assert.equal(languageCode('en'), 'en');
  assert.equal(languageCode('mandarin'), 'zh');
  assert.equal(languageCode('klingon'), null);
  assert.equal(languageCode(''), null);
});

test('a full answer is read field by field', () => {
  const p = parseUnderstanding(
    JSON.stringify({ title: 'اتصل بالصيدلية', language: 'ar', dialect: 'jordanian', frequency: 'daily', hour: 17, minute: 30, date: '2026-09-14', periodDays: 14, note: 'ask about the price' }),
    'اتصل بالصيدلية كل يوم الساعة خمسة ونص المسا', 'ar');
  assert.equal(p.title, 'اتصل بالصيدلية');
  assert.equal(p.language, 'ar');
  assert.equal(p.dialect, 'jordanian');
  assert.equal(p.frequency, 'daily');
  assert.equal(p.hour, 17);
  assert.equal(p.minute, 30);
  assert.equal(p.date, '2026-09-14');
  assert.equal(p.periodDays, 14);
  assert.equal(p.note, 'ask about the price');
  assert.equal(p.transcript, 'اتصل بالصيدلية كل يوم الساعة خمسة ونص المسا');
});

test('garbage from the model still yields a task from the transcript', () => {
  const p = parseUnderstanding('I cannot help with that', 'water the plants', 'en');
  assert.equal(p.title, 'water the plants');
  assert.equal(p.language, 'en');
  assert.equal(p.frequency, 'once');
  assert.equal(p.hour, null);
  assert.equal(p.minute, null);
  assert.deepEqual(p.weekdays, []);
});

test('json wrapped in prose is still found', () => {
  const p = parseUnderstanding('Sure! ```json\n{"title":"gym","frequency":"weekly","weekdays":[1,3,5,3,9]}\n```', 'gym mon wed fri', 'en');
  assert.equal(p.title, 'gym');
  assert.equal(p.frequency, 'weekly');
  assert.deepEqual(p.weekdays, [1, 3, 5]);
});

test('invalid schedule shapes degrade instead of inventing', () => {
  assert.equal(parseUnderstanding('{"title":"x","frequency":"weekly"}', 'x', 'en').frequency, 'once');
  const e = parseUnderstanding('{"title":"x","frequency":"everyNDays"}', 'x', 'en');
  assert.equal(e.frequency, 'daily');
  assert.equal(e.everyNDays, null);
  const d = parseUnderstanding('{"title":"x","frequency":"daily","everyNDays":3,"weekdays":[2]}', 'x', 'en');
  assert.equal(d.everyNDays, null);
  assert.deepEqual(d.weekdays, []);
  assert.equal(parseUnderstanding('{"title":"x","hour":25}', 'x', 'en').hour, null);
  assert.equal(parseUnderstanding('{"title":"x","hour":9}', 'x', 'en').minute, 0);
  assert.equal(parseUnderstanding('{"title":"x","date":"tomorrow"}', 'x', 'en').date, null);
  assert.equal(parseUnderstanding('{"title":"x","frequency":"hourly"}', 'x', 'en').frequency, 'once');
});

test('a dialect is only kept for arabic and only from the list', () => {
  assert.equal(parseUnderstanding('{"title":"x","language":"en","dialect":"egyptian"}', 'x', 'en').dialect, null);
  assert.equal(parseUnderstanding('{"title":"x","language":"ar","dialect":"martian"}', 'x', 'ar').dialect, null);
  assert.equal(parseUnderstanding('{"title":"x","language":"ar","dialect":"moroccan"}', 'x', 'ar').dialect, 'moroccan');
  assert.equal(parseUnderstanding('{"title":"x","language":"ar"}', 'x', 'ar').dialect, null);
});

test('the language falls back to what the recogniser heard', () => {
  assert.equal(parseUnderstanding('{"title":"x"}', 'x', 'ja').language, 'ja');
  assert.equal(parseUnderstanding('{"title":"x","language":"English"}', 'x', 'ja').language, 'en');
});

test('the prompt names every language and dialect the product shows', () => {
  const s = buildSystemPrompt({ now: '2026-09-13T10:00', weekday: 'Sunday', uiLanguage: 'ar' });
  for (const code of Object.keys(LANGUAGES)) assert.ok(s.includes(code), code);
  for (const d of ARABIC_DIALECTS) assert.ok(s.includes(d), d);
  assert.ok(s.includes('Sunday'));
  assert.ok(s.includes('Do not translate'));
});

test('audio bounds', () => {
  assert.equal(audioAcceptable(0, 'audio/wav').ok, false);
  assert.equal(audioAcceptable(500 * 1024, 'audio/wav').ok, true);
  assert.equal(audioAcceptable(500 * 1024, 'audio/webm;codecs=opus').ok, true);
  assert.equal(audioAcceptable(9 * 1024 * 1024, 'audio/wav').ok, false);
  assert.equal(audioAcceptable(500 * 1024, 'text/html').ok, false);
});
