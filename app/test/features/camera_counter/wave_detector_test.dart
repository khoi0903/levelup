import 'package:fitness_app/features/camera_counter/domain/camera_counter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Người đứng thẳng: vai y=200, hông y=400 (thân dài 200). Tay trái giơ lên khi [leftY] nhỏ.
PoseFrame frame(
  int ms, {
  double leftX = 100,
  double leftY = 350,
  double rightX = 300,
  double rightY = 350,
  double likelihood = 0.9,
}) => PoseFrame(
  timestamp: Duration(milliseconds: ms),
  landmarks: [
    PoseLandmark(type: PoseLandmarkType.leftShoulder, x: 150, y: 200, likelihood: likelihood),
    PoseLandmark(type: PoseLandmarkType.rightShoulder, x: 250, y: 200, likelihood: likelihood),
    PoseLandmark(type: PoseLandmarkType.leftHip, x: 160, y: 400, likelihood: likelihood),
    PoseLandmark(type: PoseLandmarkType.rightHip, x: 240, y: 400, likelihood: likelihood),
    PoseLandmark(type: PoseLandmarkType.leftWrist, x: leftX, y: leftY, likelihood: likelihood),
    PoseLandmark(type: PoseLandmarkType.rightWrist, x: rightX, y: rightY, likelihood: likelihood),
  ],
);

/// Vẫy tay trái trên đầu: cổ tay lắc ±[amp] quanh vai, mỗi nửa nhịp [halfMs].
void wave(
  WaveDetector d, {
  int start = 0,
  int swings = 4,
  double amp = 60,
  int halfMs = 250,
  bool bothHands = false,
  double y = 60,
}) {
  for (var i = 0; i <= swings * 5; i++) {
    final phase = (i ~/ 5).isEven ? 1 : -1;
    final x = 150 + phase * amp * ((i % 5) / 4);
    d.addFrame(
      frame(
        start + i * halfMs ~/ 5,
        leftX: x,
        leftY: y,
        rightY: bothHands ? y : 350,
      ),
    );
  }
}

void main() {
  test('vẫy một tay trên đầu được nhận một lần', () {
    final d = WaveDetector();
    wave(d);
    expect(d.waveCount, 1);
  });

  test('giơ tay đứng yên không phải vẫy, nhưng sáng biểu tượng bàn tay', () {
    final d = WaveDetector();
    for (var t = 0; t < 3000; t += 50) {
      d.addFrame(frame(t, leftY: 60));
    }
    expect(d.handRaised, isTrue);
    expect(d.waveCount, 0);
  });

  test('giơ cả hai tay (jumping jack, đẩy qua đầu) không tính', () {
    final d = WaveDetector();
    wave(d, bothHands: true);
    expect(d.waveCount, 0);
    expect(d.handRaised, isFalse);
  });

  test('tay ngang vai lắc qua lại (tập tay) không tính', () {
    final d = WaveDetector();
    wave(d, y: 190);
    expect(d.waveCount, 0);
  });

  test('rung nhẹ dưới ngưỡng không tính', () {
    final d = WaveDetector();
    wave(d, amp: 15);
    expect(d.waveCount, 0);
  });

  test('vẫy quá chậm (ngoài cửa sổ 2,5 giây) không tính', () {
    final d = WaveDetector();
    wave(d, halfMs: 1200);
    expect(d.waveCount, 0);
  });

  test('vẫy liên tục chỉ tính một lần trong thời gian chờ, sau đó tính tiếp', () {
    final d = WaveDetector();
    wave(d);
    wave(d, start: 1100);
    expect(d.waveCount, 1);
    wave(d, start: 4000);
    expect(d.waveCount, 2);
  });

  test('mất người hoặc điểm mờ thì không tính', () {
    final d = WaveDetector();
    d.addFrame(null);
    expect(d.handRaised, isFalse);
    for (var t = 0; t < 2000; t += 50) {
      d.addFrame(frame(t, leftY: 60, leftX: t.isEven ? 90 : 210, likelihood: 0.2));
    }
    expect(d.waveCount, 0);
  });
}
