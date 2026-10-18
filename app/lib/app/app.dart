import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/domain/app_settings.dart';
import '../features/settings/presentation/settings_providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

/// Root widget: theme + router. No business logic.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themes = ref.watch(appThemesProvider);
    final reduceMotionSetting = ref.watch(
      settingsProvider.select((s) => s.motion == MotionPreference.reduced),
    );
    return MaterialApp.router(
      title: 'Notehaven',
      theme: themes.light,
      darkTheme: themes.dark,
      themeMode: ref.watch(themeModeProvider),
      localizationsDelegates: const [
        ...GlobalMaterialLocalizations.delegates,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: FlutterQuillLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
      // "Reduced" in settings behaves exactly like the OS reduce-motion flag.
      builder: (context, child) => reduceMotionSetting
          ? MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            )
          : child!,
    );
  }
}
