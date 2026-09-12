import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'l10n/strings.dart';
import 'services/reminder_scheduler.dart';
import 'state/providers.dart';
import 'ui/home_screen.dart';
import 'ui/add_person_screen.dart';
import 'ui/invite_landing_screen.dart';
import 'ui/task_detail_screen.dart';

/// Notification taps arrive here from the plugin callback registered in main().
class ReminderTaps {
  ReminderTaps._();
  static final instance = ReminderTaps._();
  final controller = StreamController<(ReminderPayload, bool)>.broadcast();
  void add(ReminderPayload p, {required bool markDone}) => controller.add((p, markDone));
}

class ImDoneApp extends ConsumerStatefulWidget {
  const ImDoneApp({super.key});
  @override
  ConsumerState<ImDoneApp> createState() => _ImDoneAppState();
}

class _ImDoneAppState extends ConsumerState<ImDoneApp> with WidgetsBindingObserver {
  final _nav = GlobalKey<NavigatorState>();
  Timer? _syncDebounce;
  StreamSubscription? _tapSub;
  StreamSubscription? _fcmSub;
  String? _pushRegisteredFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tapSub = ReminderTaps.instance.controller.stream.listen(_onReminderTap);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _scheduleSync();
      final launch = await ref.read(bootstrapProvider).scheduler.launchPayload();
      if (launch != null) _onReminderTap((launch, false));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncDebounce?.cancel();
    _tapSub?.cancel();
    _fcmSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(notificationsEnabledProvider);
      ref.invalidate(exactAlarmsProvider);
      _scheduleSync();
    }
  }

  /// Re-derive every pending reminder from the task list, debounced.
  void _scheduleSync() {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 400), () {
      final b = ref.read(bootstrapProvider);
      b.scheduler.syncAll(ref.read(allTasksProvider), ref.read(l10nProvider));
    });
  }

  Future<void> _onReminderTap((ReminderPayload, bool) e) async {
    final (p, markDone) = e;
    if (markDone) await ref.read(taskActionsProvider).markDoneById(p.taskId, p.occurrenceKey);
    _nav.currentState?.push(MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: p.taskId)));
  }

  /// An invite link arrived (deep link on the phone, or ?join= on the web):
  /// show the landing screen, which signs the person in and joins.
  void _onInvite(String code) {
    _nav.currentState?.push(MaterialPageRoute(builder: (_) => InviteLandingScreen(code: code)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(allTasksProvider, (_, _) => _scheduleSync());
    ref.listen(languageCodeProvider, (_, code) {
      // Re-register the notification action label in the new language.
      ref.read(bootstrapProvider).scheduler.init(L10n.forCode(code), (p, {required markDone}) => ReminderTaps.instance.add(p, markDone: markDone));
      _scheduleSync();
    });
    ref.listen(incomingInviteProvider, (_, next) {
      final code = next.value;
      if (code != null) _onInvite(code);
    });
    ref.listen(incomingPersonCodeProvider, (_, next) {
      final code = next.value;
      if (code != null) _nav.currentState?.push(MaterialPageRoute(builder: (_) => AddPersonScreen(code: code)));
    });
    ref.listen(authUserProvider, (_, next) {
      final user = next.value;
      final b = ref.read(bootstrapProvider);
      if (user != null && _pushRegisteredFor != user.uid && b.cloudAvailable) {
        _pushRegisteredFor = user.uid;
        b.push.register(user.uid, languageCode: ref.read(languageCodeProvider), displayName: ref.read(myNameProvider));
        _fcmSub ??= FirebaseMessaging.onMessage.listen((m) {
          // Firestore already streams the change; the push is only a heads-up.
          final n = m.notification;
          final c = _nav.currentContext;
          if (n != null && c != null && c.mounted) {
            ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('${n.title ?? ''} ${n.body ?? ''}'.trim())));
          }
        });
      }
      if (user == null) _pushRegisteredFor = null;
    });

    final code = ref.watch(languageCodeProvider);
    return MaterialApp(
      navigatorKey: _nav,
      title: "I'm Done",
      debugShowCheckedModeBanner: false,
      theme: ImDoneTheme.light(),
      darkTheme: ImDoneTheme.dark(),
      locale: Locale(code),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeScreen(),
    );
  }
}
