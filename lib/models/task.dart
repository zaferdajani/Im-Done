import 'dart:convert';

/// Who the task belongs to.
enum TaskKind { personal, shared }

/// How often the task recurs.
enum Frequency { once, daily, weekdays, weekly, everyNDays }

/// How much the task matters. Medium is the default; high sorts first on
/// the day's list and is marked in red, low in grey.
enum Importance { high, medium, low }

/// A completion of one occurrence (one calendar day) of a task.
///
/// For a shared task the completion is *claimed* by a member and must be
/// *confirmed* by the creator before it counts. For a personal task the
/// creator and the member are the same person, so it counts immediately.
class Completion {
  const Completion({
    required this.byUid,
    required this.byName,
    required this.at,
    this.confirmedByUid,
    this.confirmedAt,
  });

  final String byUid;
  final String byName;
  final DateTime at;
  final String? confirmedByUid;
  final DateTime? confirmedAt;

  bool get confirmed => confirmedAt != null;

  Completion copyWith({String? confirmedByUid, DateTime? confirmedAt}) =>
      Completion(
        byUid: byUid,
        byName: byName,
        at: at,
        confirmedByUid: confirmedByUid ?? this.confirmedByUid,
        confirmedAt: confirmedAt ?? this.confirmedAt,
      );

  Map<String, dynamic> toJson() => {
        'byUid': byUid,
        'byName': byName,
        'at': at.toUtc().toIso8601String(),
        if (confirmedByUid != null) 'confirmedByUid': confirmedByUid,
        if (confirmedAt != null)
          'confirmedAt': confirmedAt!.toUtc().toIso8601String(),
      };

  static Completion fromJson(Map<String, dynamic> j) => Completion(
        byUid: j['byUid'] as String,
        byName: (j['byName'] as String?) ?? '',
        at: DateTime.parse(j['at'] as String).toLocal(),
        confirmedByUid: j['confirmedByUid'] as String?,
        confirmedAt: j['confirmedAt'] == null
            ? null
            : DateTime.parse(j['confirmedAt'] as String).toLocal(),
      );
}

class TaskMember {
  const TaskMember({required this.uid, required this.name, required this.joinedAt});
  final String uid;
  final String name;
  final DateTime joinedAt;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'joinedAt': joinedAt.toUtc().toIso8601String(),
      };

  static TaskMember fromJson(Map<String, dynamic> j) => TaskMember(
        uid: j['uid'] as String,
        name: (j['name'] as String?) ?? '',
        joinedAt: DateTime.parse(j['joinedAt'] as String).toLocal(),
      );
}

/// The identity used for personal tasks that never leave the device.
const String localOwnerUid = 'me';

class Task {
  Task({
    required this.id,
    required this.title,
    required this.kind,
    required this.ownerUid,
    required this.ownerName,
    required this.frequency,
    required this.hour,
    required this.minute,
    required this.createdAt,
    this.weekdays = const {},
    this.everyNDays = 2,
    this.periodStart,
    this.periodEnd,
    this.nagEveryMinutes = 10,
    this.nagRepeats = 6,
    this.note,
    this.members = const [],
    this.completions = const {},
    this.inviteCode,
    this.archived = false,
    this.language,
    this.dialect,
    this.transcript,
    this.importance = Importance.medium,
    this.group,
    this.category,
  });

  final String id;
  final String title;
  final TaskKind kind;
  final String ownerUid;
  final String ownerName;
  final Frequency frequency;

  /// ISO weekdays 1 (Monday) .. 7 (Sunday). Used when [frequency] is weekly.
  final Set<int> weekdays;

  /// Interval in days when [frequency] is [Frequency.everyNDays].
  final int everyNDays;

  /// Time of day the task is due.
  final int hour;
  final int minute;

  /// Optional period. For [Frequency.once] the start date is THE date.
  final DateTime? periodStart;
  final DateTime? periodEnd;

  /// Reminder keeps repeating every N minutes, up to [nagRepeats] times,
  /// until the occurrence is marked done. 0 = remind once only.
  final int nagEveryMinutes;
  final int nagRepeats;

  final String? note;
  final DateTime createdAt;
  final List<TaskMember> members;

  /// Keyed by occurrence key (yyyy-MM-dd of the due date).
  final Map<String, Completion> completions;

  final String? inviteCode;
  final bool archived;

  /// Language the task was spoken in (ISO 639-1), the Arabic variety when
  /// known, and the words as heard. Null for typed tasks.
  final String? language;
  final String? dialect;
  final String? transcript;

  final Importance importance;

  /// A free name that gathers tasks ("Home", "Work", "Kids"). Null = none.
  final String? group;

  /// One of the keys in models/categories.dart, or null.
  final String? category;

  bool get isShared => kind == TaskKind.shared;

  Task copyWith({
    String? title,
    TaskKind? kind,
    String? ownerUid,
    String? ownerName,
    Frequency? frequency,
    Set<int>? weekdays,
    int? everyNDays,
    int? hour,
    int? minute,
    DateTime? periodStart,
    bool clearPeriodStart = false,
    DateTime? periodEnd,
    bool clearPeriodEnd = false,
    int? nagEveryMinutes,
    int? nagRepeats,
    String? note,
    List<TaskMember>? members,
    Map<String, Completion>? completions,
    String? inviteCode,
    bool? archived,
    String? language,
    String? dialect,
    String? transcript,
    Importance? importance,
    String? group,
    bool clearGroup = false,
    String? category,
    bool clearCategory = false,
  }) =>
      Task(
        id: id,
        title: title ?? this.title,
        kind: kind ?? this.kind,
        ownerUid: ownerUid ?? this.ownerUid,
        ownerName: ownerName ?? this.ownerName,
        frequency: frequency ?? this.frequency,
        weekdays: weekdays ?? this.weekdays,
        everyNDays: everyNDays ?? this.everyNDays,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        periodStart: clearPeriodStart ? null : (periodStart ?? this.periodStart),
        periodEnd: clearPeriodEnd ? null : (periodEnd ?? this.periodEnd),
        nagEveryMinutes: nagEveryMinutes ?? this.nagEveryMinutes,
        nagRepeats: nagRepeats ?? this.nagRepeats,
        note: note ?? this.note,
        createdAt: createdAt,
        members: members ?? this.members,
        completions: completions ?? this.completions,
        inviteCode: inviteCode ?? this.inviteCode,
        archived: archived ?? this.archived,
        language: language ?? this.language,
        dialect: dialect ?? this.dialect,
        transcript: transcript ?? this.transcript,
        importance: importance ?? this.importance,
        group: clearGroup ? null : (group ?? this.group),
        category: clearCategory ? null : (category ?? this.category),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'kind': kind.name,
        'ownerUid': ownerUid,
        'ownerName': ownerName,
        'frequency': frequency.name,
        'weekdays': weekdays.toList()..sort(),
        'everyNDays': everyNDays,
        'hour': hour,
        'minute': minute,
        'periodStart': _dateOnly(periodStart),
        'periodEnd': _dateOnly(periodEnd),
        'nagEveryMinutes': nagEveryMinutes,
        'nagRepeats': nagRepeats,
        'note': note,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'members': members.map((m) => m.toJson()).toList(),
        'memberUids': members.map((m) => m.uid).toList(),
        'completions': completions.map((k, v) => MapEntry(k, v.toJson())),
        'inviteCode': inviteCode,
        'archived': archived,
        if (language != null) 'language': language,
        if (dialect != null) 'dialect': dialect,
        if (transcript != null) 'transcript': transcript,
        'importance': importance.name,
        if (group != null) 'group': group,
        if (category != null) 'category': category,
      };

  static Task fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        kind: TaskKind.values.byName((j['kind'] as String?) ?? 'personal'),
        ownerUid: (j['ownerUid'] as String?) ?? localOwnerUid,
        ownerName: (j['ownerName'] as String?) ?? '',
        frequency:
            Frequency.values.byName((j['frequency'] as String?) ?? 'daily'),
        weekdays: ((j['weekdays'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toSet(),
        everyNDays: ((j['everyNDays'] as num?) ?? 2).toInt(),
        hour: ((j['hour'] as num?) ?? 9).toInt(),
        minute: ((j['minute'] as num?) ?? 0).toInt(),
        periodStart: _parseDate(j['periodStart']),
        periodEnd: _parseDate(j['periodEnd']),
        nagEveryMinutes: ((j['nagEveryMinutes'] as num?) ?? 10).toInt(),
        nagRepeats: ((j['nagRepeats'] as num?) ?? 6).toInt(),
        note: j['note'] as String?,
        createdAt: j['createdAt'] == null
            ? DateTime.now()
            : DateTime.parse(j['createdAt'] as String).toLocal(),
        members: ((j['members'] as List?) ?? const [])
            .map((e) => TaskMember.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        completions: ((j['completions'] as Map?) ?? const {}).map(
          (k, v) => MapEntry(
            k as String,
            Completion.fromJson(Map<String, dynamic>.from(v as Map)),
          ),
        ),
        inviteCode: j['inviteCode'] as String?,
        archived: (j['archived'] as bool?) ?? false,
        language: j['language'] as String?,
        dialect: j['dialect'] as String?,
        transcript: j['transcript'] as String?,
        importance: Importance.values.where((i) => i.name == j['importance']).firstOrNull ?? Importance.medium,
        group: (j['group'] as String?)?.trim().isEmpty ?? true ? null : (j['group'] as String).trim(),
        category: j['category'] as String?,
      );

  String encode() => jsonEncode(toJson());
  static Task decode(String s) =>
      fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map));

  static String? _dateOnly(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(Object? v) {
    if (v == null) return null;
    final s = v as String;
    final parts = s.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }
}
