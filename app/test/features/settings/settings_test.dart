import 'dart:io';

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notehaven_app/app/app.dart';
import 'package:notehaven_app/app/feedback_wiring.dart';
import 'package:notehaven_app/shared/feedback/ui_feedback.dart';
import 'package:notehaven_app/app/theme/app_theme.dart';
import 'package:notehaven_app/features/notes/data/in_memory_note_repository.dart';
import 'package:notehaven_app/features/notes/presentation/note_providers.dart';
import 'package:notehaven_app/features/settings/data/in_memory_settings_repository.dart';
import 'package:notehaven_app/features/settings/data/prefs_settings_repository.dart';
import 'package:notehaven_app/features/settings/domain/app_settings.dart';
import 'package:notehaven_app/features/settings/presentation/settings_providers.dart';
import '../../support/fake_feedback.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  test('changelog top version matches pubspec version', () {
    final pub = File('pubspec.yaml').readAsStringSync();
    final log = File('assets/CHANGELOG.md').readAsStringSync();
    final v = RegExp(r'^version: *([0-9.]+)', multiLine: true).firstMatch(pub)!;
    final top = RegExp(r'^## \[([^\]]+)\]', multiLine: true).firstMatch(log)!;
    expect(top.group(1), v.group(1));
  });

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

    test(
      'feedback toggles default to haptics on, sounds off, system motion',
      () {
        const s = AppSettings();
        expect(s.hapticsEnabled, isTrue);
        expect(s.soundsEnabled, isFalse);
        expect(s.motion, MotionPreference.system);
      },
    );

    test('feedback setters persist', () async {
      final repo = InMemorySettingsRepository();
      final container = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final c = container.read(settingsProvider.notifier);
      c.setHaptics(false);
      c.setSounds(true);
      c.setMotion(MotionPreference.reduced);
      await Future<void>.delayed(Duration.zero);
      expect(repo.settings.hapticsEnabled, isFalse);
      expect(repo.settings.soundsEnabled, isTrue);
      expect(repo.settings.motion, MotionPreference.reduced);
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
      expect(s.hapticsEnabled, isTrue);
      expect(s.soundsEnabled, isFalse);
      expect(s.motion, MotionPreference.system);
    });

    test('round-trips through a fresh instance', () async {
      final first = await PrefsSettingsRepository.open();
      await first.save(
        const AppSettings(
          themePreference: ThemePreference.light,
          schemeName: 'mango',
          fontFamily: 'Lato',
          hapticsEnabled: false,
          soundsEnabled: true,
          motion: MotionPreference.reduced,
        ),
      );
      final loaded = (await PrefsSettingsRepository.open()).load();
      expect(loaded.themePreference, ThemePreference.light);
      expect(loaded.schemeName, 'mango');
      expect(loaded.fontFamily, 'Lato');
      expect(loaded.hapticsEnabled, isFalse);
      expect(loaded.soundsEnabled, isTrue);
      expect(loaded.motion, MotionPreference.reduced);
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

  testWidgets('feedback toggles in the UI persist and drive the service', (
    tester,
  ) async {
    final settingsRepo = InMemorySettingsRepository();
    final fake = FakeUiFeedback();
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(InMemoryNoteRepository()),
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
          feedbackPrefsOverride,
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const App();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(container.read(feedbackPrefsProvider).sounds, isFalse);
    await tester.tap(find.text('Sounds'));
    await tester.tap(find.text('Haptic feedback'));
    await tester.tap(find.text('Reduced'));
    await tester.pumpAndSettle();

    expect(settingsRepo.settings.soundsEnabled, isTrue);
    expect(settingsRepo.settings.hapticsEnabled, isFalse);
    expect(settingsRepo.settings.motion, MotionPreference.reduced);
    final prefs = container.read(feedbackPrefsProvider);
    expect(prefs.sounds, isTrue);
    expect(prefs.haptics, isFalse);
    expect(fake.events, isEmpty);
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

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    final target = FlexScheme.values.firstWhere(
      (s) => s != FlexScheme.custom && s.name != AppSettings.defaultSchemeName,
    );
    await tester.tap(find.text('Color theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('scheme-${target.name}')));
    await tester.pumpAndSettle();

    expect(settingsRepo.settings.schemeName, target.name);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(settingsRepo.settings.themePreference, ThemePreference.dark);
  });
}
