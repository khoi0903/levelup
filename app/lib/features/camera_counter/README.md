# Camera counter

Pure Dart; no Flutter, camera, ML Kit or network dependency. Import
`domain/camera_counter.dart` to use the public API.
This describes `domain/`; the `data/` layer now connects the native camera and
ML Kit, and `presentation/` contains an isolated debug screen.

## Connecting the camera later

```dart
final config = CvConfig.fromJson(exerciseCvConfig);
final counter = RepCounter(config: config);
final clock = Stopwatch()..start();

// Adapt ML Kit landmark names to PoseLandmarkType. Use pixel coordinates,
// or another coordinate system with the same scale for x and y.
final result = counter.addFrame(PoseFrame(
  timestamp: clock.elapsed,
  landmarks: adaptedLandmarks,
));
final form = const FormChecker().checkSquats(result.reps);
// result.repCount, result.averageConfidence, result.reps
// form.formScore, form.issues.map((issue) => issue.toJson())

// Also run this on a UI timer, even when camera frames stop arriving.
final presence = counter.checkPresence(clock.elapsed);
// Pause the UI when presence.personMissing is true.
```

Use one monotonically increasing session clock for frames and timer calls.
Frame timestamps must strictly increase and cannot precede a timer check.
Create a new counter and clock for a new set/session.

## Counting and confidence

- `joints` is an ordered triplet; its middle joint is the angle vertex.
- Each frame selects the usable side with the higher mean triplet likelihood
  (left wins ties). Every joint must meet `minConfidence`. Missing joints,
  nonfinite coordinates, zero-length vectors and likelihood outside [0, 1]
  make that side unusable. A usable opposite side is still accepted.
- Two consecutive usable frames must be strictly below `downBelow` or strictly
  above `upAbove`. Equality and frames in between reset that transition's
  debounce. An unusable frame also resets debounce, but short gaps preserve
  the active rep and its deepest angle.
- Initially, and after losing the person, two up frames are required to arm
  counting. A session starting crouched cannot count a partial initial rep.
- Duration uses the first downward crossing in the confirmed pair and the
  first upward crossing in the confirmed pair. A duration equal to `minRepMs`
  counts; shorter reps are discarded. Rep indices start at 1.
- `averageConfidence` averages accepted frames for the session, including up
  frames; it is zero before any accepted frame. Each rep also has its own
  average and the minimum angle observed during that completed rep.
- More than 1 second since the last usable frame (or session start if none)
  sets `personMissing` and cancels incomplete reps. A new usable frame clears
  the flag; counting must first re-arm. Completed reps remain available.
- Result lists and pose-frame landmark maps are immutable snapshots.

## Squat depth and score

Only pass knee-angle squat reps to `FormChecker.checkSquats`. A deepest knee
angle strictly greater than 100 degrees yields `shallow_depth`. Severity is
1 through 110 degrees, 2 through 120 degrees, and 3 above 120 degrees.
`formScore = round(100 - sum(10 * severity) / repCount)`, clamped to 0–100.
No recorded reps means no recorded issues and score 100; the UI should use
`repCount` to distinguish an empty set from a successfully completed set.
These severity bands and the score are explicit local scoring conventions.

The sample configuration `downBelow: 95` only detects squats deeper than
95 degrees, so its accepted reps cannot have `shallow_depth`. To detect and
grade shallower cycles, supply an exercise config with a wider threshold;
the shallow-squat test uses `downBelow: 120`. The checker never adds reps
that did not complete the counter's state machine.

## Tests

From `app/`: `flutter test test/features/camera_counter`.
Synthetic frames cover standard/shallow squats, jitter, fast motion,
alternating confidence and sides, missing/invalid geometry, loss/recovery,
timestamp ordering, JSON validation, and immutable results.

## Native camera session (squats)

```dart
import 'package:fitness_app/features/camera_counter/data/camera_rep_session.dart';
import 'package:fitness_app/features/camera_counter/domain/cv_config.dart';

final session = CameraRepSession(config: CvConfig.fromJson(exerciseCvConfig));
final subscription = session.results.listen((result) {
  // repCount, personMissing, averageConfidence, formScore, issues, status, error
  // Use session.cameraController with CameraPreview for the live preview.
});
await session.start();
await session.pause(); // Releases camera, cancels partial rep, retains completed reps.
await session.start(); // Reopens front camera and resumes this set.
await session.stop();  // Terminal: releases camera and ML Kit; closes results.
await subscription.cancel();
```

Subscribe before `start()`. `latestResult` holds the latest immutable result,
including before the first camera frame. The stream is broadcast and emits
camera/processing failures through `result.error`; failed start/pause/stop
operations also return a failed Future for the UI to handle. Stop is idempotent;
create a new session after stop to start a new set. Current form scoring supports
hip–knee–ankle squat configurations only.

The camera opens at medium resolution, front-facing, with audio disabled.
Android requests camera access with `permission_handler`; iOS uses the camera
plugin's permission request. Android streams packed NV21 (CameraX supports it),
iOS streams BGRA. Image metadata compensates Android sensor/device rotation;
pixel coordinates are copied into domain without normalization or mirroring.
Unexpected/truncated image formats surface an error instead of feeding corrupt
data into the detector. No file capture, video recording or upload API is used.

ML Kit runs in stream mode. Only one native inference is in flight; newer frames
are discarded instead of queued. A Stopwatch supplies both frame-delivery times
and the 100 ms presence timer, avoiding out-of-order timestamps after async
inference. Results older than one second are discarded. An empty ML Kit pose
result becomes an empty PoseFrame, so domain handles the absence normally.

On app background/inactive, call `pause()` to release the camera. On return,
call `start()` when the user is ready. Dispose the session with `stop()` when
leaving F2b. An inference completing after pause/stop cannot update the set.
`personMissing` does not automatically stop detection: keep listening so a
returning person can be detected; the UI can suspend its workout timer instead.

Platform configuration:

- Android declares CAMERA and uses minSdk at least 24 (camera requires 24,
  ML Kit requires 21). The camera feature is optional, allowing a useful error
  when a front camera is unavailable.
- iOS has NSCameraUsageDescription. The current Xcode deployment target is
  15.0; **ML Kit requires iOS 15.5 or later**, so the owner must raise that target
  before building iOS. Runner.xcodeproj and Podfile were outside this task's
  authorized edit scope. iOS native compilation is unverified on Windows.
- Only the three authorized direct dependencies were added. The tracked
  pubspec.lock was kept unchanged because it was outside the allowed files;
  run `flutter pub get` after pulling this branch to resolve the new packages.

Sources: [camera setup](https://pub.dev/packages/camera),
[CameraX NV21 support](https://pub.dev/packages/camera_android_camerax),
[ML Kit platform requirements](https://pub.dev/packages/google_mlkit_pose_detection).

## Run the isolated debug screen on Android

From `app/`, with USB debugging enabled on a connected phone:

```sh
flutter pub get
flutter devices
flutter run -d <device-id> -t lib/features/camera_counter/presentation/debug_counter_main.dart
```

Allow camera access. Stand far enough away that shoulders, hips, knees and
ankles are visible; turn sideways to expose the knee angle. Start with two
upright frames, then squat slowly. The debug default uses downBelow=120 so
shallow reps can be graded too. Pass another CvConfig to DebugCounterScreen
to test the actual exercise config (e.g. downBelow=95).

The screen shows preview, rep count, confidence, knee angle, depth score and
warnings; Pause keeps the count, Continue reopens the camera, and End closes
the set. Start after End creates a fresh set. Backgrounding the app pauses
it; tap Continue after returning. This entrypoint does not change the app router.

Device-free native-layer tests cover the adapter (all/missing/low-confidence
joints), packed-image metadata and rotation, busy-frame dropping, presence
checks during inference, stale results, pause/resume, initialization races,
permission failure and resource cleanup. Hardware preview/pose accuracy must
still be tested on a real phone.
