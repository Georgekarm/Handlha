import 'dart:math' as math;

import '../util/arabic_text.dart';
import 'nlu_features.dart';
import 'trained_egyptian_weights.dart';

enum EgyptianIntent {
  createTask,
  updateTask,
  completeTask,
  deleteTask,
  listTasks,
  summary,
  schedule,
  reminder,
  clarificationAnswer,
  greeting,
  outOfScope,
  unknown,
}

extension EgyptianIntentX on EgyptianIntent {
  String get wireName => switch (this) {
        EgyptianIntent.createTask => 'create_task',
        EgyptianIntent.updateTask => 'update_task',
        EgyptianIntent.completeTask => 'complete_task',
        EgyptianIntent.deleteTask => 'delete_task',
        EgyptianIntent.listTasks => 'list_tasks',
        EgyptianIntent.summary => 'summary',
        EgyptianIntent.schedule => 'schedule',
        EgyptianIntent.reminder => 'reminder',
        EgyptianIntent.clarificationAnswer => 'clarification_answer',
        EgyptianIntent.greeting => 'greeting',
        EgyptianIntent.outOfScope => 'out_of_scope',
        EgyptianIntent.unknown => 'unknown',
      };

  static EgyptianIntent fromWire(String value) {
    for (final intent in EgyptianIntent.values) {
      if (intent.wireName == value || intent.name == value) {
        return intent;
      }
    }
    return EgyptianIntent.unknown;
  }
}

class EgyptianIntentPrediction {
  const EgyptianIntentPrediction({
    required this.intent,
    required this.confidence,
    required this.normalizedText,
    this.margin = 0,
    this.secondBestIntent,
    this.belowThreshold,
    this.modelVersion = TrainedEgyptianIntentWeights.modelVersion,
  });

  final EgyptianIntent intent;
  final double confidence;
  final double margin;
  final String normalizedText;
  final EgyptianIntent? secondBestIntent;
  final bool? belowThreshold;
  final String modelVersion;

  bool get needsClarification =>
      intent == EgyptianIntent.unknown ||
      (belowThreshold ?? (confidence < 0.34 || margin < 0.025));
}

/// On-device Egyptian productivity intent classifier trained from scratch on
/// versioned Handelha annotations (`TrainedEgyptianIntentWeights`).
///
/// Honest scope: this is a compact closed-domain 12-class L2-regularized
/// softmax linear classifier (~1.3K n-gram/stem features), NOT a general LLM.
/// When custom [examples] are passed (e.g. unit tests), a local centroid model
/// is fit exclusively from those examples.
class EgyptianIntentModel {
  EgyptianIntentModel({List<EgyptianIntentExample>? examples})
      : _useTrainedWeights = examples == null,
        _centroids = examples == null ? const {} : _trainCentroids(examples);

  final bool _useTrainedWeights;
  final Map<EgyptianIntent, Map<String, double>> _centroids;

  String get modelVersion => _useTrainedWeights
      ? TrainedEgyptianIntentWeights.modelVersion
      : 'custom-centroid-v1';

  EgyptianIntentPrediction predict(String input) {
    final normalized = ArabicText.normalizeForNlu(input);
    if (normalized.isEmpty) {
      return EgyptianIntentPrediction(
        intent: EgyptianIntent.unknown,
        confidence: 0,
        normalizedText: normalized,
        belowThreshold: true,
        modelVersion: modelVersion,
      );
    }

    if (_useTrainedWeights) {
      return _predictLogReg(input, normalized);
    }
    return _predictCentroid(normalized);
  }

  EgyptianIntentPrediction _predictLogReg(String rawInput, String normalized) {
    final feats = EgyptianNluFeatures.extract(rawInput);
    if (feats.isEmpty) {
      return EgyptianIntentPrediction(
        intent: EgyptianIntent.unknown,
        confidence: 0,
        normalizedText: normalized,
        belowThreshold: true,
        modelVersion: modelVersion,
      );
    }

    const classes = TrainedEgyptianIntentWeights.classes;
    const biases = TrainedEgyptianIntentWeights.biases;
    const weights = TrainedEgyptianIntentWeights.featureWeights;

    final logits = List<double>.from(biases);
    for (final entry in feats.entries) {
      final row = weights[entry.key];
      if (row == null) continue;
      final value = entry.value;
      for (var c = 0; c < classes.length; c++) {
        logits[c] += row[c] * value;
      }
    }

    final maxLogit = logits.reduce(math.max);
    final exps = [for (final z in logits) math.exp(z - maxLogit)];
    final sum = exps.fold<double>(0.0, (a, b) => a + b);
    final probs = [for (final e in exps) e / sum];

    var bestIdx = 0;
    var secondIdx = 1;
    if (probs.length > 1 && probs[1] > probs[0]) {
      bestIdx = 1;
      secondIdx = 0;
    }
    for (var i = 2; i < probs.length; i++) {
      if (probs[i] > probs[bestIdx]) {
        secondIdx = bestIdx;
        bestIdx = i;
      } else if (probs[i] > probs[secondIdx]) {
        secondIdx = i;
      }
    }

    final topProb = probs[bestIdx];
    final secondProb = probs.length > 1 ? probs[secondIdx] : 0.0;
    final margin = topProb - secondProb;
    final below = topProb < TrainedEgyptianIntentWeights.minConfidence ||
        margin < TrainedEgyptianIntentWeights.minMargin;

    return EgyptianIntentPrediction(
      intent: below ? EgyptianIntent.unknown : classes[bestIdx],
      confidence: topProb,
      margin: margin,
      normalizedText: normalized,
      secondBestIntent: classes[secondIdx],
      belowThreshold: below,
      modelVersion: modelVersion,
    );
  }

  EgyptianIntentPrediction _predictCentroid(String normalized) {
    final vector = _centroidFeatures(normalized);
    final scores = <EgyptianIntent, double>{};
    for (final entry in _centroids.entries) {
      scores[entry.key] = _cosine(vector, entry.value);
    }
    final ranked = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final best = ranked.first;
    final second = ranked.length > 1 ? ranked[1].value : 0.0;
    final confidence = ((best.value + 1) / 2).clamp(0.0, 1.0).toDouble();
    final margin = best.value - second;
    return EgyptianIntentPrediction(
      intent: best.key,
      confidence: confidence,
      margin: margin,
      normalizedText: normalized,
      secondBestIntent: ranked.length > 1 ? ranked[1].key : null,
      belowThreshold: confidence < 0.34 || margin < 0.025,
      modelVersion: modelVersion,
    );
  }

  static Map<EgyptianIntent, Map<String, double>> _trainCentroids(
    List<EgyptianIntentExample> examples,
  ) {
    final buckets = <EgyptianIntent, List<Map<String, double>>>{};
    for (final example in examples) {
      final norm = ArabicText.normalizeForMatching(example.text);
      buckets.putIfAbsent(example.intent, () => []).add(_centroidFeatures(norm));
    }
    return {
      for (final entry in buckets.entries) entry.key: _centroid(entry.value),
    };
  }

  static Map<String, double> _centroid(List<Map<String, double>> vectors) {
    final result = <String, double>{};
    for (final vector in vectors) {
      for (final entry in vector.entries) {
        result[entry.key] = (result[entry.key] ?? 0) + entry.value;
      }
    }
    final count = vectors.length;
    result.updateAll((key, value) => value / count);
    return _unit(result);
  }

  static Map<String, double> _centroidFeatures(String text) {
    final result = <String, double>{};
    final compact = text.replaceAll(' ', '_');
    for (var n = 2; n <= 4; n++) {
      for (var i = 0; i + n <= compact.length; i++) {
        final gram = 'c$n:${compact.substring(i, i + n)}';
        result[gram] = (result[gram] ?? 0) + 1;
      }
    }
    for (final word in text.split(' ').where((w) => w.length > 1)) {
      final key = 'w:$word';
      result[key] = (result[key] ?? 0) + 1.5;
    }
    return _unit(result);
  }

  static Map<String, double> _unit(Map<String, double> vector) {
    var sum = 0.0;
    for (final value in vector.values) {
      sum += value * value;
    }
    if (sum == 0) return vector;
    final norm = math.sqrt(sum);
    return vector.map((key, value) => MapEntry(key, value / norm));
  }

  static double _cosine(Map<String, double> a, Map<String, double> b) {
    var score = 0.0;
    for (final entry in a.entries) {
      score += entry.value * (b[entry.key] ?? 0);
    }
    return score;
  }
}

class EgyptianIntentExample {
  const EgyptianIntentExample(this.text, this.intent);
  final String text;
  final EgyptianIntent intent;
}
