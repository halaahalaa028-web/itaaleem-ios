/// One assignment from `GET /courses/{subject}/assignments` or
/// `GET /assignments/{id}`. Field names are read defensively since the
/// endpoints are new.
class Assignment {
  const Assignment({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.maxScore,
    this.score,
    this.isSubmitted = false,
    this.subjectName,
    this.attachmentUrl,
  });

  final int id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final num? maxScore;
  final num? score;
  final bool isSubmitted;
  final String? subjectName;

  /// The teacher's attached file (instructions/worksheet), if any.
  final String? attachmentUrl;

  bool get isOverdue =>
      !isSubmitted && dueDate != null && dueDate!.isBefore(DateTime.now());

  Assignment withSubject(String name) => Assignment(
    id: id,
    title: title,
    description: description,
    dueDate: dueDate,
    maxScore: maxScore,
    score: score,
    isSubmitted: isSubmitted,
    subjectName: name,
    attachmentUrl: attachmentUrl,
  );

  factory Assignment.fromJson(Map<String, dynamic> json) {
    final subject = json['subject'];
    final submission = json['submission'];
    final status = json['status']?.toString().toLowerCase();
    final rawScore =
        json['score'] ??
        json['grade'] ??
        (submission is Map ? submission['score'] : null);
    return Assignment(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: (json['title'] ?? json['name'] ?? '').toString(),
      description: (json['description'] ?? json['body'])?.toString(),
      dueDate: DateTime.tryParse(
        (json['due_date'] ?? json['deadline'] ?? json['due_at'] ?? '')
            .toString(),
      ),
      maxScore: num.tryParse(
        (json['max_score'] ?? json['total_score'] ?? json['max_grade'] ?? '')
            .toString(),
      ),
      score: num.tryParse((rawScore ?? '').toString()),
      isSubmitted:
          json['is_submitted'] == true ||
          json['submitted'] == true ||
          submission != null ||
          status == 'submitted' ||
          status == 'graded',
      subjectName: subject is Map ? subject['name']?.toString() : null,
      attachmentUrl:
          (json['file_url'] ?? json['attachment_url'] ?? json['file'])
              ?.toString(),
    );
  }
}

/// The student's own submission (`GET /assignments/{id}/submission`).
class AssignmentSubmission {
  const AssignmentSubmission({
    required this.id,
    this.submittedAt,
    this.score,
    this.feedback,
    this.fileUrl,
    this.notes,
  });

  final int id;
  final DateTime? submittedAt;
  final num? score;
  final String? feedback;
  final String? fileUrl;
  final String? notes;

  bool get isGraded => score != null;

  factory AssignmentSubmission.fromJson(Map<String, dynamic> json) {
    return AssignmentSubmission(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      submittedAt: DateTime.tryParse(
        (json['submitted_at'] ?? json['created_at'] ?? '').toString(),
      ),
      score: num.tryParse((json['score'] ?? json['grade'] ?? '').toString()),
      feedback: (json['feedback'] ?? json['comment'])?.toString(),
      fileUrl: (json['file_url'] ?? json['file'])?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}
