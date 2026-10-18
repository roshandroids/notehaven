import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../layout/layout.dart';

/// Which scene an [Illustration] draws; each maps to an unDraw SVG
/// (https://undraw.co, free license) in `assets/illustrations/`.
enum IllustrationKind {
  empty,
  search,
  select,
  error,
  loading,
  saved,
  deleted,
  sync,
  onboarding,
  offline,
}

/// Theme-tinted SVG scene with a gentle idle animation (static when the OS
/// asks to reduce motion). Colors come from the active [ColorScheme] so it
/// follows every color theme and dark mode.
class Illustration extends StatelessWidget {
  const Illustration(this.kind, {this.size = 200, super.key});

  final IllustrationKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final svg = SvgPicture.asset(
      'assets/illustrations/${kind.name}.svg',
      width: size,
      height: size,
      semanticsLabel: kind.name,
      // unDraw's accent purple becomes the active theme color.
      colorMapper: _AccentMapper(cs.primary),
    );
    if (reduceMotion(context)) return svg;
    // Finite loop: an endless animation would never let pumpAndSettle finish.
    final animated = svg.animate(
      onPlay: (c) => c.repeat(reverse: true, count: 6),
    );
    return kind == IllustrationKind.loading
        ? animated.scale(
            duration: 900.ms,
            begin: const Offset(0.92, 0.92),
            end: const Offset(1.04, 1.04),
            curve: Curves.easeInOut,
          )
        : animated.moveY(
            duration: 2200.ms,
            begin: -5,
            end: 5,
            curve: Curves.easeInOut,
          );
  }
}

class _AccentMapper extends ColorMapper {
  const _AccentMapper(this.accent);

  final Color accent;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) => color == const Color(0xFF6C63FF) ? accent : color;
}

/// Illustration with a title (and optional subtitle) underneath.
class IllustratedMessage extends StatelessWidget {
  const IllustratedMessage({
    required this.kind,
    required this.title,
    this.subtitle,
    super.key,
  });

  final IllustrationKind kind;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Illustration(kind),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
