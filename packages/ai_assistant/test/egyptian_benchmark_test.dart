import 'dart:convert';
import 'dart:io';

import 'package:ai_assistant/ai_assistant.dart';
import 'package:flutter_test/flutter_test.dart';

class _Sample {
  _Sample(this.id, this.text, this.intent, this.family, this.mustNotExecute);
  final String id;
  final String text;
  final EgyptianIntent intent;
  final String family;
  final bool mustNotExecute;
}

List<_Sample> _parse(List<dynamic> list) => [
      for (final raw in list)
        _Sample(
          (raw as Map<String, dynamic>)['id'] as String,
          raw['text'] as String,
          EgyptianIntentX.fromWire(raw['intent'] as String),
          raw['family'] as String,
          raw['must_not_execute'] == true,
        ),
    ];

double _macroF1(
  List<_Sample> samples,
  EgyptianIntent Function(String) predict,
) {
  final tp = {for (final i in EgyptianIntent.values) i: 0};
  final fp = {for (final i in EgyptianIntent.values) i: 0};
  final fn = {for (final i in EgyptianIntent.values) i: 0};
  final sup = {for (final i in EgyptianIntent.values) i: 0};

  for (final s in samples) {
    final p = predict(s.text);
    sup[s.intent] = sup[s.intent]! + 1;
    if (p == s.intent) {
      tp[p] = tp[p]! + 1;
    } else {
      fp[p] = fp[p]! + 1;
      fn[s.intent] = fn[s.intent]! + 1;
    }
  }
  var sum = 0.0;
  var active = 0;
  for (final i in EgyptianIntent.values) {
    if (sup[i]! == 0) continue;
    active++;
    final p = tp[i]! + fp[i]! == 0 ? 0.0 : tp[i]! / (tp[i]! + fp[i]!);
    final r = tp[i]! + fn[i]! == 0 ? 0.0 : tp[i]! / (tp[i]! + fn[i]!);
    sum += (p + r) == 0 ? 0.0 : 2 * p * r / (p + r);
  }
  return sum / active;
}

File _locateDataset() {
  final candidates = [
    File('data/egyptian_intent_annotations_v2.json'),
    File('packages/ai_assistant/data/egyptian_intent_annotations_v2.json'),
  ];
  return candidates.firstWhere(
    (f) => f.existsSync(),
    orElse: () => throw StateError('Cannot find egyptian_intent_annotations_v2.json'),
  );
}

void main() {
  group('Annotated Egyptian dataset integrity & held-out benchmark', () {
    final jsonMap =
        jsonDecode(_locateDataset().readAsStringSync()) as Map<String, dynamic>;
    final train = _parse(jsonMap['train'] as List<dynamic>);
    final dev = _parse(jsonMap['dev'] as List<dynamic>);
    final testSet = _parse(jsonMap['test'] as List<dynamic>);

    test('train, dev, and test have zero overlapping template families', () {
      final tf = train.map((e) => e.family).toSet();
      final df = dev.map((e) => e.family).toSet();
      final tef = testSet.map((e) => e.family).toSet();
      expect(tf.intersection(df), isEmpty);
      expect(tf.intersection(tef), isEmpty);
      expect(df.intersection(tef), isEmpty);
      expect(train.length, greaterThanOrEqualTo(100));
      expect(dev.length, greaterThanOrEqualTo(12));
      expect(testSet.length, greaterThanOrEqualTo(20));
    });

    test('trained softmax log-linear model outperforms cosine centroid baseline on dev & test', () {
      final trained = EgyptianIntentModel();
      expect(trained.modelVersion, startsWith('egyptian-logreg-'));

      final centroidBaseline = EgyptianIntentModel(
        examples: [
          for (final s in train) EgyptianIntentExample(s.text, s.intent),
        ],
      );

      final trainedDevF1 = _macroF1(dev, (t) => trained.predict(t).intent);
      final cenDevF1 = _macroF1(dev, (t) {
        final p = centroidBaseline.predict(t);
        return p.needsClarification ? EgyptianIntent.unknown : p.intent;
      });

      final trainedTestF1 = _macroF1(testSet, (t) => trained.predict(t).intent);
      final cenTestF1 = _macroF1(testSet, (t) {
        final p = centroidBaseline.predict(t);
        return p.needsClarification ? EgyptianIntent.unknown : p.intent;
      });

      expect(trainedDevF1, greaterThan(cenDevF1));
      expect(trainedTestF1, greaterThan(cenTestF1));
      expect(trainedTestF1, greaterThan(0.68));
    });

    test('inference speed stays well under 2ms per query on CPU', () {
      final trained = EgyptianIntentModel();
      final sw = Stopwatch()..start();
      for (var i = 0; i < 500; i++) {
        trained.predict(testSet[i % testSet.length].text);
      }
      sw.stop();
      final usPerQuery = sw.elapsedMicroseconds / 500;
      expect(usPerQuery, lessThan(2000));
    });
  });

  group('Hardened Arabic normalization & self-correction', () {
    test('collapses excessive elongation while preserving negation & English case', () {
      expect(ArabicText.collapseElongation('عااااوز أذااااكر'), 'عاوز أذاكر');
      final nlu = ArabicText.normalizeForNlu('ما تمسحش اجتماع Deep Learning بكرة');
      expect(nlu, contains('ما'));
      expect(nlu, contains('تمسحش'));
      expect(nlu, contains('deep learning'));

      final display = ArabicText.cleanDisplayPreserveCase('  ضيفلي   مذاكرة   Deep Learning  ');
      expect(display, contains('Deep Learning'));
    });

    test('resolves Egyptian and English self-correction phrases cleanly', () {
      final res = ArabicText.resolveSelfCorrection(
        'ضيفلي مراجعة فيزياء بكرة لا قصدي الخميس الساعة 8',
      );
      expect(res.hadCorrection, isTrue);
      expect(res.resolved, isNot(contains('بكرة')));
      expect(res.resolved, contains('ضيفلي مراجعة فيزياء'));
      expect(res.resolved, contains('الخميس'));

      final enRes = ArabicText.resolveSelfCorrection(
        'add physics tomorrow no I meant Thursday at 8 pm',
      );
      expect(enRes.hadCorrection, isTrue);
      expect(enRes.resolved.toLowerCase(), contains('add physics'));
      expect(enRes.resolved.toLowerCase(), isNot(contains('tomorrow')));
      expect(enRes.resolved.toLowerCase(), contains('thursday'));
    });
  });
}

