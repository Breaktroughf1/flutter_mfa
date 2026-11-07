// Licence allowlist for every third-party Dart package the workspace
// resolves (CLAUDE.md rule 6, NFR-10): MIT, BSD (2- or 3-clause) or
// Apache-2.0. Packages from the Flutter SDK and the workspace itself are
// skipped. Run after `dart pub get`:
//
//   dart run tool/check_licenses.dart
import 'dart:convert';
import 'dart:io';

const _names = ['LICENSE', 'LICENSE.md', 'LICENSE.txt', 'COPYING', 'LICENCE'];

/// Phrases that identify each allowed licence text.
const _allowed = <String, List<String>>{
  'MIT': ['Permission is hereby granted, free of charge'],
  'BSD': ['Redistribution and use in source and binary forms'],
  'Apache-2.0': ['Apache License', 'Version 2.0'],
};

/// Phrases that disqualify a text even when an allowed phrase matches: the
/// BSD-4-Clause advertising clause, which is not on the allowlist.
const _forbidden = ['advertising materials mentioning features or use'];

void main() {
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) {
    stderr.writeln('run `dart pub get` first');
    exit(2);
  }
  final root = Directory.current.uri;
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final packages =
      (jsonDecode(config.readAsStringSync())
              as Map<String, Object?>)['packages']!
          as List<Object?>;
  final failures = <String>[];
  final counts = <String, int>{};
  var checked = 0;
  for (final entry in packages.cast<Map<String, Object?>>()) {
    final name = entry['name']! as String;
    // Resolve against the absolute URI so `..` segments are normalised and a
    // package outside the workspace is never mistaken for one inside it.
    final dir = Directory.fromUri(
      config.absolute.uri.resolve(entry['rootUri']! as String),
    );
    final path = dir.absolute.path;
    if (path.startsWith(Directory.fromUri(root).absolute.path) ||
        (flutterRoot != null && path.startsWith(flutterRoot)) ||
        path.contains('/flutter/packages/') ||
        path.contains('/flutter/bin/cache/pkg/')) {
      continue; // workspace or Flutter SDK
    }
    checked++;
    final file = _names
        .map((n) => File('${dir.path}/$n'))
        .where((f) => f.existsSync())
        .firstOrNull;
    if (file == null) {
      failures.add('$name: no licence file');
      continue;
    }
    // Collapse line breaks and runs of spaces so wrapped phrases match.
    final text = file.readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
    if (_forbidden.any(text.toLowerCase().contains)) {
      failures.add('$name: BSD-4-Clause (advertising clause) not allowed');
      continue;
    }
    final kind = _allowed.entries
        .where((e) => e.value.every(text.contains))
        .map((e) => e.key)
        .firstOrNull;
    if (kind == null) {
      failures.add('$name: licence not in the allowlist');
    } else {
      counts[kind] = (counts[kind] ?? 0) + 1;
    }
  }
  if (failures.isNotEmpty) {
    stderr
      ..writeln('ERROR: licences outside MIT/BSD/Apache-2.0:')
      ..writeln(failures.map((f) => '  $f').join('\n'));
    exit(1);
  }
  final summary = counts.entries.map((e) => '${e.key} ${e.value}').join(', ');
  stdout.writeln('ok: $checked third-party packages ($summary)');
}
