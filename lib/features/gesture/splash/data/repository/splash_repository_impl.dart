import '../../../../../core/error/app_exception.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/result/result.dart';
import '../../domain/datasource/splash_local_datasource.dart';
import '../../domain/entity/app_session_entity.dart';
import '../../domain/repository/splash_repository.dart';

class SplashRepositoryImpl implements SplashRepository {
  const SplashRepositoryImpl({required this.localDataSource});

  final SplashLocalDataSource localDataSource;

  @override
  Future<Result<AppSessionEntity>> loadSession() async {
    try {
      final session = await localDataSource.readSession();
      await localDataSource.markLaunched();
      return Result.success(session);
    } on CacheException catch (e) {
      return Result.error(CacheFailure(e.message, cause: e));
    } on AppException catch (e) {
      return Result.error(UnexpectedFailure(e.message, cause: e));
    } catch (e) {
      return Result.error(
        UnexpectedFailure('Could not start the app session.', cause: e),
      );
    }
  }
}
