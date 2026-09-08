import '../../../../../core/result/result.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entity/camera_session_entity.dart';
import '../repository/hand_tracking_repository.dart';

/// Flips between the front and back camera without tearing the session down.
class SwitchCameraUseCase implements UseCase<CameraSessionEntity, NoParams> {
  const SwitchCameraUseCase(this._repository);

  final HandTrackingRepository _repository;

  @override
  Future<Result<CameraSessionEntity>> call(NoParams params) =>
      _repository.switchCamera();
}
