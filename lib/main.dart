import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'l10n/strings.dart';
import 'state/bootstrap.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  final boot = await AppBootstrap.create();
  final code = boot.settings.languageCode ??
      (WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'ar' ? 'ar' : 'en');
  await boot.scheduler.init(
    L10n.forCode(code),
    (p, {required markDone}) => ReminderTaps.instance.add(p, markDone: markDone),
  );
  runApp(
    ProviderScope(
      overrides: [bootstrapProvider.overrideWithValue(boot)],
      child: const DonebyApp(),
    ),
  );
}
