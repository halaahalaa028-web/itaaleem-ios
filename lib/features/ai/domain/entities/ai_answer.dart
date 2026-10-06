/// The server's response to one `POST /ai/ask` question.
class AiAnswer {
  const AiAnswer({required this.answer, this.remainingQuestions});

  final String answer;

  /// How many more questions the student can ask today, if the server
  /// sends a count back — `null` when it doesn't.
  final int? remainingQuestions;
}
