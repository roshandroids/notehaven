import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:notehaven_tools/boundaries.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('boundaries_'));
  tearDown(() => root.deleteSync(recursive: true));

  void write(String rel, String content) {
    final f = File(p.join(root.path, rel))..createSync(recursive: true);
    f.writeAsStringSync(content);
  }

  test('clean layout has no violations', () {
    write('app/lib/features/a/domain/m.dart', 'class M {}');
    write('app/lib/features/a/data/r.dart', "import '../domain/m.dart';");
    expect(checkBoundaries(root.path), isEmpty);
  });

  test('domain importing Flutter is flagged', () {
    write(
      'app/lib/features/a/domain/m.dart',
      "import 'package:flutter/material.dart';",
    );
    expect(checkBoundaries(root.path), hasLength(1));
  });

  test('domain importing data is flagged', () {
    write('app/lib/features/a/data/r.dart', '');
    write('app/lib/features/a/domain/m.dart', "import '../data/r.dart';");
    expect(checkBoundaries(root.path).single.rule, contains('domain'));
  });

  test('feature importing another feature is flagged', () {
    write('app/lib/features/b/domain/m.dart', '');
    write(
      'app/lib/features/a/domain/m.dart',
      "import 'package:notehaven_app/features/b/domain/m.dart';",
    );
    expect(
      checkBoundaries(root.path).single.rule,
      contains('must not import feature'),
    );
  });

  test('presentation importing data is flagged', () {
    write('app/lib/features/a/data/r.dart', '');
    write('app/lib/features/a/presentation/s.dart', "import '../data/r.dart';");
    expect(checkBoundaries(root.path).single.rule, contains('presentation'));
  });

  test('package importing the app is flagged', () {
    write(
      'packages/x/lib/x.dart',
      "import 'package:notehaven_app/app/app.dart';",
    );
    expect(checkBoundaries(root.path).single.rule, contains('packages'));
  });

  test('notehaven_core importing Flutter is flagged', () {
    write(
      'packages/notehaven_core/lib/x.dart',
      "import 'package:flutter/foundation.dart';",
    );
    expect(checkBoundaries(root.path).single.rule, contains('notehaven_core'));
  });
}
