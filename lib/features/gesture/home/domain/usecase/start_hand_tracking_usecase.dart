import '../../../../../core/result/result.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entity/camera_session_entity.dart';
import '../repository/hand_tracking_repository.dart';

class StartHandTrackingParams {
  const StartHandTrackingParams({this.lens = CameraLens.back});

  final CameraLens lens;
}

/// Opens the camera and loads the models.
class StartHandTrackingUseCase
    implements UseCase<CameraSessionEntity, StartHandTrackingParams> {
  const StartHandTrackingUseCase(this._repository);

  final HandTrackingRepository _repository;

  @override
  Future<Result<CameraSessionEntity>> call(StartHandTrackingParams params) =>
      _repository.startTracking(lens: params.lens);
}
