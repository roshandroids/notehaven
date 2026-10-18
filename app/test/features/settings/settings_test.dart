import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notehaven_app/app/app.dart';
import 'package:notehaven_app/app/theme/app_theme.dart';
import 'package:notehaven_app/features/notes/data/in_memory_note_repository.dart';
import 'package:notehaven_app/features/notes/presentation/note_providers.dart';
import 'package:notehaven_app/features/settings/data/in_memory_settings_repository.dart';
import 'package:notehaven_app/features/settings/data/prefs_settings_repository.dart';
import 'package:notehaven_app/features/settings/domain/app_settings.dart';
import 'package:notehaven_app/features/settings/presentation/settings_providers.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  group('SettingsController', () {
    test('setters update state and persist', () async {
      final repo = InMemorySettingsRepository();
      final container = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final controller = container.read(settingsProvider.notifier);

      controller.setThemePreference(ThemePreference.dark);
      controller.setScheme('mango');
      controller.setFont('Lato');
      await Future<void>.delayed(Duration.zero);

      expect(repo.settings.themePreference, ThemePreference.dark);
      expect(repo.settings.schemeName, 'mango');
      expect(repo.settings.fontFamily, 'Lato');

      controller.setFont(null);
      expect(container.read(settingsProvider).fontFamily, isNull);
    });
  });

  group('PrefsSettingsRepository', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('defaults when nothing is saved', () async {
      final repo = await PrefsSettingsRepository.open();
      final s = repo.load();
      expect(s.themePreference, ThemePreference.system);
      expect(s.schemeName, AppSettings.defaultSchemeName);
      expect(s.fontFamily, isNull);
    });

    test('round-trips through a fresh instance', () async {
      final first = await PrefsSettingsRepository.open();
      await first.save(
        const AppSettings(
          themePreference: ThemePreference.light,
          schemeName: 'mango',
          fontFamily: 'Lato',
        ),
      );
      final loaded = (await PrefsSettingsRepository.open()).load();
      expect(loaded.themePreference, ThemePreference.light);
      expect(loaded.schemeName, 'mango');
      expect(loaded.fontFamily, 'Lato');
    });
  });

  group('buildThemes', () {
    test('unknown scheme name falls back to the default scheme', () {
      final fallback = buildThemes(const AppSettings(schemeName: 'nope'));
      final indigo = buildThemes(const AppSettings());
      expect(
        fallback.light.colorScheme.primary,
        indigo.light.colorScheme.primary,
      );
    });

    test('different schemes produce different colors', () {
      final a = buildThemes(AppSettings(schemeName: FlexScheme.indigo.name));
      final b = buildThemes(AppSettings(schemeName: FlexScheme.mango.name));
      expect(a.light.colorScheme.primary, isNot(b.light.colorScheme.primary));
    });
  });

  testWidgets('picking a color theme in the UI changes the app theme', (
    tester,
  ) async {
    final settingsRepo = InMemorySettingsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(InMemoryNoteRepository()),
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Appearance'));
    await tester.pumpAndSettle();

    final target = FlexScheme.values.firstWhere(
      (s) => s != FlexScheme.custom && s.name != AppSettings.defaultSchemeName,
    );
    await tester.tap(find.byKey(Key('scheme-${target.name}')));
    await tester.pumpAndSettle();

    expect(settingsRepo.settings.schemeName, target.name);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(settingsRepo.settings.themePreference, ThemePreference.dark);
  });
}
