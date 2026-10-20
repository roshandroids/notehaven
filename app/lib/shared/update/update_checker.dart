import 'dart:convert';

import 'package:http/http.dart' as http;

/// Latest published release of Note Haven.
class UpdateInfo {
  const UpdateInfo({required this.version, required this.url});

  final String version;
  final String url;
}

const _latestRelease =
    'https://api.github.com/repos/roshandroids/notehaven/releases/latest';

/// Asks GitHub for the latest release. Null when none is published yet;
/// throws on network, rate-limit or parse errors. Only runs on request.
Future<UpdateInfo?> fetchLatestRelease({http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final res = await c
        .get(
          Uri.parse(_latestRelease),
          headers: {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw Exception('GitHub answered ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return UpdateInfo(
      version: (json['tag_name'] as String).replaceFirst(RegExp('^v'), ''),
      url: json['html_url'] as String,
    );
  } finally {
    if (client == null) c.close();
  }
}

/// True when [latest] is a higher version than [current]; compares numbers
/// part by part, so 0.10.0 > 0.9.0. Ignores a `+build` suffix.
bool isNewerVersion(String latest, String current) {
  List<int> parts(String v) =>
      v.split('+').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final a = parts(latest), b = parts(current);
  for (var i = 0; i < a.length || i < b.length; i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}
