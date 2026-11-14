enum ParamType { string, integer, number, boolean, object }

enum ParamFormat { date, time }

class ParamSpec {
  const ParamSpec(
    this.name,
    this.type,
    this.description, {
    this.required = false,
    this.enumValues,
    this.format,
    this.min,
    this.max,
    this.maxLength = 200,
  });

  final String name;
  final ParamType type;
  final String description;
  final bool required;
  final List<String>? enumValues;
  final ParamFormat? format;
  final num? min;
  final num? max;
  final int maxLength;

  Map<String, dynamic> toJsonSchema() {
    final m = <String, dynamic>{'description': description};
    switch (type) {
      case ParamType.string:
        m['type'] = 'string';
        if (enumValues != null) m['enum'] = enumValues;
        if (format == ParamFormat.date) m['pattern'] = r'^\d{4}-\d{2}-\d{2}$';
        if (format == ParamFormat.time) m['pattern'] = r'^([01]\d|2[0-3]):[0-5]\d$';
        m['maxLength'] = maxLength;
        break;
      case ParamType.integer:
        m['type'] = 'integer';
        if (min != null) m['minimum'] = min;
        if (max != null) m['maximum'] = max;
        break;
      case ParamType.number:
        m['type'] = 'number';
        if (min != null) m['minimum'] = min;
        if (max != null) m['maximum'] = max;
        break;
      case ParamType.boolean:
        m['type'] = 'boolean';
        break;
      case ParamType.object:
        m['type'] = 'object';
        m['additionalProperties'] = true;
        break;
    }
    return m;
  }
}

/// Cross-field rule. Receives the cleaned args; returns an error or null.
typedef CrossRule = String? Function(Map<String, dynamic> args);

class ToolSchema {
  ToolSchema({
    required this.name,
    required this.description,
    required this.params,
    this.rules = const [],
  });

  final String name;
  final String description;
  final List<ParamSpec> params;
  final List<CrossRule> rules;

  /// Provider-neutral tool definition (JSON Schema, no extra properties).
  Map<String, dynamic> toDefinition() => {
        'name': name,
        'description': description,
        'parameters': {
          'type': 'object',
          'properties': {for (final p in params) p.name: p.toJsonSchema()},
          'required': [for (final p in params) if (p.required) p.name],
          'additionalProperties': false,
        },
      };
}
