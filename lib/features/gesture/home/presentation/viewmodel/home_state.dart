import '../../../../../core/error/failure.dart';
import '../../domain/entity/camera_session_entity.dart';
import '../../domain/entity/hand_detection_entity.dart';
import '../../domain/entity/hand_gesture_entity.dart';

enum CameraStatus {
  /// Nothing started yet, or the screen was backgrounded.
  idle,

  /// Opening the camera and loading the models.
  starting,

  /// Frames are flowing.
  running,

  /// The user refused camera access — retrying alone will not help.
  permissionDenied,

  /// Anything else went wrong; [HomeState.failure] says what.
  failure,
}

/// Everything the camera screen draws, and nothing else.
class HomeState {
  const HomeState({
    this.status = CameraStatus.idle,
    this.session,
    this.detection = const HandDetectionEntity.empty(),
    this.poses = const <HandPoseEntity?>[],
    this.confidences = const <double?>[],
    this.failure,
    this.showOverlay = true,
    this.analysisFps = 0,
  });

  final CameraStatus status;
  final CameraSessionEntity? session;

  /// The most recent detection. Frames dropped while the pipeline is busy do
  /// not clear this, so the overlay stays put instead of flickering.
  final HandDetectionEntity detection;

  /// The shape each hand in [detection] is making, index-aligned with
  /// `detection.hands` and smoothed so the label does not flicker.
  ///
  /// `null` where a hand is on screen but not yet trusted: its skeleton has
  /// not held together for enough frames to name a shape from.
  final List<HandPoseEntity?> poses;

  /// How confident the model was about each hand on the frame that admitted
  /// it, index-aligned with `detection.hands` and `null` wherever [poses] is.
  ///
  /// The frame the gate decided on, not the current one: the number is the
  /// evidence the hand was trusted on, so it holds still while the hand is
  /// held rather than twitching every frame.
  final List<double?> confidences;

  final Failure? failure;
  final bool showOverlay;

  /// Smoothed frames-per-second actually analysed, for the stats readout.
  final double analysisFps;

  bool get isRunning => status == CameraStatus.running;

  bool get isBusy => status == CameraStatus.starting;

  bool get hasHands => detection.hasHands;

  bool get canRetry => status == CameraStatus.failure;

  HomeState copyWith({
    CameraStatus? status,
    CameraSessionEntity? session,
    HandDetectionEntity? detection,
    List<HandPoseEntity?>? poses,
    List<double?>? confidences,
    Failure? failure,
    bool? showOverlay,
    double? analysisFps,
    bool clearFailure = false,
  }) {
    return HomeState(
      status: status ?? this.status,
      session: session ?? this.session,
      detection: detection ?? this.detection,
      poses: poses ?? this.poses,
      confidences: confidences ?? this.confidences,
      failure: clearFailure ? null : (failure ?? this.failure),
      showOverlay: showOverlay ?? this.showOverlay,
      analysisFps: analysisFps ?? this.analysisFps,
    );
  }
}
