import 'package:flutter_test/flutter_test.dart';
import 'package:doneby/models/task.dart';
import 'package:doneby/services/voice_parser.dart';

void main() {
  final now = DateTime(2026, 9, 12, 8, 0);

  test('english daily with time', () {
    final p = parseSpeech('remind me to call the pharmacy every day at 9 am', now: now);
    expect(p.title, 'Call the pharmacy');
    expect(p.frequency, Frequency.daily);
    expect(p.hour, 9);
    expect(p.minute, 0);
  });

  test('pm time and weekly day', () {
    final p = parseSpeech('take out the bins every monday at 7:30 pm', now: now);
    expect(p.frequency, Frequency.weekly);
    expect(p.weekdays, {1});
    expect(p.hour, 19);
    expect(p.minute, 30);
    expect(p.title, 'Take out the bins');
  });

  test('every N days and a period', () {
    final p = parseSpeech('water the plants every 3 days for two weeks', now: now);
    expect(p.frequency, Frequency.everyNDays);
    expect(p.everyNDays, 3);
    expect(p.periodDays, 14);
    expect(p.title, 'Water the plants');
  });

  test('tomorrow is a one-off', () {
    final p = parseSpeech('pay the electricity bill tomorrow at 5', now: now);
    expect(p.frequency, Frequency.once);
    expect(p.periodStart, DateTime(2026, 9, 13));
    expect(p.hour, 17, reason: 'a bare "at 5" for a task means the afternoon');
  });

  test('arabic daily with evening time', () {
    final p = parseSpeech('ذكرني أن أشرب الدواء كل يوم الساعة ٩ مساء', now: now);
    expect(p.frequency, Frequency.daily);
    expect(p.hour, 21);
    expect(p.title, 'أشرب الدواء');
  });

  test('arabic weekday and period', () {
    final p = parseSpeech('اتصل بأمي كل الجمعة الساعة 6 مساء لمدة شهر', now: now);
    expect(p.frequency, Frequency.weekly);
    expect(p.weekdays, {5});
    expect(p.hour, 18);
    expect(p.periodDays, 30);
    expect(p.title, 'اتصل بأمي');
  });

  test('nothing understood keeps the sentence', () {
    final p = parseSpeech('buy milk', now: now);
    expect(p.title, 'Buy milk');
    expect(p.frequency, isNull);
    expect(p.hour, isNull);
  });

  test('a number inside the title is not a time', () {
    final p = parseSpeech('order 20 boxes of gloves', now: now);
    expect(p.hour, isNull);
    expect(p.title, 'Order 20 boxes of gloves');
  });
}
