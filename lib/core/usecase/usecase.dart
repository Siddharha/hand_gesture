import '../result/result.dart';

/// A single piece of business logic, callable like a function.
///
/// [T] is what the use case produces, [P] what it needs to run. Use cases that
/// take no input declare `UseCase<T, NoParams>` and are invoked with
/// `useCase(const NoParams())`.
abstract interface class UseCase<T, P> {
  Future<Result<T>> call(P params);
}

/// A use case that produces a stream instead of a single value.
abstract interface class StreamUseCase<T, P> {
  Stream<Result<T>> call(P params);
}

/// A use case that computes its answer immediately, with nothing to fail.
///
/// Pure logic over data the caller already holds - no I/O, so neither a
/// `Future` nor a [Result] would carry any information.
abstract interface class SyncUseCase<T, P> {
  T call(P params);
}

/// Placeholder for use cases without parameters.
class NoParams {
  const NoParams();
}
