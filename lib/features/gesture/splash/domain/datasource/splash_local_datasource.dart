import '../entity/app_session_entity.dart';

/// Contract for the persisted flags the splash screen reads on start-up.
abstract interface class SplashLocalDataSource {
  Future<AppSessionEntity> readSession();

  Future<void> markLaunched();
}
