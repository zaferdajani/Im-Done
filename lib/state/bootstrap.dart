import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/task.dart';
import '../services/cloud/auth_service.dart';
import '../services/cloud/cloud.dart';
import '../services/cloud/cloud_tasks.dart';
import '../services/cloud/push_service.dart';
import '../services/deep_links.dart';
import '../services/local_store.dart';
import '../services/reminder_scheduler.dart';
import '../services/settings_store.dart';
import '../services/speech_service.dart';

/// Everything that must exist before the first frame, built once in main().
class AppBootstrap {
  AppBootstrap({
    required this.settings,
    required this.settingsStore,
    required this.localStore,
    required this.initialTasks,
    required this.scheduler,
    required this.speech,
    required this.auth,
    required this.cloudTasks,
    required this.push,
    required this.deepLinks,
  });

  final AppSettings settings;
  final SettingsStore settingsStore;
  final LocalStore localStore;
  final List<Task> initialTasks;
  final ReminderScheduler scheduler;
  final SpeechService speech;
  final AuthService auth;
  final CloudTasks cloudTasks;
  final PushService push;
  final DeepLinks deepLinks;

  bool get cloudAvailable => Cloud.available;

  static Future<AppBootstrap> create() async {
    await ReminderScheduler.initTimezone();
    await Cloud.init();
    final settingsStore = SettingsStore();
    final settings = await settingsStore.read();
    final localStore = await LocalStore.open();
    final tasks = await localStore.readAll();
    return AppBootstrap(
      settings: settings,
      settingsStore: settingsStore,
      localStore: localStore,
      initialTasks: tasks,
      scheduler: ReminderScheduler(FlutterLocalNotificationsPlugin()),
      speech: SpeechService(),
      auth: AuthService(),
      cloudTasks: CloudTasks(),
      push: PushService(),
      deepLinks: DeepLinks(),
    );
  }
}
