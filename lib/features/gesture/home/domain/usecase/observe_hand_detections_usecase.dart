import '../../../../../core/result/result.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entity/hand_detection_entity.dart';
import '../repository/hand_tracking_repository.dart';

/// The stream the view model listens to while the camera runs.
class ObserveHandDetectionsUseCase
    implements StreamUseCase<HandDetectionEntity, NoParams> {
  const ObserveHandDetectionsUseCase(this._repository);

  final HandTrackingRepository _repository;

  @override
  Stream<Result<HandDetectionEntity>> call(NoParams params) =>
      _repository.observeDetections();
}
