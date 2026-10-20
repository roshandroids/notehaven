import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/domain/app_settings.dart';
import '../features/settings/presentation/settings_providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import '../l10n/l10n.dart';

/// Root widget: theme + router. No business logic.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themes = ref.watch(appThemesProvider);
    final reduceMotionSetting = ref.watch(
      settingsProvider.select((s) => s.motion == MotionPreference.reduced),
    );
    final textScale = ref.watch(settingsProvider.select((s) => s.textScale));
    final localeCode = ref.watch(settingsProvider.select((s) => s.localeCode));
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      locale: localeCode == null ? null : Locale(localeCode),
      theme: themes.light,
      darkTheme: themes.dark,
      themeMode: ref.watch(themeModeProvider),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
      // "Reduced" in settings behaves exactly like the OS reduce-motion flag.
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        // Status bar icons must contrast with the page (Android: icon
        // brightness; iOS: the bar's own brightness, so inverted).
        final body = AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            statusBarBrightness: dark ? Brightness.dark : Brightness.light,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            excludeFromSemantics: true,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: child!,
          ),
        );
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            disableAnimations: reduceMotionSetting ? true : null,
            // Settings size stacks on the OS size.
            textScaler: TextScaler.linear(mq.textScaler.scale(1) * textScale),
          ),
          child: body,
        );
      },
    );
  }
}
