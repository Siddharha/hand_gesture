import '../../../../../core/result/result.dart';
import '../../../../../core/usecase/usecase.dart';
import '../repository/hand_tracking_repository.dart';

/// Releases the camera — called when the screen is backgrounded or disposed.
class StopHandTrackingUseCase implements UseCase<void, NoParams> {
  const StopHandTrackingUseCase(this._repository);

  final HandTrackingRepository _repository;

  @override
  Future<Result<void>> call(NoParams params) => _repository.stopTracking();
}
