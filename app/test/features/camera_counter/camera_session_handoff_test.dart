import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'session_handoff_helpers.dart';
import 'synthetic_pose.dart';
import 'camera_rep_session_test.dart' show image;

void main() {
  testWidgets('set 2 receives fresh frames after slow set 1 teardown', (
    tester,
  ) async {
    final hardware = SharedCameraHardware();
    final first = hardware.create(squatConfig());
    final firstSeen = <int>[];
    first.results.listen((r) => firstSeen.add(r.repCount));
    await first.start();
    await hardware.rep(tester, 0);
    expect(first.latestResult.repCount, 1);
    final staleCallback = hardware.cameras[0].onImage!;
    final gate = Completer<void>();
    hardware.cameras[0].release = gate;
    final stopping = first.stop();
    await tester.pump();

    final second = hardware.create(squatConfig());
    final secondSeen = <int>[];
    second.results.listen((r) => secondSeen.add(r.repCount));
    expect(second.latestResult.repCount, 0);
    final starting = second.start();
    await tester.pump();
    final initializedBeforeRelease = hardware.cameras[1].initialized;
    gate.complete();
    await tester.pump();
    await stopping;
    await starting;
    // A late callback from set 1 must not change either counter.
    staleCallback(image());
    await hardware.rep(tester, 1);
    final count = second.latestResult.repCount;
    final seen = List<int>.of(secondSeen);
    await second.stop();
    expect(initializedBeforeRelease, 0);
    expect(count, 1);
    expect(seen, contains(1));
    expect(firstSeen.last, 1);
    expect(hardware.detectors.every((d) => d.closed == 1), isTrue);
  });

  testWidgets('a stopped waiting session does not block the following set', (
    tester,
  ) async {
    final hardware = SharedCameraHardware();
    final first = hardware.create(squatConfig());
    await first.start();
    final release = Completer<void>();
    hardware.cameras[0].release = release;
    final firstStop = first.stop();
    await tester.pump();

    final canceled = hardware.create(squatConfig());
    final canceledStart = canceled.start();
    await tester.pump();
    final canceledStop = canceled.stop();
    final third = hardware.create(squatConfig());
    final thirdStart = third.start();
    await tester.pump();
    release.complete();
    await tester.pump();
    await Future.wait([firstStop, canceledStart, canceledStop, thirdStart]);
    expect(hardware.cameras[1].initialized, 0);
    expect(hardware.cameras[1].started, 0);
    await hardware.rep(tester, 2);
    final reps = third.latestResult.repCount;
    await third.stop();
    expect(reps, 1);
  });

  testWidgets('failed cleanup releases access for the following set', (
    tester,
  ) async {
    final hardware = SharedCameraHardware();
    final first = hardware.create(squatConfig());
    await first.start();
    hardware.cameras[0].stopError = StateError('native stop failed');
    final stopped = expectLater(first.stop(), throwsStateError);
    final second = hardware.create(squatConfig());
    final started = second.start();
    await tester.pump();
    await stopped;
    await started;
    await hardware.rep(tester, 1);
    final reps = second.latestResult.repCount;
    await second.stop();
    expect(reps, 1);
    expect(hardware.cameras[0].disposed, 1);
    expect(hardware.detectors[0].closed, 1);
  });
}
