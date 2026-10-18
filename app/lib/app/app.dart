import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme/app_theme.dart';

/// Root widget: theme + router. No business logic.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themes = ref.watch(appThemesProvider);
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
    );
  }
}
