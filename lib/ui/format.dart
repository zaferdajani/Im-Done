import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/strings.dart';
import '../models/task.dart';

String formatTime(BuildContext context, int hour, int minute) => MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: hour, minute: minute),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

String formatDate(String lang, DateTime d) {
  try {
    return DateFormat.MMMEd(lang).format(d);
  } catch (_) {
    return DateFormat.MMMEd('en').format(d);
  }
}

String formatDateShort(String lang, DateTime d) {
  try {
    return DateFormat.MMMd(lang).format(d);
  } catch (_) {
    return DateFormat.MMMd('en').format(d);
  }
}

String frequencySummary(L10n l, String lang, Task t) {
  String base;
  switch (t.frequency) {
    case Frequency.once:
      base = t.periodStart == null ? l.freqSummaryOnce : formatDate(lang, t.periodStart!);
    case Frequency.daily:
      base = l.freqSummaryDaily;
    case Frequency.weekdays:
      base = l.freqSummaryWeekdays;
    case Frequency.weekly:
      final days = (t.weekdays.toList()..sort()).map((d) => l.weekdayShort[d - 1]).join(lang == 'ar' ? '، ' : ', ');
      base = days.isEmpty ? l.freqWeekly : l.freqSummaryWeekly.fill({'days': days});
    case Frequency.everyNDays:
      base = l.freqSummaryEveryN.fill({'n': t.everyNDays});
  }
  if (t.frequency != Frequency.once && t.periodEnd != null) {
    base = '$base · ${l.untilDate.fill({'date': formatDateShort(lang, t.periodEnd!)})}';
  }
  return base;
}
