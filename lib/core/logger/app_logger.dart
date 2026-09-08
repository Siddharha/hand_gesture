import 'dart:developer' as developer;

/// Minimal logging seam. Swap the implementation (or override
/// `appLoggerProvider`) to route logs somewhere else without touching callers.
class AppLogger {
  const AppLogger({this.name = 'hand_gesture'});

  final String name;

  void debug(String message) => developer.log(message, name: name, level: 500);

  void info(String message) => developer.log(message, name: name, level: 800);

  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      developer.log(message, name: name, level: 1000, error: error, stackTrace: stackTrace);
}
