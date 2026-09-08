import '../error/failure.dart';

/// The return type of every repository and use case.
///
/// Callers pattern-match on it instead of catching exceptions:
///
/// ```dart
/// switch (result) {
///   case Success(:final data) => ...,
///   case Error(:final failure) => ...,
/// }
/// ```
sealed class Result<T> {
  const Result();

  const factory Result.success(T data) = Success<T>;

  const factory Result.error(Failure failure) = Error<T>;

  bool get isSuccess => this is Success<T>;

  /// The value on success, `null` otherwise.
  T? get dataOrNull => switch (this) {
        Success<T>(:final data) => data,
        Error<T>() => null,
      };

  /// The failure on error, `null` otherwise.
  Failure? get failureOrNull => switch (this) {
        Success<T>() => null,
        Error<T>(:final failure) => failure,
      };

  /// Maps the success value, leaving a failure untouched.
  Result<R> map<R>(R Function(T data) transform) => switch (this) {
        Success<T>(:final data) => Success<R>(transform(data)),
        Error<T>(:final failure) => Error<R>(failure),
      };

  /// Folds both branches into a single value.
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(Failure failure) onError,
  }) =>
      switch (this) {
        Success<T>(:final data) => onSuccess(data),
        Error<T>(:final failure) => onError(failure),
      };
}

final class Success<T> extends Result<T> {
  const Success(this.data);

  final T data;
}

final class Error<T> extends Result<T> {
  const Error(this.failure);

  final Failure failure;
}
