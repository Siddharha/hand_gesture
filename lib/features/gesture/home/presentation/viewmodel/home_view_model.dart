import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../data/di/home_di.dart';
import '../../domain/entity/camera_session_entity.dart';
import '../../domain/entity/gesture_event_entity.dart';
import '../../domain/entity/hand_detection_entity.dart';
import '../../domain/entity/hand_gesture_entity.dart';
import '../../domain/usecase/recognize_hand_gesture_usecase.dart';
import '../../domain/usecase/start_hand_tracking_usecase.dart';
import '../../domain/usecase/validate_hand_structure_usecase.dart';
import 'gesture_event_tracker.dart';
import 'gesture_stabilizer.dart';
import 'hand_structure_gate.dart';
import 'home_state.dart';

/// Owns the camera screen's state: start and stop the session, listen to
/// detections, keep the stats. It talks to use cases only — it has no idea
/// TFLite or CameraX exist.
///
/// Every write to [state] after an await checks `ref.mounted` first. Start and
/// stop are driven by app lifecycle callbacks as well as by the user, so they
/// routinely race a screen teardown, and writing to a disposed provider throws.
class HomeViewModel extends Notifier<HomeState> {
  StreamSubscription<void>? _detections;
  DateTime? _lastDetectionAt;
  final GestureStabilizer _gestures = GestureStabilizer();
  final GestureEventTracker _events = GestureEventTracker();
  final HandStructureGate _structure = HandStructureGate();

  /// Smoothing factor for the FPS readout. Low enough that the number is
  /// readable rather than flickering.
  static const _fpsSmoothing = 0.1;

  @override
  HomeState build() {
    ref.onDispose(() {
      _detections?.cancel();
      _detections = null;
    });
    return const HomeState();
  }

  /// Opens the camera and starts analysing. Safe to call repeatedly.
  Future<void> start({CameraLens lens = CameraLens.back}) async {
    if (state.status == CameraStatus.starting || state.isRunning) return;

    state = state.copyWith(status: CameraStatus.starting, clearFailure: true);

    final result = await ref.read(startHandTrackingUseCaseProvider)(
      StartHandTrackingParams(lens: lens),
    );
    if (!ref.mounted) return;

    state = result.fold(
      onSuccess: (session) => state.copyWith(
        status: CameraStatus.running,
        session: session,
        clearFailure: true,
      ),
      onError: _toErrorState,
    );

    if (state.isRunning) _listenForHands();
  }

  /// Releases the camera. Called when the screen is backgrounded or disposed —
  /// holding it open in the background is both rude and, on Android, likely to
  /// get the session taken away.
  Future<void> stop() async {
    await _detections?.cancel();
    _detections = null;
    _lastDetectionAt = null;
    _gestures.reset();
    _structure.reset();
    // Close out anything in flight, so a listener waiting on `ended` is not
    // left believing a gesture is still held.
    _publish(_events.reset());

    await ref.read(stopHandTrackingUseCaseProvider)(const NoParams());
    if (!ref.mounted) return;

    state = state.copyWith(
      status: CameraStatus.idle,
      detection: const HandDetectionEntity.empty(),
      poses: const <HandPoseEntity?>[],
      analysisFps: 0,
    );
  }

  Future<void> switchCamera() async {
    if (!state.isRunning) return;

    final result = await ref.read(switchCameraUseCaseProvider)(const NoParams());
    if (!ref.mounted) return;

    state = result.fold(
      onSuccess: (session) {
        _gestures.reset();
        _structure.reset();
        _publish(_events.reset());
        return state.copyWith(
          session: session,
          detection: const HandDetectionEntity.empty(),
          poses: const <HandPoseEntity?>[],
          clearFailure: true,
        );
      },
      onError: _toErrorState,
    );
  }

  void toggleOverlay() => state = state.copyWith(showOverlay: !state.showOverlay);

  /// Re-runs after a failure the user can do something about.
  Future<void> retry() async {
    await stop();
    await start(lens: state.session?.lens ?? CameraLens.back);
  }

  void _listenForHands() {
    _detections?.cancel();
    _detections = ref
        .read(observeHandDetectionsUseCaseProvider)(const NoParams())
        .listen((result) {
      if (!ref.mounted) return;
      result.fold(
        onSuccess: _onDetection,
        onError: (failure) => state = _toErrorState(failure),
      );
    });
  }

  void _onDetection(HandDetectionEntity detection) {
    final poses = _recognize(detection);
    _publish(_events.update(detection.hands, poses));

    state = state.copyWith(
      detection: detection,
      poses: poses,
      analysisFps: _nextFps(),
    );
  }

  /// Pushes gesture transitions out to whoever is listening.
  void _publish(List<GestureEventEntity> events) {
    if (events.isEmpty) return;

    final sink = ref.read(gestureEventSinkProvider);

    for (final event in events) {
      if (!sink.isClosed) sink.add(event);

      // print rather than the logger: dart:developer output does not reach adb
      // logcat, and seeing events land on a device is the whole point while
      // wiring an action up. Compiled out of release builds with the assert.
      assert(() {
        // ignore: avoid_print
        print('Gesture: $event');
        return true;
      }());
    }
  }

  /// Names the shape of each hand, then smooths it. Cheap enough to run inline:
  /// a few dozen distance comparisons against landmarks already in hand.
  ///
  /// A hand is only named once its skeleton has passed the structure check
  /// several frames running. Until then it comes back as `null` — drawn, but
  /// unnamed and silent — because a gesture read off a broken skeleton is a
  /// wrong answer, and a wrong answer fires an event that something acts on.
  List<HandPoseEntity?> _recognize(HandDetectionEntity detection) {
    if (detection.hands.isEmpty) {
      _gestures.reset();
      _structure.reset();
      return const <HandPoseEntity?>[];
    }

    // The landmarks are normalised per axis, so both checking a hand and
    // naming its shape need to know how the frame is shaped.
    final aspectRatio = state.session?.aspectRatio ?? 1.0;
    final validate = ref.read(validateHandStructureUseCaseProvider);
    final recognize = ref.read(recognizeHandGestureUseCaseProvider);

    final trusted = _structure.admit([
      for (final hand in detection.hands)
        validate(
          ValidateHandStructureParams(
            hand: hand,
            frameAspectRatio: aspectRatio,
          ),
        ),
    ]);

    return _gestures.stabilize([
      for (var i = 0; i < detection.hands.length; i++)
        if (trusted[i])
          recognize(
            RecognizeHandGestureParams(
              hand: detection.hands[i],
              frameAspectRatio: aspectRatio,
            ),
          )
        else
          null,
    ]);
  }

  /// Exponential moving average over the gaps between analysed frames.
  double _nextFps() {
    final now = DateTime.now();
    final last = _lastDetectionAt;
    _lastDetectionAt = now;

    if (last == null) return state.analysisFps;

    final gap = now.difference(last).inMicroseconds;
    if (gap <= 0) return state.analysisFps;

    final instant = 1000000 / gap;
    if (state.analysisFps == 0) return instant;
    return state.analysisFps * (1 - _fpsSmoothing) + instant * _fpsSmoothing;
  }

  HomeState _toErrorState(Failure failure) => state.copyWith(
        status: failure is PermissionFailure
            ? CameraStatus.permissionDenied
            : CameraStatus.failure,
        failure: failure,
      );
}

final homeViewModelProvider = NotifierProvider<HomeViewModel, HomeState>(
  HomeViewModel.new,
);
