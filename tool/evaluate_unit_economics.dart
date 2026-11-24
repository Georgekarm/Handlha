import 'dart:convert';
import 'dart:io';

import 'package:handelha/core/telemetry/unit_economics_calculator.dart';

/// CLI runner for Phase 5 channel unit-economics & monetization Go/Stop evaluation.
///
/// Usage:
/// `dart run tool/evaluate_unit_economics.dart <channel_experiment.json>`
void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/evaluate_unit_economics.dart <channel_experiment.json>',
    );
    exitCode = 64;
    return;
  }

  final file = File(args.first);
  if (!file.existsSync()) {
    stderr.writeln('Error: file not found: ${file.path}');
    exitCode = 2;
    return;
  }

  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final input = UnitEconomicsInput.fromJson(decoded);
  final report = UnitEconomicsCalculator.evaluate(input);
  stdout.writeln(report.toMarkdownReport());
}
