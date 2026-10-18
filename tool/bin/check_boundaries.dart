import 'dart:io';

import 'package:notehaven_tools/boundaries.dart';

/// Usage: `dart run tool/bin/check_boundaries.dart [repoRoot]` (default `.`).
void main(List<String> args) {
  final violations = checkBoundaries(args.isEmpty ? '.' : args.first);
  if (violations.isEmpty) {
    stdout.writeln('Architecture boundaries OK.');
    return;
  }
  violations.forEach(stderr.writeln);
  stderr.writeln('${violations.length} boundary violation(s).');
  exit(1);
}
