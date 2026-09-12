/// Turns a spoken sentence into task fields.
///
/// "call the pharmacy every day at 9 am"  → title "call the pharmacy",
/// daily, 09:00. Works for English and Arabic. Anything it does not
/// understand stays in the title, so the person can fix it on the sheet.
/// Pure Dart, unit-tested in test/voice_parser_test.dart.
library;

import '../models/task.dart';

class ParsedSpeech {
  const ParsedSpeech({
    required this.title,
    this.frequency,
    this.weekdays = const {},
    this.everyNDays,
    this.hour,
    this.minute,
    this.periodStart,
    this.periodDays,
  });

  final String title;
  final Frequency? frequency;
  final Set<int> weekdays;
  final int? everyNDays;
  final int? hour;
  final int? minute;

  /// A relative start such as "tomorrow".
  final DateTime? periodStart;

  /// "for two weeks" → 14.
  final int? periodDays;
}

const _arabicIndic = '٠١٢٣٤٥٦٧٨٩';

String _latinDigits(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    final i = _arabicIndic.indexOf(ch);
    b.write(i >= 0 ? i.toString() : ch);
  }
  return b.toString();
}


/// Dart/JS `\b` only knows ASCII word characters, so it never matches beside
/// an Arabic letter. Every pattern below is built through [_re], which swaps
/// `\b` for a Unicode-aware word boundary.
const _wb = r'(?:(?<=[\p{L}\p{N}_])(?![\p{L}\p{N}_])|(?<![\p{L}\p{N}_])(?=[\p{L}\p{N}_]))';
RegExp _re(String pattern) =>
    RegExp(pattern.replaceAll(r'\b', _wb), caseSensitive: false, unicode: true);

final _numberWords = <String, int>{
  'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6, 'seven': 7,
  'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11, 'twelve': 12,
  'a': 1, 'an': 1,
  'واحد': 1, 'واحدة': 1, 'اثنين': 2, 'اثنتين': 2, 'ثلاث': 3, 'ثلاثة': 3,
  'اربع': 4, 'أربع': 4, 'اربعة': 4, 'أربعة': 4, 'خمس': 5, 'خمسة': 5,
  'ست': 6, 'ستة': 6, 'سبع': 7, 'سبعة': 7, 'ثمان': 8, 'ثمانية': 8,
  'تسع': 9, 'تسعة': 9, 'عشر': 10, 'عشرة': 10,
};

int? _num(String? s) {
  if (s == null) return null;
  final t = s.trim();
  return int.tryParse(t) ?? _numberWords[t];
}

final _weekdayWords = <String, int>{
  'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4, 'friday': 5,
  'saturday': 6, 'sunday': 7,
  'الاثنين': 1, 'الإثنين': 1, 'الثلاثاء': 2, 'الاربعاء': 3, 'الأربعاء': 3,
  'الخميس': 4, 'الجمعة': 5, 'السبت': 6, 'الاحد': 7, 'الأحد': 7,
};

ParsedSpeech parseSpeech(String raw, {DateTime? now}) {
  final today = now ?? DateTime.now();
  var text = _latinDigits(raw).trim();
  Frequency? frequency;
  final weekdays = <int>{};
  int? everyN;
  int? hour;
  int? minute;
  DateTime? start;
  int? periodDays;

  String strip(RegExp re) {
    final m = re.firstMatch(text);
    if (m == null) return '';
    text = text.replaceRange(m.start, m.end, ' ');
    return m.group(0)!;
  }

  // ---- period: "for 2 weeks" / "لمدة أسبوعين" / "لمدة 3 أيام"
  final forRe = _re(r'\b(?:for|لمدة|لمده)\s+(\d+|[a-z]+|[؀-ۿ]+)?\s*(days?|weeks?|months?|يوم|أيام|ايام|يومين|اسبوع|أسبوع|اسابيع|أسابيع|اسبوعين|أسبوعين|شهر|شهرين|اشهر|أشهر)\b');
  final forM = forRe.firstMatch(text);
  if (forM != null) {
    final unit = forM.group(2)!;
    var n = _num(forM.group(1)) ?? 1;
    if (unit == 'يومين' || unit.contains('اسبوعين') || unit.contains('أسبوعين') || unit == 'شهرين') {
      n = 2;
    }
    if (unit.startsWith('day') || unit.contains('يوم') || unit.contains('يام')) {
      periodDays = n;
    } else if (unit.startsWith('week') || unit.contains('سبوع') || unit.contains('سابيع')) {
      periodDays = n * 7;
    } else {
      periodDays = n * 30;
    }
    strip(forRe);
  }

  // ---- frequency
  final dailyRe = _re(r'\b(every\s*day|everyday|daily|each\s*day|كل\s*يوم|يوميا|يومياً|يوميًا)\b');
  final weekdaysRe = _re(r'\b(every\s*weekday|on\s*weekdays|weekdays|أيام\s*العمل|ايام\s*العمل|أيام\s*الدوام|ايام\s*الدوام)\b');
  final everyNRe = _re(r'\bevery\s+(\d+|[a-z]+)\s+days?\b|\bكل\s+(\d+|[؀-ۿ]+)\s+(?:أيام|ايام)\b|\bكل\s+يومين\b');
  final weeklyRe = _re(r'\b(?:every\s+week|weekly|كل\s*أسبوع|كل\s*اسبوع|أسبوعيا|اسبوعيا|أسبوعياً|اسبوعياً)\b');
  final onDayRe = _re(r'\b(?:every|on|each|كل|يوم)?\s*(monday|tuesday|wednesday|thursday|friday|saturday|sunday|الاثنين|الإثنين|الثلاثاء|الاربعاء|الأربعاء|الخميس|الجمعة|السبت|الاحد|الأحد)s?\b');

  if (weekdaysRe.hasMatch(text)) {
    frequency = Frequency.weekdays;
    strip(weekdaysRe);
  } else if (dailyRe.hasMatch(text)) {
    frequency = Frequency.daily;
    strip(dailyRe);
  } else {
    final m = everyNRe.firstMatch(text);
    if (m != null) {
      final n = _num(m.group(1) ?? m.group(2)) ?? 2;
      frequency = n <= 1 ? Frequency.daily : Frequency.everyNDays;
      everyN = n;
      strip(everyNRe);
    }
  }
  var dm = onDayRe.firstMatch(text);
  while (dm != null) {
    final wd = _weekdayWords[dm.group(1)!.toLowerCase()];
    if (wd != null) weekdays.add(wd);
    strip(onDayRe);
    dm = onDayRe.firstMatch(text);
  }
  if (weekdays.isNotEmpty) {
    frequency = Frequency.weekly;
  } else if (weeklyRe.hasMatch(text)) {
    frequency = Frequency.weekly;
    strip(weeklyRe);
  }

  // ---- "tomorrow" / "غدا" / "today"
  final tomorrowRe = _re(r'\b(tomorrow|غدا|غداً|بكرة|بكرا|بكره)\b');
  final todayRe = _re(r'\b(today|اليوم)\b');
  if (tomorrowRe.hasMatch(text)) {
    start = DateTime(today.year, today.month, today.day + 1);
    frequency ??= Frequency.once;
    strip(tomorrowRe);
  } else if (todayRe.hasMatch(text)) {
    start = DateTime(today.year, today.month, today.day);
    frequency ??= Frequency.once;
    strip(todayRe);
  }

  // ---- time: "at 9", "at 9:30 pm", "at 21:15", "الساعة 9 مساء", "9 صباحا"
  final timeRe = _re(r'(?:\bat\b|\bالساعة\b|\bالساعه\b|\bعلى\s+الساعة\b)?\s*\b(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.|o.clock|صباحا|صباحاً|مساء|مساءً|الصبح|بالليل|ليلا|ليلاً|بعد الظهر|العصر|المغرب)?\b');
  // Prefer a match that is introduced by "at"/"الساعة" or carries am/pm.
  RegExpMatch? best;
  for (final m in timeRe.allMatches(text)) {
    final h = int.tryParse(m.group(1)!);
    if (h == null || h > 24) continue;
    final introduced = m.group(0)!.trimLeft().startsWith(_re(r'at\b|الساعة|الساعه|على'));
    final hasSuffix = m.group(3) != null;
    if (introduced || hasSuffix || m.group(2) != null) {
      best = m;
      break;
    }
  }
  if (best != null) {
    var h = int.parse(best.group(1)!);
    final mi = int.tryParse(best.group(2) ?? '0') ?? 0;
    final suffix = (best.group(3) ?? '').toLowerCase();
    final isPm = suffix.startsWith('p') || suffix.contains('مساء') || suffix.contains('ليل') || suffix.contains('بعد') || suffix.contains('العصر') || suffix.contains('المغرب');
    final isAm = suffix.startsWith('a') || suffix.contains('صباح') || suffix.contains('الصبح');
    if (isPm && h < 12) h += 12;
    if (isAm && h == 12) h = 0;
    if (!isPm && !isAm && h < 7 && h != 0) h += 12; // "at 5" → 17:00, a sensible default for a task
    if (h == 24) h = 0;
    hour = h;
    minute = mi.clamp(0, 59);
    text = text.replaceRange(best.start, best.end, ' ');
  }

  // ---- tidy the title
  var title = text
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(_re(r'^\s*(?:remind me to|remind me|reminder to|i need to|i have to|ذكرني أن|ذكرني ان|ذكرني|لازم|يجب أن|يجب ان)\s*'), '')
      .replaceAll(RegExp(r'[\s,،.]+$'), '')
      .trim();
  if (title.isNotEmpty) {
    title = title[0].toUpperCase() + title.substring(1);
  }

  return ParsedSpeech(
    title: title.isEmpty ? raw.trim() : title,
    frequency: frequency,
    weekdays: weekdays,
    everyNDays: everyN,
    hour: hour,
    minute: minute,
    periodStart: start,
    periodDays: periodDays,
  );
}
