import 'package:flutter/foundation.dart';

/// Licenses Flutter cannot discover from `pubspec.yaml`: the app itself,
/// bundled illustrations, and fonts fetched at runtime by `google_fonts`.
/// Package licenses are listed automatically by `showLicensePage`.
void registerExtraLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['Note Haven'],
      'MIT License\n\nCopyright (c) 2026 Notehaven contributors\n\n'
      'Permission is hereby granted, free of charge, to any person obtaining '
      'a copy of this software and associated documentation files, to deal in '
      'the Software without restriction, including without limitation the '
      'rights to use, copy, modify, merge, publish, distribute, sublicense, '
      'and/or sell copies of the Software, subject to the conditions in the '
      'LICENSE file of the project repository.',
    );
    yield const LicenseEntryWithLineBreaks(
      ['unDraw illustrations'],
      'Illustrations by unDraw (undraw.co), used under the unDraw open-source '
      'license: free for personal and commercial use, no attribution required.',
    );
    yield const LicenseEntryWithLineBreaks(
      ['Google Fonts'],
      'Fonts are downloaded on demand from Google Fonts. Each family is '
      'licensed under the SIL Open Font License 1.1 or the Apache License 2.0; '
      'see fonts.google.com for the license of each family.',
    );
  });
}
