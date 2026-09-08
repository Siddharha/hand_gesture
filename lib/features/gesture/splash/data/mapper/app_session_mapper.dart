import '../../domain/entity/app_session_entity.dart';
import '../model/app_session_model.dart';

abstract final class AppSessionMapper {
  static AppSessionEntity toEntity(AppSessionModel model) => AppSessionEntity(
        isFirstLaunch: model.isFirstLaunch,
        isOnboardingCompleted: model.isOnboardingCompleted,
      );

  static AppSessionModel toModel(AppSessionEntity entity) => AppSessionModel(
        isFirstLaunch: entity.isFirstLaunch,
        isOnboardingCompleted: entity.isOnboardingCompleted,
      );
}
