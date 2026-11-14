import 'package:flutter_test/flutter_test.dart';
import 'package:ai_assistant/ai_assistant.dart';

void main() {
  final model = EgyptianIntentModel();

  test('learned baseline separates common Egyptian intents', () {
    expect(model.predict('ضيفلي assignment بكرة').intent, EgyptianIntent.createTask);
    expect(model.predict('أجلها للخميس').intent, EgyptianIntent.updateTask);
    expect(model.predict('امسح مهمة المشروع').intent, EgyptianIntent.deleteTask);
    expect(model.predict('لخص يومي').intent, EgyptianIntent.summary);
  });

  test('normalization preserves English words and removes presentation-only marks', () {
    final result = model.predict('ضِيفلي  assignment  ٨ الصبح');
    expect(result.normalizedText, contains('assignment'));
    expect(result.normalizedText, contains('8'));
    expect(result.normalizedText, isNot(contains('ِ')));
  });

  test('empty input is unknown and requires clarification', () {
    final result = model.predict('   ');
    expect(result.intent, EgyptianIntent.unknown);
    expect(result.needsClarification, isTrue);
  });
}
