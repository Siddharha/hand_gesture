# hand_gesture

Flutter app structured as **feature > module > layer**, with Riverpod for state
and dependency injection and MVVM in the presentation layer.

## Structure

```
assets/
└── models/                       # bundled TFLite models (see Resources)
    ├── hand_detector.tflite
    ├── hand_landmark_detector.tflite
    └── metadata.json
lib/
├── main.dart                     # installs ProviderScope, runs HandGestureApp
├── app/
│   ├── app.dart                  # MaterialApp: theme + routing
│   ├── router/                   # app_routes.dart (names), app_router.dart (map)
│   └── theme/                    # app_theme.dart (light/dark)
├── core/                         # shared across features
│   ├── di/                       # app-wide providers
│   ├── error/                    # AppException (data), Failure (domain)
│   ├── logger/
│   ├── ml/                       # anchors, NMS, ROI geometry, frame sampler
│   ├── resources/                # asset paths + TFLite tensor contracts
│   ├── result/                   # Result<T> = Success | Error
│   ├── usecase/                  # UseCase<T, P>, NoParams
│   └── widgets/                  # AppScaffold
└── features/
    └── gesture/                  # feature
        ├── splash/               # module
        │   ├── data/
        │   │   ├── datasource/   # SplashLocalDataSourceImpl
        │   │   ├── di/           # splash_di.dart — Riverpod wiring
        │   │   ├── mapper/       # model <-> entity
        │   │   ├── model/        # AppSessionModel (json/storage shape)
        │   │   └── repository/   # SplashRepositoryImpl
        │   ├── domain/
        │   │   ├── datasource/   # SplashLocalDataSource (contract)
        │   │   ├── entity/       # AppSessionEntity
        │   │   ├── repository/   # SplashRepository (contract)
        │   │   └── usecase/      # LoadAppSessionUseCase
        │   └── presentation/
        │       ├── view/         # SplashScreen (empty)
        │       ├── viewmodel/    # SplashViewModel + SplashState
        │       └── widgets/
        └── home/                 # module - live camera + hand tracking
            ├── data/
            │   ├── datasource/   # CameraX camera, TFLite pipeline + isolate
            │   ├── di/
            │   ├── mapper/       # CameraImage -> entity, landmarks -> entity
            │   ├── model/        # raw tensor decoders
            │   └── repository/
            ├── domain/           # datasource, entity, repository, usecase
            └── presentation/     # preview view, view model, overlay painter
```

## How the layers talk

```
View ──intent──> ViewModel ──> UseCase ──> Repository ──> DataSource
     <──state───            <── Result<T> ──            <── Model→Entity
```

- **domain** depends on nothing. It declares the contracts (`repository/`,
  `datasource/`) and the business logic (`usecase/`) over entities.
- **data** implements those contracts. `model/` holds transport shapes,
  `mapper/` converts them to entities, `repository/` turns `AppException` into
  `Failure`, and `di/` binds every implementation to its abstraction.
- **presentation** holds the MVVM pieces: a `Notifier` view model owning an
  immutable state class, and a `ConsumerWidget` view that only reads state and
  fires intents.

Nothing throws across a layer boundary — repositories and use cases return
`Result<T>`, which the view model folds into its state.

## Resources

The MediaPipe hand models live in `assets/models/` and are declared once in
`pubspec.yaml`. Nothing else refers to them by string:

- [core/resources/app_assets.dart](lib/core/resources/app_assets.dart) — the
  only place asset paths are written.
- [core/resources/tflite_model_spec.dart](lib/core/resources/tflite_model_spec.dart)
  — a model's asset path, input shape, normalisation range and output shapes.
- [core/resources/hand_model_resources.dart](lib/core/resources/hand_model_resources.dart)
  — the two specs, transcribed from `metadata.json`.

| Model | Input | Outputs |
| --- | --- | --- |
| `hand_detector` | `[1, 256, 256, 3]` float, 0–1 | `box_coords [1, 2944, 18]`, `box_scores [1, 2944, 1]` |
| `hand_landmark_detector` | `[1, 256, 256, 3]` float, 0–1 | `scores [1]`, `lr [1]`, `landmarks [1, 21, 3]` |

Detection is two-stage: the detector finds hand boxes in a frame, then the
landmark detector runs on each crop and returns 21 normalised `(x, y, z)`
points plus handedness (`lr`: 0 = left, 1 = right).

`test/core/hand_model_resources_test.dart` asserts the models are bundled and
that these specs still match `metadata.json`, so swapping in new models fails
loudly instead of silently producing garbage tensors.

No inference engine is wired up yet — add `tflite_flutter` and load
`HandModelResources.detector.assetPath` when you build that datasource.

## Adding a module

1. `lib/features/<feature>/<module>/{data,domain,presentation}` with the
   sub-folders above.
2. Write the domain contracts and entities first, then the data
   implementations, then `data/di/<module>_di.dart`.
3. Add the view model + state, and register the screen in
   [app_routes.dart](lib/app/router/app_routes.dart) and
   [app_router.dart](lib/app/router/app_router.dart).

## Hand tracking

`home` is a live camera preview with the hand skeleton drawn over it. The
pipeline is a port of MediaPipe's two-stage design:

```
CameraX frame ──> sample rotated ROI ──> palm detector ──> hand crop
                                                             │
     overlay <── landmarks in frame space <── landmark model ─┘
                          │
                          └─> crop for the NEXT frame (skips the detector)
```

Stage 1 (`hand_detector`) is expensive and runs only when tracking is lost, or
every `redetectInterval` frames to notice a hand that has just entered. Stage 2
(`hand_landmark_detector`) runs on a crop derived from the previous frame's
landmarks — that feedback loop is what makes per-frame tracking affordable.

**Where the work happens.** Both inference and the YUV→RGB sampling that feeds
it run in a dedicated isolate ([hand_pipeline_isolate.dart](lib/features/gesture/home/data/datasource/hand_pipeline_isolate.dart)),
so neither stalls the UI thread. One frame is in flight at a time; frames that
arrive while the pipeline is busy are dropped rather than queued, because a
queue would only add latency. A dropped frame emits nothing, so the overlay
holds its last position instead of flickering.

**Sampling.** [frame_sampler.dart](lib/core/ml/frame_sampler.dart) walks each
output pixel back through the ROI rotation and the sensor rotation to a source
pixel and converts it there — no intermediate RGB bitmap, no separate resize.
Coordinates are in *upright* space (after sensor rotation and front-camera
mirroring), so landmarks land in the same space the preview is drawn in.

**The constants matter.** The palm detector emits offsets against a fixed
anchor grid; [ssd_anchors.dart](lib/core/ml/ssd_anchors.dart) rebuilds that grid
(strides `[8,16,32,32,32]` → exactly 2944 anchors, asserted in tests). The crop
in [hand_roi.dart](lib/core/ml/hand_roi.dart) keeps MediaPipe's scale/shift
constants under their original names. Getting either wrong yields landmarks
that are subtly and persistently off rather than obviously broken.

**Orientation.** The app is locked to portrait, which is what lets a frame's
rotation be described by the sensor orientation alone. Supporting landscape
means folding device orientation into `CameraFrameEntity.rotationDegrees`.

### Performance

Measured on a physical device (Android 15, 720×480 stream, release build):

Measured on a physical device, release build, 720×480 stream, one hand tracked:

| | Per frame | Analysis rate | Capture-to-overlay lag |
| --- | --- | --- | --- |
| Before | ~70 ms | ~10 fps | unbounded, grew over time |
| After | ~34 ms | ~26 fps | ~36 ms |

Three changes got there, in order of how much they mattered:

**1. Frames were queueing, not dropping.** The consumer used `asyncMap`, which
serialises by pausing its subscription — and a broadcast controller *buffers*
for a paused subscriber. The camera produces ~30fps and the pipeline consumed
~10fps, so two frames in three piled up in that buffer and every analysed frame
was older than the last: the overlay fell progressively further behind rather
than simply running at a lower frame rate. The datasource's own "drop while
busy" check never even fired, because `asyncMap` never called it concurrently.
The repository now keeps only the newest frame and discards whatever arrived
behind it. This is what fixed the *lag*, as opposed to the frame rate.

**2. The GPU delegate was running fp32 at maximum precision.** Its defaults are
`isPrecisionLossAllowed: false` and `MAX_PRECISION` — the wrong trade for
detection models feeding an overlay. Allowing fp16 and asking for `MIN_LATENCY`
roughly halved the GPU pass. Raising `maxDelegatePartitions` from its default
of 1 also matters here: the detector splits into several partitions because one
`TRANSPOSE_CONV` version is unsupported, and the cap left the remainder on the
CPU. Delegated node count went from 129/149 to 147/149.

**3. Sampling was made allocation-free**, with fixed-point YUV→RGB and the
interpreter's input buffer written in place. This turned out to be the *least*
important: profiling showed sampling was only 1-2 ms of a ~90 ms frame. Worth
keeping, but it is not where the time was — which is exactly why the split is
measured rather than assumed.

A detector pass still costs several times a tracked frame, so `redetectInterval`
is a visible hitch rather than a background cost. It defaults to 90 frames; at
30 it fired about once a second while a single hand was tracked, which read as
stutter.

The GPU delegate is preferred and falls back to CPU automatically when a device
cannot provide it. Tuning knobs live in `HandPipelineConfig` — override
`handPipelineConfigProvider` to change them; `maxHands: 1` roughly halves the
cost when two hands are in view.

The on-screen stats bar carries the numbers that matter for responsiveness:
**Inference** is time in the pipeline, **Lag** is the age of the frame when its
result reached the overlay. Lag close to inference means nothing is queueing;
lag drifting above it means frames are backing up somewhere.

### Gesture recognition

The 21 landmarks are enough to name hand shapes without a second model.
[recognize_hand_gesture_usecase.dart](lib/features/gesture/home/domain/usecase/recognize_hand_gesture_usecase.dart)
works entirely in ratios between distances, so a reading holds regardless of
hand size, distance from the camera, or rotation — no pixel thresholds, and no
assumption that the hand is upright.

- **Fingers** are judged by *straightness*: the knuckle-to-tip chord divided by
  the distance travelled along the finger. Straight scores 1.0, curled drops
  well below; the cut is at 0.80.
- **The thumb** needs its own test, because it barely curls — it folds *across*
  the palm. It is measured by how far its tip sits from the pinky knuckle
  compared to its own knuckle: tucked, the tip moves inward and the ratio falls
  below 1.
- **Landmarks are normalised per axis**, so a step of 0.1 is a different number
  of pixels horizontally and vertically. Distances are corrected by the frame
  aspect ratio before anything is compared.

Named shapes: fist, thumbs up/down, one, two, three, four, open palm, rock on,
shaka, finger gun, and OK. Anything else reports its finger count instead
("3 fingers"), so the readout is never blank. Adding a gesture means adding a
row to the pattern switch in `_classify`.

Raw per-frame classification flickers at ~26fps, so
[gesture_stabilizer.dart](lib/features/gesture/home/presentation/viewmodel/gesture_stabilizer.dart)
holds a label until a new one has been seen for three consecutive frames —
about a tenth of a second, per hand.

The thresholds are named constants at the top of the use case. They are checked
against synthetic hands in `test/features/gesture/home/gesture_recognizer_test.dart`;
if real hands read wrong at the margins, those constants are the dials.

### Two things the models do differently from stock MediaPipe

Both were found by instrumenting the pipeline on a device, and both fail
silently rather than loudly:

1. **The landmark model emits normalised coordinates, not input pixels.** Stock
   `hand_landmark.tflite` returns landmarks in input pixels; this conversion
   returns `[0, 1]`. Dividing by the input size a second time collapses every
   hand to a speck at the origin — the landmark stage then scores ~0.006 on its
   own crop, so tracking can never hold and the palm detector re-fires every
   other frame. `HandLandmarkDecoder` asserts against the opposite mistake if
   the models are ever swapped.
2. **Output tensors are matched to roles by shape and name, not position.**
   Tensor order is not guaranteed across conversions, and `scores` and `lr`
   share a shape — swapping them rejects every hand. Debug builds print the
   resolved binding so it can be checked against `metadata.json`.

### Diagnostics

Debug builds print the resolved output-tensor bindings and a per-frame summary,
visible over `adb logcat -s flutter:I`:

```
HandPipeline detector outputs: box_coords -> [0] box_coords [1, 2944, 18], ...
HandPipeline frame 30 stage=track rois=1 kept=1 scores=[1.000] rot=0.05 roi=1.75
```

Both are compiled out of release builds. `stage` says whether the frame ran the
detector or tracked from the previous one; `scores` is every landmark
confidence, kept or not, which is the first thing to look at when hands are
found but immediately dropped; `rot` is the crop rotation, which should stay
steady while a hand is held still.

## Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run                       # a physical device: no camera on an emulator
adb logcat -s flutter:I           # pipeline diagnostics
```

The camera needs a real device. Permissions are declared in
`AndroidManifest.xml` and `Info.plist`; the `camera` plugin raises the runtime
prompt on first use and a refusal surfaces as `PermissionFailure`.
