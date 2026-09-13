import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imdone/models/languages.dart';
import 'package:imdone/models/task.dart';
import 'package:imdone/services/voice/understanding_service.dart';
import 'package:imdone/services/voice/wav.dart';

Task draft() => Task(
      id: 't', title: '', kind: TaskKind.personal, ownerUid: localOwnerUid, ownerName: 'me',
      frequency: Frequency.daily, hour: 9, minute: 0, createdAt: DateTime(2026, 9, 13),
    );

void main() {
  test('wav header describes the samples exactly', () {
    final pcm = List<int>.filled(3200, 0); // 0.1 s of 16 kHz mono
    final wav = wavFromPcm16(pcm);
    expect(wav.length, 44 + 3200);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    final bd = ByteData.sublistView(wav);
    expect(bd.getUint32(24, Endian.little), 16000);
    expect(bd.getUint16(22, Endian.little), 1);
    expect(bd.getUint16(34, Endian.little), 16);
    expect(bd.getUint32(40, Endian.little), 3200);
    expect(pcm16Seconds(3200), closeTo(0.1, 1e-9));
  });

  test('an arabic answer fills the draft and keeps the dialect', () {
    final u = Understanding.fromJson({
      'title': 'اتصل بالصيدلية', 'transcript': 'اتصل بالصيدلية كل يوم الساعة خمسة ونص',
      'language': 'ar', 'dialect': 'jordanian', 'frequency': 'daily', 'hour': 17, 'minute': 30,
    });
    final t = applyUnderstanding(draft(), u);
    expect(t.title, 'اتصل بالصيدلية');
    expect(t.frequency, Frequency.daily);
    expect(t.hour, 17);
    expect(t.minute, 30);
    expect(t.language, 'ar');
    expect(t.dialect, 'jordanian');
    expect(t.transcript, contains('الصيدلية'));
    expect(languageLabel(t.language, t.dialect, 'en'), 'Arabic · Jordanian');
    expect(languageLabel(t.language, t.dialect, 'ar'), 'العربية · أردني');
  });

  test('a one-off with a date and a period becomes a dated span', () {
    final u = Understanding.fromJson({'title': 'gym', 'transcript': 'gym', 'frequency': 'weekly', 'weekdays': [1, 3], 'date': '2026-09-14', 'periodDays': 14, 'hour': 7});
    final t = applyUnderstanding(draft(), u);
    expect(t.frequency, Frequency.weekly);
    expect(t.weekdays, {1, 3});
    expect(t.periodStart, DateTime(2026, 9, 14));
    expect(t.periodEnd, DateTime(2026, 9, 27));
    expect(t.hour, 7);
    expect(t.minute, 0);
  });

  test('what the server did not say keeps the draft defaults', () {
    final u = Understanding.fromJson({'title': 'buy milk', 'transcript': 'buy milk', 'language': 'en', 'frequency': 'once'});
    final t = applyUnderstanding(draft(), u);
    expect(t.title, 'buy milk');
    expect(t.frequency, Frequency.once);
    expect(t.hour, 9);
    expect(t.periodStart, isNotNull); // a one-off with no date is today
    expect(t.dialect, isNull);
    expect(t.note, isNull);
  });

  test('an empty title falls back to the words heard; unknown codes still label', () {
    final u = Understanding.fromJson({'title': '', 'transcript': 'regar las plantas', 'language': 'es'});
    expect(applyUnderstanding(draft(), u).title, 'regar las plantas');
    expect(languageLabel('es', null, 'en'), 'Spanish');
    expect(languageLabel('xx', null, 'en'), 'XX');
    expect(languageLabel(null, null, 'en'), isNull);
    expect(languageLabel('en', 'egyptian', 'en'), 'English');
  });

  test('language and transcript survive the json round trip', () {
    final t = draft().copyWith(title: 'x', language: 'ur', transcript: 'x y');
    final back = Task.decode(t.encode());
    expect(back.language, 'ur');
    expect(back.dialect, isNull);
    expect(back.transcript, 'x y');
  });

  test('importance is medium unless said otherwise, and survives storage', () {
    expect(draft().importance, Importance.medium);
    expect(applyUnderstanding(draft(), Understanding.fromJson({'title': 'x', 'transcript': 'x'})).importance, Importance.medium);
    expect(applyUnderstanding(draft(), Understanding.fromJson({'title': 'x', 'transcript': 'x', 'importance': 'high'})).importance, Importance.high);
    expect(Task.decode(draft().copyWith(title: 'x', importance: Importance.low).encode()).importance, Importance.low);
    expect(Task.fromJson({'id': 'a', 'title': 'old'}).importance, Importance.medium);
  });

  test('a group is kept from speech, stored, and cleared cleanly', () {
    final u = Understanding.fromJson({'title': 'buy milk', 'transcript': 'buy milk for the house', 'group': 'Home'});
    final t = applyUnderstanding(draft(), u);
    expect(t.group, 'Home');
    expect(Task.decode(t.encode()).group, 'Home');
    expect(t.copyWith(clearGroup: true).group, isNull);
    expect(Task.fromJson({'id': 'a', 'title': 'old', 'group': '  '}).group, isNull);
  });

  test('a category from speech is kept only when it is one of ours', () {
    final t = applyUnderstanding(draft(), Understanding.fromJson({'title': 'take the pills', 'transcript': 'take the pills', 'category': 'health'}));
    expect(t.category, 'health');
    expect(Task.decode(t.encode()).category, 'health');
    expect(t.copyWith(clearCategory: true).category, isNull);
  });
}
