// Enforces coverage thresholds from an lcov file (ADR-0008).
//
// Usage: dart run tool/coverage_gate.dart <lcov.info> --lines 85 --branches 75
//
// Branch totals come from BRDA records: the Dart VM (`--branch-coverage` on
// `dart test` / `flutter test`) emits BRDA lines but no BRF/BRH summaries.
// Generated files are excluded. Exits 1 below a threshold, 2 on bad input.
import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty || args.first.startsWith('--')) {
    stderr.writeln(
      'usage: coverage_gate <lcov.info> [--lines N] [--branches N]',
    );
    exit(2);
  }
  final path = args.first;
  final minLines = _flag(args, '--lines') ?? 85;
  final minBranches = _flag(args, '--branches');

  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('coverage_gate: $path not found');
    exit(2);
  }

  final lines = <String, int>{}; // "file:line" -> hits
  final branches = <String, bool>{}; // "file:line:block:branch" -> taken
  String? source;
  var skip = false;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      source = line.substring(3);
      skip = _isGenerated(source);
    } else if (line == 'end_of_record') {
      source = null;
      skip = false;
    } else if (skip || source == null) {
      continue;
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      final key = '$source:${parts[0]}';
      final hits = int.tryParse(parts[1]) ?? 0;
      lines[key] = (lines[key] ?? 0) + hits;
    } else if (line.startsWith('BRDA:')) {
      final parts = line.substring(5).split(',');
      if (parts.length != 4) _bad(path, line);
      final key = '$source:${parts.take(3).join(':')}';
      final taken = parts[3] != '-' && (int.tryParse(parts[3]) ?? 0) > 0;
      branches[key] = (branches[key] ?? false) || taken;
    }
  }

  final lh = lines.values.where((h) => h > 0).length;
  final linePct = lines.isEmpty ? 100.0 : lh * 100 / lines.length;
  stdout.writeln(
    '$path  lines ${linePct.toStringAsFixed(2)}% ($lh/${lines.length})',
  );
  var failed = linePct < minLines;

  if (minBranches != null) {
    final bh = branches.values.where((t) => t).length;
    final brPct = branches.isEmpty ? 100.0 : bh * 100 / branches.length;
    stdout.writeln(
      '  branches ${brPct.toStringAsFixed(2)}% ($bh/${branches.length})',
    );
    failed = failed || brPct < minBranches;
  }

  if (failed) {
    stderr.writeln(
      'coverage_gate: FAILED (min lines $minLines%'
      '${minBranches == null ? '' : ', min branches $minBranches%'})',
    );
    exit(1);
  }
}

bool _isGenerated(String source) =>
    source.endsWith('.g.dart') || source.contains('/l10n/generated/');

Never _bad(String path, String line) {
  stderr.writeln('coverage_gate: malformed record in $path: $line');
  exit(2);
}

double? _flag(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i < 0) return null;
  final value = i + 1 < args.length ? double.tryParse(args[i + 1]) : null;
  if (value == null) {
    stderr.writeln('coverage_gate: $name needs a number');
    exit(2);
  }
  return value;
}
