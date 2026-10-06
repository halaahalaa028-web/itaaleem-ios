import 'package:itaaleem/core/error/failure.dart';

/// A minimal `Result`/`Either` replacement built on Dart 3 sealed classes so
/// the app doesn't need an extra dependency (dartz/fpdart) just for this.
///
/// Repositories return `Future<Result<T>>` and presentation code exhausts
/// the two cases with a `switch`:
///
/// ```dart
/// final result = await repository.login(...);
/// switch (result) {
///   case Ok(:final value):
///     // use value
///   case Err(:final failure):
///     // show failure.message
/// }
/// ```
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;
}
