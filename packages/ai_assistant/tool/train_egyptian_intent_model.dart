import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:ai_assistant/src/nlu/egyptian_intent_model.dart';
import 'package:ai_assistant/src/nlu/nlu_features.dart';

class _Sample {
  _Sample({
    required this.id,
    required this.text,
    required this.intent,
    required this.family,
    required this.mustNotExecute,
  });

  final String id;
  final String text;
  final EgyptianIntent intent;
  final String family;
  final bool mustNotExecute;
}

class _EvalMetrics {
  _EvalMetrics({
    required this.name,
    required this.total,
    required this.correct,
    required this.accuracy,
    required this.macroPrecision,
    required this.macroRecall,
    required this.macroF1,
    required this.hardNegTotal,
    required this.hardNegBlocked,
    required this.perClass,
    required this.errors,
  });

  final String name;
  final int total;
  final int correct;
  final double accuracy;
  final double macroPrecision;
  final double macroRecall;
  final double macroF1;
  final int hardNegTotal;
  final int hardNegBlocked;
  final Map<EgyptianIntent, ({double p, double r, double f1, int support})>
      perClass;
  final List<String> errors;
}

void main(List<String> args) {
  final root = Directory.current.path;
  final datasetPath = args.isNotEmpty
      ? args.first
      : '$root/packages/ai_assistant/data/egyptian_intent_annotations_v2.json';
  final file = File(datasetPath);
  if (!file.existsSync()) {
    stderr.writeln('Dataset not found: $datasetPath');
    exitCode = 1;
    return;
  }

  final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final train = _parseSplit(raw['train'] as List<dynamic>);
  final dev = _parseSplit(raw['dev'] as List<dynamic>);
  final test = _parseSplit(raw['test'] as List<dynamic>);

  // Enforce zero template_family overlap across splits.
  final trainFamilies = train.map((e) => e.family).toSet();
  final devFamilies = dev.map((e) => e.family).toSet();
  final testFamilies = test.map((e) => e.family).toSet();

  final td = trainFamilies.intersection(devFamilies);
  final tt = trainFamilies.intersection(testFamilies);
  final dt = devFamilies.intersection(testFamilies);
  if (td.isNotEmpty || tt.isNotEmpty || dt.isNotEmpty) {
    stderr.writeln('LEAKAGE DETECTED across splits: td=$td tt=$tt dt=$dt');
    exitCode = 2;
    return;
  }

  stdout.writeln(
    'Dataset: ${raw['dataset_version']} '
    '(train=${train.length}, dev=${dev.length}, test=${test.length}) — '
    '0 family leakage verified.',
  );

  // Build vocabulary strictly from TRAIN, pruning noisy singletons in n-grams.
  final docFreq = <String, int>{};
  final trainFeats = <Map<String, double>>[];
  for (final sample in train) {
    final feats = EgyptianNluFeatures.extract(sample.text);
    trainFeats.add(feats);
    for (final key in feats.keys) {
      docFreq[key] = (docFreq[key] ?? 0) + 1;
    }
  }
  final vocab = <String>[
    for (final e in docFreq.entries)
      if ((!e.key.startsWith('c3:') &&
              !e.key.startsWith('b:') &&
              !e.key.startsWith('bm:')) ||
          e.value >= 2 ||
          e.key.contains('<BOS>') ||
          e.key.contains('<EOS>'))
        e.key,
  ]..sort();
  final featIndex = {for (var i = 0; i < vocab.length; i++) vocab[i]: i};

  // Sweep L2 regularization and threshold solely on DEV.
  const l2Candidates = [0.0004, 0.001, 0.0025, 0.006];
  _TrainedLogReg? bestModel;
  double bestDevScore = -1;
  double bestMinConf = 0.14;
  double bestMinMargin = 0.01;

  for (final l2 in l2Candidates) {
    final model = _trainSoftmax(
      train: train,
      trainFeats: trainFeats,
      vocab: vocab,
      featIndex: featIndex,
      l2: l2,
      epochs: 340,
      learningRate: 0.22,
    );

    for (final minConf in [0.10, 0.13, 0.17, 0.22, 0.28]) {
      for (final minMargin in [0.005, 0.015, 0.03, 0.05]) {
        final devMetrics = _evaluate(
          'Softmax(l2=$l2,c=$minConf,m=$minMargin)',
          dev,
          (text) => model.predict(text, minConf: minConf, minMargin: minMargin),
        );
        final hnRate = devMetrics.hardNegTotal == 0
            ? 1.0
            : devMetrics.hardNegBlocked / devMetrics.hardNegTotal;
        final score = devMetrics.macroF1 * 0.7 + hnRate * 0.3;
        if (score > bestDevScore) {
          bestDevScore = score;
          bestModel = model;
          bestMinConf = minConf;
          bestMinMargin = minMargin;
        }
      }
    }
  }

  final chosen = bestModel!;
  stdout.writeln(
    '\nSelected on DEV: l2=${chosen.l2}, '
    'minConfidence=$bestMinConf, minMargin=$bestMinMargin, vocab=${vocab.length}',
  );

  // Train CosineCentroid baseline strictly on TRAIN for apples-to-apples comparison.
  final centroidBaseline = EgyptianIntentModel(
    examples: [
      for (final s in train) EgyptianIntentExample(s.text, s.intent),
    ],
  );

  // Evaluate all models on DEV and held-out TEST.
  for (final splitEntry in [
    ('DEV', dev),
    ('TEST', test),
  ]) {
    final splitName = splitEntry.$1;
    final splitSamples = splitEntry.$2;
    stdout.writeln('\n=== $splitName SPLIT (${splitSamples.length} samples) ===');

    final kw = _evaluate(
      'KeywordBaseline',
      splitSamples,
      (t) => _predictKeywordBaseline(t),
    );
    final cen = _evaluate(
      'CosineCentroidBaseline',
      splitSamples,
      (t) {
        final p = centroidBaseline.predict(t);
        if (p.needsClarification) return EgyptianIntent.unknown;
        return p.intent;
      },
    );
    final lr = _evaluate(
      'FromScratchSoftmaxLogReg',
      splitSamples,
      (t) => chosen.predict(t, minConf: bestMinConf, minMargin: bestMinMargin),
    );

    for (final m in [kw, cen, lr]) {
      _printSummary(m);
    }
    stdout.writeln('Per-class F1 on $splitName (FromScratchSoftmaxLogReg):');
    for (final intent in EgyptianIntent.values) {
      final stat = lr.perClass[intent]!;
      stdout.writeln(
        '  ${intent.wireName.padRight(21)} P=${stat.p.toStringAsFixed(2)} '
        'R=${stat.r.toStringAsFixed(2)} F1=${stat.f1.toStringAsFixed(2)} '
        '(n=${stat.support})',
      );
    }
    if (lr.errors.isNotEmpty) {
      stdout.writeln('Errors on $splitName: ${lr.errors.join(' | ')}');
    }
  }

  // Export compact quantized weights file.
  final outPath =
      '$root/packages/ai_assistant/lib/src/nlu/trained_egyptian_weights.dart';
  final code = _emitWeightsDart(
    chosen,
    minConfidence: bestMinConf,
    minMargin: bestMinMargin,
    datasetVersion: raw['dataset_version'] as String? ?? 'egyptian-intent-v2',
    trainCount: train.length,
  );
  File(outPath).writeAsStringSync(code);
  final bytes = File(outPath).lengthSync();

  // Measure runtime latency on test texts using quantized weights lookup.
  final quantized = chosen.quantizedMap(threshold: 0.015);
  final sw = Stopwatch()..start();
  const iterations = 2000;
  for (var i = 0; i < iterations; i++) {
    final s = test[i % test.length];
    _predictQuantized(
      s.text,
      chosen.classes,
      chosen.biases,
      quantized,
      bestMinConf,
      bestMinMargin,
    );
  }
  sw.stop();
  final usPerQuery = sw.elapsedMicroseconds / iterations;

  stdout.writeln(
    '\nWrote $outPath ($bytes bytes on disk, '
    '${quantized.length} active weight features, '
    '${usPerQuery.toStringAsFixed(1)} us/query)',
  );
}

List<_Sample> _parseSplit(List<dynamic> list) {
  return [
    for (final item in list)
      _Sample(
        id: (item as Map<String, dynamic>)['id'] as String,
        text: item['text'] as String,
        intent: EgyptianIntentX.fromWire(item['intent'] as String),
        family: item['family'] as String,
        mustNotExecute: item['must_not_execute'] == true,
      ),
  ];
}

class _TrainedLogReg {
  _TrainedLogReg({
    required this.classes,
    required this.vocab,
    required this.featIndex,
    required this.weights,
    required this.biases,
    required this.l2,
  });

  final List<EgyptianIntent> classes;
  final List<String> vocab;
  final Map<String, int> featIndex;
  final List<List<double>> weights; // [classIdx][featIdx]
  final List<double> biases;
  final double l2;

  EgyptianIntent predict(
    String raw, {
    required double minConf,
    required double minMargin,
  }) {
    final feats = EgyptianNluFeatures.extract(raw);
    if (feats.isEmpty) return EgyptianIntent.unknown;

    final logits = List<double>.generate(classes.length, (c) {
      var z = biases[c];
      final wc = weights[c];
      for (final entry in feats.entries) {
        final idx = featIndex[entry.key];
        if (idx != null) z += wc[idx] * entry.value;
      }
      return z;
    });

    final probs = _softmax(logits);
    var bestIdx = 0;
    var secondProb = 0.0;
    for (var i = 0; i < probs.length; i++) {
      if (probs[i] > probs[bestIdx]) {
        secondProb = probs[bestIdx];
        bestIdx = i;
      } else if (i != bestIdx && probs[i] > secondProb) {
        secondProb = probs[i];
      }
    }
    final topProb = probs[bestIdx];
    final margin = topProb - secondProb;
    if (topProb < minConf || margin < minMargin) {
      return EgyptianIntent.unknown;
    }
    return classes[bestIdx];
  }

  Map<String, List<double>> quantizedMap({required double threshold}) {
    final result = <String, List<double>>{};
    for (var f = 0; f < vocab.length; f++) {
      var maxAbs = 0.0;
      for (var c = 0; c < classes.length; c++) {
        maxAbs = math.max(maxAbs, weights[c][f].abs());
      }
      if (maxAbs < threshold) continue;
      result[vocab[f]] = [
        for (var c = 0; c < classes.length; c++)
          double.parse(weights[c][f].toStringAsFixed(4)),
      ];
    }
    return result;
  }
}

_TrainedLogReg _trainSoftmax({
  required List<_Sample> train,
  required List<Map<String, double>> trainFeats,
  required List<String> vocab,
  required Map<String, int> featIndex,
  required double l2,
  required int epochs,
  required double learningRate,
}) {
  const classes = EgyptianIntent.values;
  final k = classes.length;
  final v = vocab.length;
  final classIdx = {for (var i = 0; i < k; i++) classes[i]: i};

  final w = List.generate(k, (_) => List<double>.filled(v, 0.0));
  final b = List<double>.filled(k, 0.0);

  // Adam optimizer state for clean, reproducible deterministic convergence.
  final mw = List.generate(k, (_) => List<double>.filled(v, 0.0));
  final vw = List.generate(k, (_) => List<double>.filled(v, 0.0));
  final mb = List<double>.filled(k, 0.0);
  final vb = List<double>.filled(k, 0.0);

  const beta1 = 0.9;
  const beta2 = 0.999;
  const eps = 1e-8;

  final sparseDocs = <List<(int, double)>>[
    for (final feats in trainFeats)
      [
        for (final e in feats.entries)
          if (featIndex[e.key] != null) (featIndex[e.key]!, e.value),
      ],
  ];
  final targets = [for (final s in train) classIdx[s.intent]!];
  final classCounts = List<int>.filled(k, 0);
  for (final y in targets) {
    classCounts[y]++;
  }
  final avgCount = train.length / k;
  final sampleWeights = [
    for (final y in targets) math.sqrt(avgCount / math.max(1, classCounts[y])),
  ];
  final totalWeight = sampleWeights.fold<double>(0.0, (a, b) => a + b);

  for (var epoch = 1; epoch <= epochs; epoch++) {
    final gw = List.generate(k, (_) => List<double>.filled(v, 0.0));
    final gb = List<double>.filled(k, 0.0);

    for (var i = 0; i < train.length; i++) {
      final doc = sparseDocs[i];
      final y = targets[i];
      final sw = sampleWeights[i];
      final logits = List<double>.filled(k, 0.0);
      for (var c = 0; c < k; c++) {
        var z = b[c];
        final wc = w[c];
        for (final (idx, val) in doc) {
          z += wc[idx] * val;
        }
        logits[c] = z;
      }
      final probs = _softmax(logits);
      for (var c = 0; c < k; c++) {
        final diff = sw * (probs[c] - (c == y ? 1.0 : 0.0)) / totalWeight;
        gb[c] += diff;
        final gwc = gw[c];
        for (final (idx, val) in doc) {
          gwc[idx] += diff * val;
        }
      }
    }

    final b1t = 1 - math.pow(beta1, epoch).toDouble();
    final b2t = 1 - math.pow(beta2, epoch).toDouble();

    for (var c = 0; c < k; c++) {
      mb[c] = beta1 * mb[c] + (1 - beta1) * gb[c];
      vb[c] = beta2 * vb[c] + (1 - beta2) * gb[c] * gb[c];
      final mHatB = mb[c] / b1t;
      final vHatB = vb[c] / b2t;
      b[c] -= learningRate * mHatB / (math.sqrt(vHatB) + eps);

      final wc = w[c];
      final gwc = gw[c];
      final mwc = mw[c];
      final vwc = vw[c];
      for (var f = 0; f < v; f++) {
        final grad = gwc[f] + l2 * wc[f];
        mwc[f] = beta1 * mwc[f] + (1 - beta1) * grad;
        vwc[f] = beta2 * vwc[f] + (1 - beta2) * grad * grad;
        final mHat = mwc[f] / b1t;
        final vHat = vwc[f] / b2t;
        wc[f] -= learningRate * mHat / (math.sqrt(vHat) + eps);
      }
    }
  }

  return _TrainedLogReg(
    classes: classes,
    vocab: vocab,
    featIndex: featIndex,
    weights: w,
    biases: b,
    l2: l2,
  );
}

List<double> _softmax(List<double> logits) {
  final m = logits.reduce(math.max);
  final exps = [for (final z in logits) math.exp(z - m)];
  final sum = exps.fold<double>(0, (a, b) => a + b);
  return [for (final e in exps) e / sum];
}

EgyptianIntent _predictKeywordBaseline(String raw) {
  final n = EgyptianNluFeatures.normalizeInput(raw);
  if (RegExp(r'(^|\s)(اهلا|ازيك|السلام|صباح|مساء|هلا)(\s|$)').hasMatch(n)) {
    return EgyptianIntent.greeting;
  }
  if (RegExp(r'(امسح|احذف|شيل|الغي)').hasMatch(n)) {
    return EgyptianIntent.deleteTask;
  }
  if (RegExp(r'(خلصت|تم انهاء|علمها|انجزت|اقفل|تم تسليم)').hasMatch(n)) {
    return EgyptianIntent.completeTask;
  }
  if (RegExp(r'(أجل|اجل|خليها|خلي |انقل|عدل|غير|ارفع)').hasMatch(n)) {
    return EgyptianIntent.updateTask;
  }
  if (RegExp(r'(فكرني|ذكرني|تذكير|تنبيه|نبهني)').hasMatch(n)) {
    return EgyptianIntent.reminder;
  }
  if (RegExp(r'(رتب|نظم|جدول|ابدأ بايه|ابدا بايه|خطه|خطة)').hasMatch(n)) {
    return EgyptianIntent.schedule;
  }
  if (RegExp(r'(لخص|ملخص|تقرير|إجمالي|اجمالي|فاضلي|كام)').hasMatch(n)) {
    return EgyptianIntent.summary;
  }
  if (RegExp(r'(وريني|ايه اللي|عندى ايه|عندي ايه|دور|المتبقية|المفتوحة)').hasMatch(n)) {
    return EgyptianIntent.listTasks;
  }
  if (RegExp(r'(ضيف|سجل|حط|تاسك|امتحان|محاضره|محاضرة|اكتب)').hasMatch(n)) {
    return EgyptianIntent.createTask;
  }
  if (RegExp(r'(نكتة|صورة|الطقس|دولار|فيلم|قصيدة)').hasMatch(n)) {
    return EgyptianIntent.outOfScope;
  }
  return EgyptianIntent.unknown;
}

EgyptianIntent _predictQuantized(
  String raw,
  List<EgyptianIntent> classes,
  List<double> biases,
  Map<String, List<double>> weights,
  double minConf,
  double minMargin,
) {
  final feats = EgyptianNluFeatures.extract(raw);
  final logits = List<double>.from(biases);
  for (final e in feats.entries) {
    final row = weights[e.key];
    if (row == null) continue;
    for (var c = 0; c < classes.length; c++) {
      logits[c] += row[c] * e.value;
    }
  }
  final probs = _softmax(logits);
  var best = 0;
  var second = 0.0;
  for (var i = 0; i < probs.length; i++) {
    if (probs[i] > probs[best]) {
      second = probs[best];
      best = i;
    } else if (i != best && probs[i] > second) {
      second = probs[i];
    }
  }
  if (probs[best] < minConf || (probs[best] - second) < minMargin) {
    return EgyptianIntent.unknown;
  }
  return classes[best];
}

_EvalMetrics _evaluate(
  String name,
  List<_Sample> samples,
  EgyptianIntent Function(String text) predict,
) {
  var correct = 0;
  var hnTotal = 0;
  var hnBlocked = 0;
  final tp = {for (final i in EgyptianIntent.values) i: 0};
  final fp = {for (final i in EgyptianIntent.values) i: 0};
  final fn = {for (final i in EgyptianIntent.values) i: 0};
  final support = {for (final i in EgyptianIntent.values) i: 0};
  final errors = <String>[];

  for (final s in samples) {
    final pred = predict(s.text);
    support[s.intent] = support[s.intent]! + 1;
    if (pred == s.intent) {
      correct++;
      tp[pred] = tp[pred]! + 1;
    } else {
      fp[pred] = fp[pred]! + 1;
      fn[s.intent] = fn[s.intent]! + 1;
      errors.add('${s.id}:${s.intent.wireName}->${pred.wireName}');
    }
    if (s.mustNotExecute) {
      hnTotal++;
      if (pred == EgyptianIntent.unknown || pred == EgyptianIntent.outOfScope) {
        hnBlocked++;
      }
    }
  }

  final perClass = <EgyptianIntent, ({double p, double r, double f1, int support})>{};
  var pSum = 0.0;
  var rSum = 0.0;
  var f1Sum = 0.0;
  var activeClasses = 0;

  for (final i in EgyptianIntent.values) {
    final tpi = tp[i]!;
    final fpi = fp[i]!;
    final fni = fn[i]!;
    final sup = support[i]!;
    final p = (tpi + fpi) == 0 ? 0.0 : tpi / (tpi + fpi);
    final r = (tpi + fni) == 0 ? 0.0 : tpi / (tpi + fni);
    final f1 = (p + r) == 0 ? 0.0 : 2 * p * r / (p + r);
    perClass[i] = (p: p, r: r, f1: f1, support: sup);
    if (sup > 0) {
      activeClasses++;
      pSum += p;
      rSum += r;
      f1Sum += f1;
    }
  }

  return _EvalMetrics(
    name: name,
    total: samples.length,
    correct: correct,
    accuracy: correct / samples.length,
    macroPrecision: pSum / activeClasses,
    macroRecall: rSum / activeClasses,
    macroF1: f1Sum / activeClasses,
    hardNegTotal: hnTotal,
    hardNegBlocked: hnBlocked,
    perClass: perClass,
    errors: errors,
  );
}

void _printSummary(_EvalMetrics m) {
  stdout.writeln(
    '  ${m.name.padRight(24)} Acc=${(m.accuracy * 100).toStringAsFixed(1)}% '
    '(${m.correct}/${m.total}) '
    'MacroP=${m.macroPrecision.toStringAsFixed(3)} '
    'MacroR=${m.macroRecall.toStringAsFixed(3)} '
    'MacroF1=${m.macroF1.toStringAsFixed(3)} '
    'HardNegBlock=${m.hardNegBlocked}/${m.hardNegTotal}',
  );
}

String _emitWeightsDart(
  _TrainedLogReg model, {
  required double minConfidence,
  required double minMargin,
  required String datasetVersion,
  required int trainCount,
}) {
  final q = model.quantizedMap(threshold: 0.015);
  final buf = StringBuffer()
    ..writeln('// GENERATED BY packages/ai_assistant/tool/train_egyptian_intent_model.dart')
    ..writeln('// Trained strictly from scratch on TRAIN split only ($trainCount examples) of $datasetVersion.')
    ..writeln('// NOT a general LLM; closed-domain 12-class L2-regularized softmax classifier.')
    ..writeln()
    ..writeln("import 'egyptian_intent_model.dart';")
    ..writeln()
    ..writeln('class TrainedEgyptianIntentWeights {')
    ..writeln('  const TrainedEgyptianIntentWeights._();')
    ..writeln()
    ..writeln("  static const String modelVersion = 'egyptian-logreg-v2.0';")
    ..writeln("  static const String datasetVersion = '$datasetVersion';")
    ..writeln('  static const int trainExampleCount = $trainCount;')
    ..writeln('  static const double l2Regularization = ${model.l2};')
    ..writeln('  static const double minConfidence = $minConfidence;')
    ..writeln('  static const double minMargin = $minMargin;')
    ..writeln()
    ..writeln('  static const List<EgyptianIntent> classes = [');
  for (final c in model.classes) {
    buf.writeln('    EgyptianIntent.${c.name},');
  }
  buf.writeln('  ];');
  buf.writeln();
  buf.writeln('  static const List<double> biases = [');
  for (final b in model.biases) {
    buf.writeln('    ${b.toStringAsFixed(4)},');
  }
  buf.writeln('  ];');
  buf.writeln();
  buf.writeln('  static const Map<String, List<double>> featureWeights = {');
  for (final entry in q.entries) {
    final escaped = entry.key
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'");
    final nums = entry.value.map((v) => v.toString()).join(', ');
    buf.writeln("    '$escaped': [$nums],");
  }
  buf
    ..writeln('  };')
    ..writeln('}');
  return buf.toString();
}
