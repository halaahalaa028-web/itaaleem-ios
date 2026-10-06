import 'package:dio/dio.dart';

/// Sealed hierarchy of failures the app can surface to presentation code.
///
/// Repositories never throw into presentation — they return
/// `Future<(Failure?, T?)>`-shaped results (see [Result]) so the UI layer
/// can exhaustively `switch` over every failure kind without a try/catch.
sealed class Failure {
  const Failure(this.message);

  /// Human-readable (already localized where possible) message.
  final String message;
}

/// The server responded with an error (4xx/5xx) that isn't one of the more
/// specific cases below (validation, unauthorized).
final class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode});

  final int? statusCode;
}

/// No connectivity, DNS failure, timeout, socket exception, etc. — the
/// request never got a response from the server at all.
final class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// HTTP 422-style validation failure, with field-level error messages as
/// returned by the Laravel API (`{"errors": {"phone": ["..."]}}`).
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {this.fieldErrors = const {}});

  final Map<String, List<String>> fieldErrors;
}

/// HTTP 401 — missing/expired/invalid auth token. Presentation should react
/// by logging the user out and redirecting to `/login`.
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(super.message);
}

/// Any failure that doesn't fit the categories above (unexpected
/// exceptions, decoding errors, etc.).
final class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}

/// Unwraps the [Failure] a [DioException] carries (stashed on `.error` by
/// `ErrorMappingInterceptor`), for call sites that don't go through a
/// repository's try/catch — e.g. a `FutureProvider` whose thrown
/// [DioException] surfaces as-is in `AsyncValue.error`.
Failure failureOf(Object error) {
  if (error is Failure) return error;
  if (error is DioException && error.error is Failure) {
    return error.error as Failure;
  }
  return const UnknownFailure('حدث خطأ ما، حاول مرة أخرى');
}
