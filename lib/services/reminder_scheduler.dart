import '../core/platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/strings.dart';
import '../models/task.dart';
import '../models/task_logic.dart';

/// What a tapped notification carries back into the app.
class ReminderPayload {
  const ReminderPayload({required this.taskId, required this.occurrenceKey, required this.shared});
  final String taskId;
  final String occurrenceKey;
  final bool shared;

  String encode() => '$taskId|$occurrenceKey|${shared ? 1 : 0}';

  static ReminderPayload? decode(String? s) {
    if (s == null) return null;
    final p = s.split('|');
    if (p.length != 3) return null;
    return ReminderPayload(taskId: p[0], occurrenceKey: p[1], shared: p[2] == '1');
  }
}

typedef ReminderTap = void Function(ReminderPayload payload, {required bool markDone});

/// Local, on-device reminders. Nothing here talks to a server: a shared task
/// is reminded on each member's phone from the copy that phone holds.
///
/// Design points that matter for the stores:
///  * iOS allows at most 64 pending local notifications per app, so
///    [syncAll] schedules the SOONEST occurrences first within a budget.
///  * Android exact alarms are optional (SCHEDULE_EXACT_ALARM, user-granted).
///    Without them the reminder is `inexactAllowWhileIdle`, which Android may
///    delay by a few minutes to save battery. USE_EXACT_ALARM and
///    full-screen intents are deliberately NOT used (Play policy).
class ReminderScheduler {
  ReminderScheduler(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const channelId = 'task_reminders_v1';
  static const actionDone = 'done';
  static const iosCategory = 'DONEBY_TASK';

  /// Budget of pending notifications. iOS hard-caps at 64; keep headroom.
  static int get budget => isIOS ? 58 : 220;

  static Future<void> initTimezone() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fall back to UTC-offset-less local; scheduling still works via TZDateTime.from.
    }
  }

  Future<void> init(L10n l, ReminderTap onTap) async {
    if (isWeb) return;
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Permission is asked in context (after the first task), not at launch.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              iosCategory,
              actions: [
                DarwinNotificationAction.plain(
                  actionDone,
                  l.actionDone,
                  options: {DarwinNotificationActionOption.foreground},
                ),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        final p = ReminderPayload.decode(r.payload);
        if (p == null) return;
        onTap(p, markDone: r.actionId == actionDone);
      },
    );
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(AndroidNotificationChannel(
      channelId,
      l.reminderChannel,
      description: l.reminderChannelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ));
  }

  /// A notification the user tapped while the app was closed.
  Future<ReminderPayload?> launchPayload() async {
    if (isWeb) return null;
    final d = await _plugin.getNotificationAppLaunchDetails();
    if (d?.didNotificationLaunchApp != true) return null;
    return ReminderPayload.decode(d!.notificationResponse?.payload);
  }

  Future<bool> permissionGranted() async {
    // Browsers cannot deliver scheduled reminders when the tab is closed; the
    // phone app owns reminders. Report "fine" so the web UI shows no warning.
    if (isWeb) return true;
    if (isAndroid) {
      final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await a?.areNotificationsEnabled() ?? false;
    }
    final i = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final opts = await i?.checkPermissions();
    return opts?.isEnabled ?? false;
  }

  Future<bool> requestPermission() async {
    if (isWeb) return true;
    if (isAndroid) {
      final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await a?.requestNotificationsPermission() ?? false;
    }
    final i = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await i?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  Future<bool> canScheduleExact() async {
    if (!isAndroid) return true;
    final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await a?.canScheduleExactNotifications() ?? false;
  }

  Future<bool> requestExact() async {
    if (!isAndroid) return true;
    final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await a?.requestExactAlarmsPermission() ?? false;
  }

  /// Rebuilds EVERY pending reminder from the current task list.
  /// Called on start, on resume, and after any change — cheap and idempotent,
  /// which is what keeps "done" and "reminded" from ever disagreeing.
  Future<void> syncAll(List<Task> tasks, L10n l, {DateTime? now}) async {
    if (isWeb) return; // reminders are the phone app's job (see permissionGranted)
    final t0 = now ?? DateTime.now();
    await _plugin.cancelAll();

    final exact = await canScheduleExact();
    final mode = exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;

    // Collect (moment, task, occurrence) triples, soonest first.
    final entries = <_Entry>[];
    for (final task in tasks) {
      if (task.archived) continue;
      final occurrences = upcomingOccurrences(task, t0, maxCount: 4, horizonDays: 45);
      for (var d = 0; d < occurrences.length; d++) {
        final due = occurrences[d];
        final moments = reminderMoments(task, due, t0);
        for (var i = 0; i < moments.length; i++) {
          entries.add(_Entry(task, due, d, i, moments[i]));
        }
      }
    }
    entries.sort((a, b) => a.at.compareTo(b.at));

    var scheduled = 0;
    for (final e in entries) {
      if (scheduled >= budget) break;
      final isNag = e.index > 0;
      final title = (isNag ? l.reminderNag : l.reminderTitle).fill({'title': e.task.title});
      final body = e.task.isShared
          ? '${l.kindShared} · ${e.task.ownerName}'
          : (e.task.note?.trim().isNotEmpty == true ? e.task.note!.trim() : l.tagline);
      final payload = ReminderPayload(
        taskId: e.task.id,
        occurrenceKey: occurrenceKey(e.due),
        shared: e.task.isShared,
      ).encode();
      try {
        await _plugin.zonedSchedule(
          id: notificationId(e.task.id, e.dayOrdinal, e.index),
          scheduledDate: tz.TZDateTime.from(e.at, tz.local),
          title: title,
          body: body,
          payload: payload,
          androidScheduleMode: mode,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channelId,
              l.reminderChannel,
              channelDescription: l.reminderChannelDesc,
              importance: Importance.max,
              priority: Priority.high,
              category: AndroidNotificationCategory.reminder,
              autoCancel: true,
              tag: e.task.id, // a newer nag replaces the older one in the shade
              actions: [
                AndroidNotificationAction(
                  actionDone,
                  l.actionDone,
                  showsUserInterface: true,
                  cancelNotification: true,
                ),
              ],
            ),
            iOS: DarwinNotificationDetails(
              categoryIdentifier: iosCategory,
              threadIdentifier: e.task.id,
              interruptionLevel: InterruptionLevel.timeSensitive,
              presentAlert: true,
              presentSound: true,
              presentBanner: true,
              presentList: true,
            ),
          ),
        );
        scheduled++;
      } catch (err) {
        debugPrint('schedule failed: $err');
      }
    }
  }

  /// Cancels whatever is still pending for one task (all occurrences).
  Future<void> cancelTask(String taskId) async {
    if (isWeb) return;
    for (var d = 0; d < 8; d++) {
      for (var i = 0; i < 64; i++) {
        await _plugin.cancel(id: notificationId(taskId, d, i));
      }
    }
  }
}

class _Entry {
  _Entry(this.task, this.due, this.dayOrdinal, this.index, this.at);
  final Task task;
  final DateTime due;
  final int dayOrdinal;
  final int index;
  final DateTime at;
}
