import '../../../../../core/result/result.dart';
import '../entity/app_session_entity.dart';

abstract interface class SplashRepository {
  /// Reads the stored session and records that the app has now been launched.
  Future<Result<AppSessionEntity>> loadSession();
}
