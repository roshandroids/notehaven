import 'dart:io';

import 'package:path/path.dart' as p;

/// One broken dependency rule.
class Violation {
  const Violation(this.file, this.rule, this.import);
  final String file;
  final String rule;
  final String import;

  @override
  String toString() => '$file: $rule (import: $import)';
}

final _importRe = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);
final _featureRe = RegExp(r'^app/lib/features/([^/]+)/([^/]+)/');

/// Scans every `.dart` file under [root] (repo root) and returns rule breaks.
///
/// Rules are documented in `documentation/dependency_rules.md`.
List<Violation> checkBoundaries(String root) {
  final violations = <Violation>[];
  final files = Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where(
        (f) => !p.split(f.path).any((s) => s == '.dart_tool' || s == 'build'),
      );

  for (final file in files) {
    final rel = p.relative(file.path, from: root);
    for (final m in _importRe.allMatches(file.readAsStringSync())) {
      final target = m.group(1)!;
      for (final rule in _rules(rel, target, _resolve(rel, target))) {
        violations.add(Violation(rel, rule, target));
      }
    }
  }
  return violations;
}

/// Maps an import to a repo-relative path, or null for external libraries.
String? _resolve(String fromRel, String target) {
  if (target.startsWith('dart:')) return null;
  const appPrefix = 'package:notehaven_app/';
  const corePrefix = 'package:notehaven_core/';
  if (target.startsWith(appPrefix)) {
    return 'app/lib/${target.substring(appPrefix.length)}';
  }
  if (target.startsWith(corePrefix)) {
    return 'packages/notehaven_core/lib/${target.substring(corePrefix.length)}';
  }
  if (target.startsWith('package:')) return null;
  return p.normalize(p.join(p.dirname(fromRel), target));
}

bool _isFlutter(String target) =>
    target.startsWith('package:flutter/') ||
    target.startsWith('package:flutter_');

const _purePackages = [
  'notehaven_core',
  'notehaven_sync',
  'notehaven_sync_rest',
];

bool _isDrift(String target) => target.startsWith('package:drift');

Iterable<String> _rules(String rel, String target, String? resolved) sync* {
  final from = _featureRe.firstMatch(rel);
  final to = resolved == null ? null : _featureRe.firstMatch(resolved);

  // 1. domain is pure: no Flutter, no data, no presentation.
  if (from != null && from.group(2) == 'domain') {
    if (_isFlutter(target)) yield 'domain must not import Flutter';
    if (_isDrift(target)) yield 'domain must not import drift';
    if (to != null &&
        to.group(1) == from.group(1) &&
        (to.group(2) == 'data' || to.group(2) == 'presentation')) {
      yield 'domain must not import data or presentation';
    }
  }
  // 2. a feature never imports another feature.
  if (from != null && to != null && from.group(1) != to.group(1)) {
    yield 'feature "${from.group(1)}" must not import feature "${to.group(1)}"';
  }
  // 3. features never import the composition root.
  if (from != null && resolved != null && resolved.startsWith('app/lib/app/')) {
    yield 'features must not import app/ (composition root)';
  }
  // 4. only the composition root knows concrete data implementations.
  if (from != null &&
      from.group(2) == 'presentation' &&
      to != null &&
      to.group(1) == from.group(1) &&
      to.group(2) == 'data') {
    yield 'presentation must not import data (use domain interfaces)';
  }
  if (from != null && from.group(2) == 'presentation' && _isDrift(target)) {
    yield 'presentation must not import drift';
  }
  // 5. packages never import the app.
  if (rel.startsWith('packages/') &&
      target.startsWith('package:notehaven_app/')) {
    yield 'packages must not import the app';
  }
  // 6. pure-Dart packages stay free of Flutter, and the sync packages also
  //    stay free of any database or vendor SDK.
  final pure = _purePackages.firstWhere(
    (p) => rel.startsWith('packages/$p/'),
    orElse: () => '',
  );
  if (pure.isNotEmpty) {
    if (_isFlutter(target)) yield '$pure must not import Flutter';
    if (pure.startsWith('notehaven_sync') && _isDrift(target)) {
      yield '$pure must not import drift';
    }
  }
}
