import '../../../../../core/result/result.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entity/app_session_entity.dart';
import '../repository/splash_repository.dart';

/// Resolves the app session while the splash screen is on show.
class LoadAppSessionUseCase implements UseCase<AppSessionEntity, NoParams> {
  const LoadAppSessionUseCase(this._repository);

  final SplashRepository _repository;

  @override
  Future<Result<AppSessionEntity>> call(NoParams params) => _repository.loadSession();
}
