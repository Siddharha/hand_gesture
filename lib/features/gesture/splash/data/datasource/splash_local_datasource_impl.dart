import '../../domain/datasource/splash_local_datasource.dart';
import '../../domain/entity/app_session_entity.dart';
import '../mapper/app_session_mapper.dart';
import '../model/app_session_model.dart';

/// In-memory stand-in for persisted flags.
///
/// TODO: read and write these through shared_preferences (or secure storage)
/// so the values survive a restart.
class SplashLocalDataSourceImpl implements SplashLocalDataSource {
  SplashLocalDataSourceImpl();

  AppSessionModel _session = const AppSessionModel(
    isFirstLaunch: true,
    isOnboardingCompleted: false,
  );

  @override
  Future<AppSessionEntity> readSession() async => AppSessionMapper.toEntity(_session);

  @override
  Future<void> markLaunched() async {
    _session = AppSessionModel(
      isFirstLaunch: false,
      isOnboardingCompleted: _session.isOnboardingCompleted,
    );
  }
}
