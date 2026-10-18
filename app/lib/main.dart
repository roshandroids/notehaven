import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'shared/crash/crash_log.dart';
import 'shared/licenses.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // First, so even a failure while opening the database is recorded.
  installCrashHandling(CrashLog());
  registerExtraLicenses();
  runApp(
    ProviderScope(overrides: await productionOverrides(), child: const App()),
  );
}
