import 'dart:convert';
import 'dart:io';

import 'package:handelha/core/telemetry/pilot_cohort_evaluator.dart';

/// CLI runner for Phase 4a & 4b pilot cohort evaluation.
///
/// Usage:
/// `dart run tool/evaluate_pilot_cohorts.dart <directory_or_json_file> [--as-of=YYYY-MM-DD] [--min-users=10]`
///
/// Accepts either:
/// - A directory containing individual user-exported anonymous telemetry JSON files, OR
/// - A single JSON file containing a JSON array of anonymous telemetry snapshots.
void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/evaluate_pilot_cohorts.dart <dir_or_json_file> [--as-of=YYYY-MM-DD] [--min-users=10]',
    );
    exitCode = 64;
    return;
  }

  final targetPath = args.first;
  DateTime asOf = DateTime.now();
  var minUsers = 10;

  for (final arg in args.skip(1)) {
    if (arg.startsWith('--as-of=')) {
      final parsed = DateTime.tryParse(arg.substring('--as-of='.length));
      if (parsed != null) asOf = parsed;
    } else if (arg.startsWith('--min-users=')) {
      final parsed = int.tryParse(arg.substring('--min-users='.length));
      if (parsed != null && parsed > 0) minUsers = parsed;
    }
  }

  final snapshots = <Map<String, dynamic>>[];
  final type = FileSystemEntity.typeSync(targetPath);

  if (type == FileSystemEntityType.directory) {
    final files = Directory(targetPath)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is Map<String, dynamic>) {
        snapshots.add(decoded);
      } else if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) snapshots.add(item);
        }
      }
    }
  } else if (type == FileSystemEntityType.file) {
    final decoded = jsonDecode(File(targetPath).readAsStringSync());
    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map<String, dynamic>) snapshots.add(item);
      }
    } else if (decoded is Map<String, dynamic>) {
      snapshots.add(decoded);
    }
  } else {
    stderr.writeln('Error: path not found: $targetPath');
    exitCode = 2;
    return;
  }

  final report = PilotCohortEvaluator.evaluate(
    snapshots,
    asOf: asOf,
    minActivatedForDecision: minUsers,
    minD28EligibleForDecision: minUsers,
  );
  stdout.writeln(report.toMarkdownReport());
}
