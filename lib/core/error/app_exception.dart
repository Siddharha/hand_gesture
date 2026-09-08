/// Exceptions thrown by the data layer (datasources).
///
/// They never cross the repository boundary: a repository catches them and
/// converts them into a [Failure] carried by a `Result`.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType(message: $message, cause: $cause)';
}

/// A remote datasource could not be reached or answered with an error.
class RemoteException extends AppException {
  const RemoteException(super.message, {this.statusCode, super.cause});

  final int? statusCode;
}

/// A local datasource (cache, database, preferences) failed.
class CacheException extends AppException {
  const CacheException(super.message, {super.cause});
}

/// A payload could not be parsed into a model.
class ParsingException extends AppException {
  const ParsingException(super.message, {super.cause});
}

/// The user denied a permission the feature needs.
class PermissionException extends AppException {
  const PermissionException(super.message, {this.permission, super.cause});

  final String? permission;
}

/// A device resource (camera, sensor, accelerator) was unavailable or failed.
class DeviceException extends AppException {
  const DeviceException(super.message, {super.cause});
}
