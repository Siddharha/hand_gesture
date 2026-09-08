import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logger/app_logger.dart';

/// Providers shared by every feature. Feature-local wiring lives in that
/// feature's own `data/di` file.
final appLoggerProvider = Provider<AppLogger>((ref) => const AppLogger());
