# Camera counter domain

Pure Dart; no Flutter, camera, ML Kit or network dependency. Import
`domain/camera_counter.dart` to use the public API.

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
