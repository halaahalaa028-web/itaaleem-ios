import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _historyKey = 'exam_attempt_history';

/// One completed exam attempt, recorded locally the moment
/// `POST /exam-attempts/{id}/submit` succeeds — there is no
/// "my past exam results" endpoint on the backend, so this is the only
/// source [studentStatsProvider] has for "أداء الامتحانات" (total/passed/
/// failed). Local-only: resets on reinstall, never synced across devices.
class ExamAttemptRecord {
  const ExamAttemptRecord({
    required this.examId,
    required this.passed,
    required this.percentage,
    required this.takenAt,
  });

  final int examId;
  final bool passed;
  final double percentage;
  final DateTime takenAt;

  Map<String, dynamic> toJson() => {
    'examId': examId,
    'passed': passed,
    'percentage': percentage,
    'takenAt': takenAt.toIso8601String(),
  };

  factory ExamAttemptRecord.fromJson(Map<String, dynamic> json) {
    return ExamAttemptRecord(
      examId: json['examId'] as int,
      passed: json['passed'] as bool,
      percentage: (json['percentage'] as num).toDouble(),
      takenAt: DateTime.parse(json['takenAt'] as String),
    );
  }
}

class ExamHistoryService {
  Future<void> record(ExamAttemptRecord attempt) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _readAll(prefs);
    all.add(attempt);
    await prefs.setString(
      _historyKey,
      jsonEncode(all.map((a) => a.toJson()).toList()),
    );
  }

  Future<List<ExamAttemptRecord>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    return _readAll(prefs);
  }

  Future<List<ExamAttemptRecord>> _readAll(SharedPreferences prefs) async {
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => ExamAttemptRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

final examHistoryServiceProvider = Provider<ExamHistoryService>(
  (ref) => ExamHistoryService(),
);
