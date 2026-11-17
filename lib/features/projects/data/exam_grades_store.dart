import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ExamGradeEntry {
  const ExamGradeEntry({
    required this.id,
    required this.examTitle,
    required this.gradeTier,
    required this.scoreLabel,
    required this.encouragementAr,
    required this.encouragementEn,
    required this.recordedAt,
  });

  final String id;
  final String examTitle;
  final String gradeTier; // 'excellent' | 'very_good' | 'good' | 'pass'
  final String scoreLabel;
  final String encouragementAr;
  final String encouragementEn;
  final DateTime recordedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'examTitle': examTitle,
        'gradeTier': gradeTier,
        'scoreLabel': scoreLabel,
        'encouragementAr': encouragementAr,
        'encouragementEn': encouragementEn,
        'recordedAt': recordedAt.toIso8601String(),
      };

  factory ExamGradeEntry.fromJson(Map<String, dynamic> json) {
    return ExamGradeEntry(
      id: (json['id'] ?? '').toString(),
      examTitle: (json['examTitle'] ?? '').toString(),
      gradeTier: (json['gradeTier'] ?? 'excellent').toString(),
      scoreLabel: (json['scoreLabel'] ?? '').toString(),
      encouragementAr: (json['encouragementAr'] ?? '').toString(),
      encouragementEn: (json['encouragementEn'] ?? '').toString(),
      recordedAt:
          DateTime.tryParse((json['recordedAt'] ?? '').toString()) ??
              DateTime.now(),
    );
  }
}

class ExamGradesStore {
  static String _key(String userId) => 'handelha_exam_grades_$userId';

  static Future<List<ExamGradeEntry>> load(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(userId));
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((e) => ExamGradeEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    } catch (_) {
      return const [];
    }
  }

  static Future<ExamGradeEntry> addGrade({
    required String userId,
    required String examTitle,
    required String gradeTier,
    required String scoreLabel,
  }) async {
    final current = await load(userId);
    final msg = buildEncouragement(
      examTitle: examTitle,
      gradeTier: gradeTier,
      scoreLabel: scoreLabel,
    );
    final entry = ExamGradeEntry(
      id: 'grade_${DateTime.now().millisecondsSinceEpoch}',
      examTitle: examTitle.trim(),
      gradeTier: gradeTier,
      scoreLabel: scoreLabel.trim(),
      encouragementAr: msg.ar,
      encouragementEn: msg.en,
      recordedAt: DateTime.now(),
    );
    final updated = [entry, ...current];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key(userId),
        jsonEncode([for (final e in updated) e.toJson()]),
      );
    } catch (_) {}
    return entry;
  }

  static Future<void> clearForUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId));
    } catch (_) {}
  }

  static ({String ar, String en, String badgeAr, String badgeEn})
      buildEncouragement({
    required String examTitle,
    required String gradeTier,
    required String scoreLabel,
  }) {
    final cleanExam = examTitle.trim().isEmpty ? 'الامتحان' : examTitle.trim();
    return switch (gradeTier) {
      'excellent' => (
          ar: 'عاش بجد! تقدير «$scoreLabel» في «$cleanExam» يفرّح القلب، وتعبك ومذاكرتك بانوا في النتيجة. ألف مبروك عليك التقدير ده.',
          en: 'Incredible work! Scoring "$scoreLabel" in "$cleanExam" really shows how much effort you put in. You earned this top mark.',
          badgeAr: 'وسام الامتياز والتفوق',
          badgeEn: 'Honor & Excellence Badge',
        ),
      'very_good' => (
          ar: 'برافو عليك بجد! تقدير «$scoreLabel» في «$cleanExam» نتيجة محترمة جدًا وتطمن، وإن شاء الله المادة الجاية تقفّلها على طول.',
          en: 'Well done! Scoring "$scoreLabel" in "$cleanExam" is a strong result to be proud of, and you are right on track for the top.',
          badgeAr: 'وسام التقدير المتقدم',
          badgeEn: 'Strong Achiever Badge',
        ),
      'good' => (
          ar: 'عاش يا بطل، مجهود محترم في «$cleanExam» بتقدير «$scoreLabel». عدّيت خطوة مش سهلة، وبترتيب بسيط المرة الجاية مستواك هيعلى أكتر.',
          en: 'Solid work on "$cleanExam" with "$scoreLabel". You cleared an important exam, and with a steadier prep plan the next one gets even better.',
          badgeAr: 'وسام التقدّم والثبات',
          badgeEn: 'Steady Progress Badge',
        ),
      _ => (
          ar: 'ولا يهمك خالص في «$cleanExam»، المهم إنك دخلت وحاولت وعرفت المادة ماشية إزاي. هناخد نفس ونرتّب خطة مذاكرة هادية تعوّض بيها في اللي جاي.',
          en: 'Do not beat yourself up over "$cleanExam" — showing up and seeing what needs work is what counts. We will set a calmer study plan to bounce back next time.',
          badgeAr: 'وسام المثابرة والتعويض',
          badgeEn: 'Persistence & Comeback Badge',
        ),
    };
  }

  static String inferTierFromText(String norm) {
    if (norm.contains('امتياز') ||
        norm.contains('قفلت') ||
        norm.contains('فول مارك') ||
        norm.contains('full mark') ||
        norm.contains('a+') ||
        RegExp(r'\b(?:9\d|100)\s*%?').hasMatch(norm)) {
      return 'excellent';
    }
    if (norm.contains('جيد جدا') ||
        norm.contains('حلو اوي') ||
        norm.contains('ممتاز') ||
        norm.contains('very good') ||
        norm.contains('b+') ||
        RegExp(r'\b8\d\s*%?').hasMatch(norm)) {
      return 'very_good';
    }
    if (norm.contains('جيد') ||
        norm.contains('كويس') ||
        norm.contains('حليت حلو') ||
        norm.contains('نجحت') ||
        norm.contains('good') ||
        RegExp(r'\b7\d\s*%?').hasMatch(norm)) {
      return 'good';
    }
    return 'pass';
  }
}
