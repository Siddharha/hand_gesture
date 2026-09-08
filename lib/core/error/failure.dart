/// Errors as the domain and presentation layers see them.
///
/// A [Failure] is safe to show to a view model: it is free of transport
/// details and carries a message meant for the user.
sealed class Failure {
  const Failure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType(message: $message, cause: $cause)';
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {this.statusCode, super.cause});

  final int? statusCode;
}

class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.cause});
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message, {super.cause});
}

/// A permission the feature needs was refused. The UI should offer a way into
/// system settings rather than simply retrying.
class PermissionFailure extends Failure {
  const PermissionFailure(super.message, {this.permission, super.cause});

  final String? permission;
}

/// A device resource was unavailable or failed mid-use.
class DeviceFailure extends Failure {
  const DeviceFailure(super.message, {super.cause});
}
