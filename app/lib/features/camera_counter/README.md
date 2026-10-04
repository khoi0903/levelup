# Camera counter

`domain/` is pure Dart (no Flutter, camera, ML Kit or network). Import
`domain/camera_counter.dart` for the public API. `data/` connects the native
camera and ML Kit; `presentation/` contains an isolated debug screen.

One generic engine handles every supported exercise: a 3-joint angle, a
direction (flex/extend), a mode (reps/hold), a side policy, optional body
orientation check and a list of form rules — all read from the exercise's
`cv.configs[].config` JSON (`mongo/cv-configs.json`).

## Supported exercises

Configs live in `mongo/cv-configs.json` (key = exercise slug, `activeVersion`
selects the config). `mongo/seed/exercises.json` marks `cv.supported`; a test
keeps the two in sync. Angles are in degrees; "rest/active" = thresholds
`downBelow`/`upAbove` (hold: `holdMin`–`holdMax`).

| Bài (slug) | Hỗ trợ | Mode | Direction | Khớp (đỉnh ở giữa) | Side | Máy | Đặt máy | Ngưỡng | Luật tư thế |
|---|---|---|---|---|---|---|---|---|---|
| bodyweight-squat | ✔ | reps | flex | hip–knee–ankle | auto | side | – | <95 / >160 | shallow_depth (gối sâu nhất >100°) |
| goblet-squat | ✔ | reps | flex | hip–knee–ankle | auto | side | floor_side | <110 / >160 | shallow_depth >100° |
| reverse-lunge | ✔ | reps | flex | hip–knee–ankle | min | side | floor_side | <115 / >160 | lunge_not_deep_enough >100° |
| glute-bridge | ✔ | reps | extend | shoulder–hip–knee | auto | side | floor_side | <150 / >162 | bridge_hips_not_high_enough (đỉnh <170°) |
| push-up | ✔ | reps | flex | shoulder–elbow–wrist | auto | side | floor_side | <110 / >150, thân nằm ngang ±40° | pushup_not_deep_enough >90°; body_not_straight (vai–hông–cổ chân ngoài 160–180°) |
| wall-push-up | ✔ | reps | flex | shoulder–elbow–wrist | auto | side | table_side | <115 / >150 | pushup_not_deep_enough >95°; body_not_straight 160–180° |
| jumping-jack | ✔ | reps | extend | hip–shoulder–elbow | both | front | floor_front | <50 / >110 | arms_not_overhead (đỉnh <140°) |
| dumbbell-shoulder-press | ✔ | reps | extend | shoulder–elbow–wrist | both | front | table_front | <110 / >150 | press_not_locked_out (đỉnh <165°) |
| dumbbell-biceps-curl | ✔ | reps | flex | shoulder–elbow–wrist | auto | side | table_side | <70 / >145 | curl_not_full_range >55° |
| dumbbell-bent-over-row | ✔ | reps | flex | shoulder–elbow–wrist | auto | side | floor_side | <110 / >150 | row_not_high_enough >95° |
| seated-resistance-band-row | ✔ | reps | flex | shoulder–elbow–wrist | auto | side | floor_side | <110 / >150 | row_not_high_enough >95° |
| standing-calf-raise | ✔ | reps | extend | knee–ankle–footIndex | auto | side | floor_side | <125 / >135 | heels_not_high_enough (đỉnh <145°) |
| side-lying-leg-raise | ✔ | reps | flex | shoulder–hip–knee | min | front | floor_front | <158 / >168 | leg_not_high_enough >145° |
| plank | ✔ | hold | – | shoulder–hip–ankle | auto | side | floor_side | giữ 150–180, thân nằm ngang ±35° | body_not_straight (ngoài 165–180° >10% thời gian) |
| wall-sit | ✔ | hold | – | hip–knee–ankle | auto | side | floor_side | giữ 65–120 | knee_not_at_90 (ngoài 80–100° >10% thời gian) |
| dead-bug | ✘ | | | | | | | | Nằm ngửa, tay–chân đối bên chuyển động chéo: nhìn nghiêng hai bên che nhau, một góc 2D không biết bên nào đang duỗi. |
| bird-dog | ✘ | | | | | | | | Tư thế bò, duỗi tay–chân đối bên: tay/chân phía xa bị thân che; cần đo thăng bằng hông mà một góc khớp không thể hiện. |
| march-in-place | ✘ | | | | | | | | Nhìn trước, gối nâng chủ yếu theo chiều sâu nên góc 2D đổi ít; nhịp nhanh, luân phiên → cần đếm theo vị trí gối, chưa có. |
| step-jack | ✘ | | | | | | | | Bước ngang luân phiên biên độ nhỏ kèm đưa tay; cần đếm theo khoảng cách cổ chân chứ không phải góc khớp. |
| dumbbell-floor-press | ✘ | | | | | | | | Nằm sàn: nhìn nghiêng thân che tay xa, nhìn trước thì khuỷu gập trong mặt phẳng ngang nên góc 2D sai lệch lớn. |

Every config has a Vietnamese `setupTipVi` (shown to the user before the set)
and `placement` (`floor_side`, `table_front`, ...) refining `cameraPosition`.
Tất cả ngưỡng là **ước lượng ban đầu** chưa đo trên máy thật (xem cuối file).

### Nguồn tham khảo ngưỡng góc

- Đếm lần bằng góc khớp và ngưỡng có trễ (hysteresis) giữa hai tư thế:
  [ML Kit – Pose classification options](https://developers.google.com/ml-kit/vision/pose-detection/classifying-poses)
  và [ML Kit Pose Detection](https://developers.google.com/ml-kit/vision/pose-detection)
  (33 điểm, gồm heel/footIndex dùng cho nhón gót).
- Squat/lunge: độ sâu "song song" ứng với gối ~90°; dừng sớm ở >100–110° là
  squat nông. Schoenfeld B.J., *Squatting kinematics and kinetics and their
  application to exercise performance*, J Strength Cond Res 24(12), 2010.
- Hít đất: khuỷu gập tới ~90° và thân thẳng là tiêu chí một lần hợp lệ của bài
  test hít đất trong ACSM's Guidelines for Exercise Testing and Prescription.
- Wall sit: gối và hông ~90° (bài test ngồi tựa tường thường dùng); dải
  80–100° là sai số chấp nhận được, 65–120° là còn tính giờ.
- Plank, glute bridge: vai–hông–gối/cổ chân gần thẳng hàng (~170–180°) theo
  mô tả bài tập của ACE (American Council on Exercise) Exercise Library.
- Đẩy vai, cuốn tay, kéo tạ, nhón gót, jumping jack, nâng chân nằm nghiêng:
  biên độ khớp theo mô tả kỹ thuật chuẩn (duỗi gần hết khuỷu ~165°+, cuốn
  tới ~55°, kéo khuỷu ra sau ≤95°, tay qua đầu ≥140° so với thân). Ngưỡng đếm
  đặt cách nhau ≥10° để khử rung; ngưỡng lỗi chặt hơn ngưỡng đếm để lần tập
  nông vẫn được đếm nhưng bị chấm lỗi.

## Config schema (`cv.configs[].config`)

| Field | Default | Meaning |
|---|---|---|
| `joints` | required | 3 of `shoulder, elbow, wrist, hip, knee, ankle, heel, footIndex`; middle = vertex |
| `downBelow`, `upAbove` | required for reps | `0 < downBelow < upAbove < 180` |
| `minConfidence` | required | per-joint likelihood in [0, 1] |
| `minRepMs` | required for reps, 0 for hold | shorter reps are discarded |
| `direction` | `flex` | `flex`: rest at large angle, rep = below `downBelow` then above `upAbove`. `extend`: rest at small angle, rep = above `upAbove` then below `downBelow` |
| `mode` | `reps` | `hold`: accumulate time while angle ∈ [`holdMin`, `holdMax`] |
| `side` | `auto` | `auto` higher confidence, `both` mean of both sides (falls back to one), `min`/`max` smaller/larger angle |
| `orientation` | none | `{joints: [a, b], axis: horizontal\|vertical, maxTiltDeg: 35}`; wrong orientation is "person present" but never advances reps/hold |
| `formRules` | squat hip–knee–ankle flex reps → legacy `shallow_depth`; else none | see below |
| `placement`, `setupTipVi` | none | UI hints |

Form rules (`domain/form_rule.dart`), each `{type, code, severity: [s0, s1], ...}`;
optional `joints` measures another triplet on the same side(s) as the main angle:

- `min_depth` `{angle}`: per rep, deepest angle must be `<= angle`;
  severity 1 if `<= s0`, 2 if `<= s1`, else 3 (`angle < s0 < s1`).
- `max_extreme` `{angle}`: per rep, peak angle must be `>= angle`;
  severity 1 if `>= s0`, 2 if `>= s1`, else 3 (`angle > s0 > s1`).
- `band` `{min, max}`: reps → degrees outside the band over the rep;
  hold → fraction of held time outside the band, ignored if `<= minFraction`
  (default 0.1), `s0`/`s1` are fractions in (minFraction, 1].
- Legacy `{code, maxDepthAngle}` (old squat seed) is still read as `min_depth`.

Hold mode accepts only `band` rules.

## Using the domain directly

```dart
final config = CvConfig.fromJson(exerciseCvConfig);
final counter = RepCounter(config: config);
final clock = Stopwatch()..start();
final result = counter.addFrame(PoseFrame(
  timestamp: clock.elapsed,
  landmarks: adaptedLandmarks, // same scale for x and y, e.g. pixels
));
final form = const FormChecker().check(config, result);
// reps: result.repCount, result.reps; hold: result.holdDuration, result.holding
// result.currentAngle, selectedSide, averagedSides, orientationOk
// form.formScore, form.issues.map((issue) => issue.toJson())

// Also run on a UI timer, even when camera frames stop arriving.
final presence = counter.checkPresence(clock.elapsed);
```

`FormChecker.checkSquats(reps)` is kept for old callers and equals
`check(squatConfig, result)` for a hip–knee–ankle config.

## Counting, hold and confidence rules

- Each frame picks the side per `side`. Every joint must meet `minConfidence`;
  missing joints, nonfinite coordinates, zero-length vectors or likelihood
  outside [0, 1] make that side unusable. A usable opposite side is accepted.
- Reps: two consecutive usable frames must be strictly past a threshold.
  Initially and after losing the person, two rest frames arm the counter, so a
  set starting in the active position cannot count a partial rep. Duration runs
  from the first active crossing to the first rest crossing; `== minRepMs`
  counts. Rep indices start at 1. Each rep stores deepest/peak angle and the
  min/max of every tracked triplet (`angleRanges`) for form rules.
- Hold: time between two consecutive usable in-band frames is added if the gap
  is `<= 500 ms` (`RepCounter.holdMaxGap`). Leaving the band, wrong
  orientation, losing the person or pausing stops the clock; the first frame
  back only restarts it. `holdDuration` is never lost.
- More than 1 s without a usable frame sets `personMissing` and cancels an
  incomplete rep. Completed reps and hold time remain.
- Form score: each issue costs `10 * severity`. Reps:
  `round(100 - total / repCount)`; hold: `100 - total` (whole set = rep 1).
  Clamped 0–100. No reps / no hold time → 100 with no issues; the UI uses
  `repCount` / `holdDuration` to tell an empty set apart.

## Native camera session

```dart
import 'package:fitness_app/features/camera_counter/data/camera_rep_session.dart';
import 'package:fitness_app/features/camera_counter/domain/camera_counter.dart';

final session = CameraRepSession(config: CvConfig.fromJson(exerciseCvConfig));
final subscription = session.results.listen((result) {
  // Common: status, error, personMissing, averageConfidence, formScore, issues
  // result.mode (CvMode.reps | CvMode.hold), result.isHold
  // reps: result.repCount — hold: result.holdDuration, result.holding
  // live debug: currentAngle, selectedSide, averagedSides, orientationOk
  // Use session.cameraController with CameraPreview for the live preview.
});
await session.start();
await session.pause(); // Releases camera; keeps reps / hold time.
await session.start(); // Reopens front camera and resumes this set.
await session.stop();  // Terminal: releases camera and ML Kit; closes results.
await subscription.cancel();
```

`session.config` exposes the config (e.g. `setupTipVi`). Subscribe before
`start()`; `latestResult` is always readable, including before the first frame.
Failures appear in `result.error`, and failed start/pause/stop Futures also
throw. Stop is idempotent; create a new session for a new set.

Camera: front-facing, medium resolution, no audio. **Android streams
`ImageFormatGroup.yuv420` and `yuv420ToNv21` repacks it per plane stride**
(some Xiaomi devices pad rows while the plugin's NV21 reports
`bytesPerRow = width`); do not switch back to `nv21`. iOS streams BGRA.
Image metadata compensates sensor/device rotation; pixel coordinates are
passed to the domain without normalization or mirroring. Frames stay in
memory: no file capture, recording or upload.

ML Kit runs in stream mode with one inference in flight; newer frames are
dropped, results older than 1 s are discarded. One Stopwatch drives frame
timestamps and the 100 ms presence timer. On app background call `pause()`;
on leaving F2b call `stop()`.

Platform notes: Android declares CAMERA, minSdk ≥ 24. iOS has
NSCameraUsageDescription; **ML Kit needs iOS ≥ 15.5** (current target 15.0,
raise it before building iOS).

## Debug screen (Android)

```sh
flutter run -d <device-id> -t lib/features/camera_counter/presentation/debug_counter_main.dart
```

The dropdown lists every exercise of `mongo/cv-configs.json` (name • đếm/giữ •
side/front). Changing exercise ends the current set and opens a new one. The
screen shows reps or hold time (`mm:ss.s`, green while holding), the main
angle with its joint names, side used (left/right/average), confidence, wrong
orientation, form score and issue codes, the setup tip, placement and
thresholds. `DebugCounterScreen(config: ...)` adds a custom config at the top.

The app has no asset entry for `mongo/`, so the screen reads a copy in
`presentation/debug_exercise_configs.dart`; `debug_counter_screen_test.dart`
fails if it drifts from `mongo/cv-configs.json` — copy the file contents over
after editing the JSON.

## Tests

From `app/`: `flutter test test/features/camera_counter`.

- `generic_counter_test.dart`: flex on elbow (curl), extend (glute bridge:
  count, jitter, start extended), `max_extreme` severities, side
  `both`/`min`/`max`/`auto`, push-up orientation and body-line `band`, hold
  (in/out of band, gaps, person missing, pause, band fraction, plank
  orientation).
- `exercise_configs_test.dart`: every config in `mongo/cv-configs.json` parses
  and round-trips (read by relative path), `cv.supported` matches, old squat
  JSON counts/grades exactly like `checkSquats`, validation errors.
- `camera_rep_session_test.dart`: session lifecycle plus hold mode fields.
- `debug_counter_screen_test.dart`: config copy in sync, picker reps ↔ hold.
- Older files cover squat counting, form scoring, ML Kit adapter and image
  conversion (yuv420 stride).

## Cần chỉnh trên máy thật

Synthetic tests prove the logic, not the thresholds. On a real phone, record
`currentAngle` in the debug screen for a few correct and sloppy reps per
exercise and adjust:

- jumping-jack (`both`, `minRepMs: 200`) and standing-calf-raise (gap only
  10° between thresholds; foot landmarks are the least reliable) are the most
  likely to miscount.
- side-lying-leg-raise (lying, front camera, `side: min`) and glute-bridge
  (lying on the floor) depend on landmark quality when the body is horizontal.
- push-up/plank `orientation.maxTiltDeg` against phone tilt on the floor;
  push-up `body_not_straight` needs ankles in frame.
- Rows/curls with `auto` side: the far arm may be selected if it is more
  confident; consider `min` if that happens.
- Front camera only: floor placements assume the screen faces the user.
