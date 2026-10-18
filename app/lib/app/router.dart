import 'package:animations/animations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/notes/presentation/note_editor_screen.dart';
import '../features/notes/presentation/notes_screen.dart';
import '../features/settings/presentation/font_picker_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../shared/layout/layout.dart';
import 'adaptive_shell.dart';

/// Shared-axis slide between screens (cheap, GPU-friendly transition).
CustomTransitionPage<void> _page(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondary, child) =>
          SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondary,
            transitionType: SharedAxisTransitionType.horizontal,
            fillColor: const Color(0x00000000),
            child: child,
          ),
    );

/// App router. Each feature contributes its routes here.
final routerProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AdaptiveShell(state: state, child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => _page(
              state,
              Builder(
                builder: (context) => isSplitView(context)
                    ? const SelectNotePlaceholder()
                    : const NotesScreen(),
              ),
            ),
          ),
          GoRoute(
            path: '/notes/:id',
            pageBuilder: (context, state) =>
                _page(state, NoteEditorScreen(id: state.pathParameters['id']!)),
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => _page(state, const SettingsScreen()),
        routes: [
          GoRoute(
            path: 'font',
            pageBuilder: (context, state) =>
                _page(state, const FontPickerScreen()),
          ),
        ],
      ),
    ],
  ),
);
