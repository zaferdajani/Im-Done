import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../models/task.dart';
import '../cloud/cloud.dart';

/// What the server made of a recording: the words, the language (and
/// Arabic dialect) they were spoken in, and the task fields it read out of
/// them. Every field except [title] and [transcript] may be absent.
class Understanding {
  const Understanding({
    required this.title,
    required this.transcript,
    this.language,
    this.dialect,
    this.frequency,
    this.weekdays = const {},
    this.everyNDays,
    this.hour,
    this.minute,
    this.date,
    this.periodDays,
    this.note,
    this.importance,
    this.group,
    this.category,
    this.engine,
  });

  final String title;
  final String transcript;
  final String? language;
  final String? dialect;
  final Frequency? frequency;
  final Set<int> weekdays;
  final int? everyNDays;
  final int? hour;
  final int? minute;
  final DateTime? date;
  final int? periodDays;
  final String? note;
  final Importance? importance;
  final String? group;
  final String? category;
  final String? engine;

  static Understanding fromJson(Map<String, dynamic> j) {
    int? asInt(Object? v) => v is num ? v.toInt() : null;
    DateTime? date;
    final d = j['date'];
    if (d is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d)) {
      final p = d.split('-').map(int.parse).toList();
      date = DateTime(p[0], p[1], p[2]);
    }
    final f = j['frequency'];
    return Understanding(
      title: (j['title'] as String?)?.trim() ?? '',
      transcript: (j['transcript'] as String?)?.trim() ?? '',
      language: j['language'] as String?,
      dialect: j['dialect'] as String?,
      frequency: f is String && Frequency.values.any((x) => x.name == f) ? Frequency.values.byName(f) : null,
      weekdays: ((j['weekdays'] as List?) ?? const []).whereType<num>().map((e) => e.toInt()).where((d) => d >= 1 && d <= 7).toSet(),
      everyNDays: asInt(j['everyNDays']),
      hour: asInt(j['hour']),
      minute: asInt(j['minute']),
      date: date,
      periodDays: asInt(j['periodDays']),
      note: (j['note'] as String?)?.trim(),
      importance: Importance.values.where((i) => i.name == j['importance']).firstOrNull,
      group: (j['group'] as String?)?.trim().isEmpty ?? true ? null : (j['group'] as String).trim(),
      category: j['category'] as String?,
      engine: j['engine'] as String?,
    );
  }
}

/// Fills a draft from an [Understanding]. Anything the server did not say
/// keeps the draft's value, so the person always lands on a sensible sheet.
Task applyUnderstanding(Task draft, Understanding u) {
  final freq = u.frequency ?? draft.frequency;
  DateTime? start = u.date ?? draft.periodStart;
  DateTime? end = draft.periodEnd;
  if (u.periodDays != null) {
    start ??= DateTime.now();
    start = DateTime(start.year, start.month, start.day);
    end = start.add(Duration(days: u.periodDays! - 1));
  }
  if (freq == Frequency.once && start == null) {
    // A one-off with no date is today.
    final n = DateTime.now();
    start = DateTime(n.year, n.month, n.day);
  }
  return draft.copyWith(
    title: u.title.isEmpty ? u.transcript : u.title,
    frequency: freq,
    weekdays: u.weekdays.isNotEmpty ? u.weekdays : draft.weekdays,
    everyNDays: u.everyNDays ?? draft.everyNDays,
    hour: u.hour ?? draft.hour,
    minute: u.hour == null ? draft.minute : (u.minute ?? 0),
    periodStart: start,
    periodEnd: end,
    note: (u.note?.isNotEmpty ?? false) ? u.note : draft.note,
    importance: u.importance ?? draft.importance,
    group: u.group ?? draft.group,
    category: u.category ?? draft.category,
    language: u.language,
    dialect: u.dialect,
    transcript: u.transcript.isEmpty ? null : u.transcript,
  );
}

class UnderstandingException implements Exception {
  UnderstandingException(this.code, [this.detail]);
  final String code; // 'offline' | 'unconfigured' | 'nothing_heard' | 'failed'
  final String? detail;
  @override
  String toString() => 'UnderstandingException($code${detail == null ? '' : ': $detail'})';
}

/// Sends the recording to the worker and reads its answer.
class UnderstandingService {
  UnderstandingService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  bool get configured => Cloud.pushEndpoint.isNotEmpty;

  Future<Understanding> understand(Uint8List wav, {required String idToken, required String uiLanguage}) async {
    if (!configured) throw UnderstandingException('unconfigured');
    final now = DateTime.now();
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('${Cloud.pushEndpoint}/transcribe'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'audio/wav',
              'X-Now': now.toIso8601String().split('.').first,
              'X-Weekday': weekdays[now.weekday - 1],
              'X-Ui-Language': uiLanguage,
              // The person's own language, so the listener checks it first
              // when a guess is doubtful (Urdu vs Hindi, Ukrainian vs Russian).
              'X-Preferred-Language': uiLanguage,
            },
            body: wav,
          )
          .timeout(const Duration(seconds: 40));
    } catch (e) {
      throw UnderstandingException('offline', e.toString());
    }
    if (res.statusCode == 503) throw UnderstandingException('unconfigured');
    if (res.statusCode == 422) throw UnderstandingException('nothing_heard');
    if (res.statusCode != 200) throw UnderstandingException('failed', 'HTTP ${res.statusCode} ${res.body}');
    final j = Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)) as Map);
    final u = Understanding.fromJson(j);
    if (u.title.isEmpty && u.transcript.isEmpty) throw UnderstandingException('nothing_heard');
    return u;
  }
}
