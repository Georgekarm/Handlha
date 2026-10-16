import '../models/tool_models.dart';
import '../util/wall_clock.dart';
import 'tool_definitions.dart';
import 'tool_schema.dart';

class ValidationResult {
  const ValidationResult._(this.ok, this.errors, this.args);
  factory ValidationResult.ok(Map<String, dynamic> args) =>
      ValidationResult._(true, const [], args);
  factory ValidationResult.fail(List<String> errors) =>
      ValidationResult._(false, errors, const {});
  final bool ok;
  final List<String> errors;

  /// Cleaned arguments (trimmed strings, nulls removed). Only valid if [ok].
  final Map<String, dynamic> args;
}

/// Strict validation of raw LLM tool calls. Nothing reaches the application
/// unless it passes: unknown tools/params, wrong types, bad enums, malformed
/// or implausible dates/times and missing required params are all rejected.
class ToolValidator {
  ToolValidator({required this.now, Map<String, ToolSchema>? schemas})
      : schemas = schemas ?? AssistantTools.validatable;

  final WallClock now;
  final Map<String, ToolSchema> schemas;

  static final _control = RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]');
  static final _dateRe = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
  static final _timeRe = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  ValidationResult validate(ToolCall call) {
    final schema = schemas[call.name];
    if (schema == null) {
      return ValidationResult.fail(['Unknown tool "${call.name}".']);
    }
    final specs = {for (final p in schema.params) p.name: p};
    final errors = <String>[];
    final clean = <String, dynamic>{};

    call.arguments.forEach((key, value) {
      final spec = specs[key];
      if (spec == null) {
        errors.add('Unknown parameter "$key".');
        return;
      }
      if (value == null) return; // models often send null for "absent"
      final v = _coerce(spec, value, errors);
      if (v != null) clean[key] = v;
    });

    for (final p in schema.params) {
      if (p.required && !clean.containsKey(p.name)) {
        errors.add('Missing required parameter "${p.name}".');
      }
    }

    if (errors.isEmpty) {
      for (final rule in schema.rules) {
        final e = rule(clean);
        if (e != null) errors.add(e);
      }
    }
    return errors.isEmpty ? ValidationResult.ok(clean) : ValidationResult.fail(errors);
  }

  Object? _coerce(ParamSpec s, Object v, List<String> errors) {
    switch (s.type) {
      case ParamType.string:
        if (v is! String) {
          errors.add('"${s.name}" must be a string.');
          return null;
        }
        final t = v.trim();
        if (t.isEmpty) return null; // required-ness is checked by the caller
        if (t.length > s.maxLength) {
          errors.add('"${s.name}" is too long (max ${s.maxLength}).');
          return null;
        }
        if (_control.hasMatch(t)) {
          errors.add('"${s.name}" contains control characters.');
          return null;
        }
        if (s.enumValues != null && !s.enumValues!.contains(t)) {
          errors.add('"${s.name}" must be one of: ${s.enumValues!.join(', ')}.');
          return null;
        }
        if (s.format == ParamFormat.date) {
          final err = _checkDate(t);
          if (err != null) {
            errors.add('"${s.name}" $err');
            return null;
          }
        } else if (s.format == ParamFormat.time) {
          if (!_timeRe.hasMatch(t)) {
            errors.add('"${s.name}" must be HH:mm (24-hour).');
            return null;
          }
        }
        return t;
      case ParamType.integer:
        int? n;
        if (v is int) {
          n = v;
        } else if (v is double && v == v.truncateToDouble()) {
          n = v.toInt();
        }
        if (n == null) {
          errors.add('"${s.name}" must be an integer.');
          return null;
        }
        return _range(s, n, errors) ? n : null;
      case ParamType.number:
        if (v is! num) {
          errors.add('"${s.name}" must be a number.');
          return null;
        }
        return _range(s, v, errors) ? v : null;
      case ParamType.boolean:
        if (v is! bool) {
          errors.add('"${s.name}" must be true or false.');
          return null;
        }
        return v;
      case ParamType.object:
        if (v is! Map) {
          errors.add('"${s.name}" must be an object.');
          return null;
        }
        return Map<String, dynamic>.from(v);
    }
  }

  bool _range(ParamSpec s, num n, List<String> errors) {
    if (s.min != null && n < s.min!) {
      errors.add('"${s.name}" must be >= ${s.min}.');
      return false;
    }
    if (s.max != null && n > s.max!) {
      errors.add('"${s.name}" must be <= ${s.max}.');
      return false;
    }
    return true;
  }

  String? _checkDate(String t) {
    final m = _dateRe.firstMatch(t);
    if (m == null) return 'must be YYYY-MM-DD.';
    final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
    final dt = DateTime.utc(y, mo, d);
    if (dt.year != y || dt.month != mo || dt.day != d) return 'is not a real calendar date.';
    final days = dt.difference(DateTime.utc(now.wall.year, now.wall.month, now.wall.day)).inDays;
    if (days < -3650 || days > 1826) return 'is outside the plausible range.';
    return null;
  }
}
