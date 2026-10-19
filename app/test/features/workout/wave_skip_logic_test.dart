import 'package:fitness_app/features/workout/data/camera/rep_counting_session.dart';
import 'package:fitness_app/features/workout/domain/models/wave_skip_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 10, 19, 18);
  DateTime at(int sec) => t0.add(Duration(seconds: sec));
  const idle = RepSnapshot(status: RepCountingStatus.running);

  test('đứng yên 20 giây thì hỏi một lần; vẫy tay lúc hỏi thì đếm ngược rồi bỏ bài', () {
    final l = WaveSkipLogic()..start(t0, idle);
    expect(l.tick(at(19)), isEmpty);
    expect(l.tick(at(20)), [WaveSkipEvent.prompt]);
    expect(l.promptVisible(at(21)), isTrue);
    expect(l.tick(at(40)), isEmpty); // không hỏi lại trong hiệp
    expect(
      l.onSnapshot(const RepSnapshot(waveCount: 1), at(22)),
      [WaveSkipEvent.countdown],
    );
    expect(l.countdownLeft, 3);
    expect(l.tick(at(23)), [WaveSkipEvent.countdownTick]);
    expect(l.tick(at(24)), [WaveSkipEvent.countdownTick]);
    expect(l.tick(at(25)), [WaveSkipEvent.skip]);
    expect(l.countdownLeft, isNull);
  });

  test('vừa tập (dưới 3 giây) thì không nhận vẫy tay', () {
    final l = WaveSkipLogic()..start(t0, idle);
    l.onSnapshot(const RepSnapshot(repCount: 1), at(1));
    expect(l.onSnapshot(const RepSnapshot(repCount: 1, waveCount: 1), at(2)), isEmpty);
    // 3 giây không đếm được lần nào: nhận
    expect(
      l.onSnapshot(const RepSnapshot(repCount: 1, waveCount: 2), at(5)),
      [WaveSkipEvent.countdown],
    );
  });

  test('làm thêm một lần trong lúc đếm ngược thì huỷ', () {
    final l = WaveSkipLogic()..start(t0, idle);
    l.onSnapshot(const RepSnapshot(waveCount: 1), at(5));
    expect(l.countdownLeft, 3);
    expect(
      l.onSnapshot(const RepSnapshot(repCount: 1, waveCount: 1), at(6)),
      [WaveSkipEvent.cancelled],
    );
    expect(l.countdownLeft, isNull);
  });

  test('bài giữ tư thế: đang giữ thì không nhận vẫy, không hỏi', () {
    final l = WaveSkipLogic()..start(t0, idle);
    expect(
      l.onSnapshot(const RepSnapshot(isHold: true, holding: true, waveCount: 1), at(10)),
      isEmpty,
    );
    expect(l.tick(at(25)), isEmpty);
  });

  test('không thấy người thì không hỏi; vẫy trước khi bắt đầu bị bỏ qua', () {
    final l = WaveSkipLogic();
    expect(l.onSnapshot(const RepSnapshot(waveCount: 1), at(0)), isEmpty);
    l.start(at(1), const RepSnapshot(waveCount: 1));
    expect(l.onSnapshot(const RepSnapshot(waveCount: 1, personMissing: true), at(30)), isEmpty);
    expect(l.tick(at(30)), isEmpty);
  });

  test('bấm "Bỏ bài này" đếm ngược, "Huỷ" dừng', () {
    final l = WaveSkipLogic()..start(t0, idle);
    l.tick(at(20));
    expect(l.requestSkip(), WaveSkipEvent.countdown);
    l.dismiss();
    expect(l.countdownLeft, isNull);
    expect(l.promptVisible(at(21)), isFalse);
    expect(l.tick(at(22)), isEmpty);
  });
}
