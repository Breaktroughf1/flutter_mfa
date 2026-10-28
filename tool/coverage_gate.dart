// Enforces coverage thresholds from an lcov file (ADR-0008).
// Usage: dart run tool/coverage_gate.dart <lcov.info> --lines 85 --branches 75
// Excludes generated files. Exits 1 below threshold, 2 on bad input.
import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: coverage_gate <lcov.info> [--lines N] [--branches N]');
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

  var lf = 0, lh = 0, brf = 0, brh = 0;
  var skip = false;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      final src = line.substring(3);
      skip = src.endsWith('.g.dart') ||
          src.contains('/l10n/generated/') ||
          src.contains('messages.g.dart');
    } else if (skip) {
      continue;
    } else if (line.startsWith('LF:')) {
      lf += int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      lh += int.parse(line.substring(3));
    } else if (line.startsWith('BRF:')) {
      brf += int.parse(line.substring(4));
    } else if (line.startsWith('BRH:')) {
      brh += int.parse(line.substring(4));
    }
  }

  final linePct = lf == 0 ? 100.0 : lh * 100 / lf;
  stdout.writeln('$path  lines ${linePct.toStringAsFixed(2)}% ($lh/$lf)');
  var failed = linePct < minLines;

  if (minBranches != null) {
    if (brf == 0) {
      stdout.writeln('  branches: no branch data in lcov — see ADR-0008 (line gate only)');
    } else {
      final brPct = brh * 100 / brf;
      stdout.writeln('  branches ${brPct.toStringAsFixed(2)}% ($brh/$brf)');
      failed = failed || brPct < minBranches;
    }
  }

  if (failed) {
    stderr.writeln('coverage_gate: FAILED (min lines $minLines%'
        '${minBranches == null ? '' : ', min branches $minBranches%'})');
    exit(1);
  }
}

double? _flag(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) return null;
  return double.tryParse(args[i + 1]);
}
