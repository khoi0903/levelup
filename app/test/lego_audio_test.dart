import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/core/voice/audio_clip_player.dart';
import 'package:fitness_app/core/voice/voice_models.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => null,
    );
  });

  late AudioClipPlayer player;

  setUp(() {
    player = AudioClipPlayer();
  });

  group('Lego Audio - resolveRepSubPaths', () {
    test('1 to 10 are single files', () {
      for (int i = 1; i <= 10; i++) {
        expect(player.resolveRepSubPaths(i), ['reps/$i.mp3']);
      }
    });

    test('11 to 19', () {
      expect(player.resolveRepSubPaths(11), ['reps/10.mp3', 'reps/1.mp3']);
      expect(player.resolveRepSubPaths(12), ['reps/10.mp3', 'reps/2.mp3']);
      expect(player.resolveRepSubPaths(14), ['reps/10.mp3', 'reps/4.mp3']);
      expect(player.resolveRepSubPaths(15), ['reps/10.mp3', 'reps/lam.mp3']);
      expect(player.resolveRepSubPaths(19), ['reps/10.mp3', 'reps/9.mp3']);
    });

    test('Round tens and 100', () {
      expect(player.resolveRepSubPaths(20), ['reps/20.mp3']);
      expect(player.resolveRepSubPaths(30), ['reps/30.mp3']);
      expect(player.resolveRepSubPaths(40), ['reps/40.mp3']);
      expect(player.resolveRepSubPaths(50), ['reps/50.mp3']);
      expect(player.resolveRepSubPaths(90), ['reps/90.mp3']);
      expect(player.resolveRepSubPaths(100), ['reps/100.mp3']);
    });

    test('21 to 99 composite numbers', () {
      expect(player.resolveRepSubPaths(21), ['reps/20.mp3', 'reps/mot.mp3']);
      expect(player.resolveRepSubPaths(24), ['reps/20.mp3', 'reps/tu.mp3']);
      expect(player.resolveRepSubPaths(25), ['reps/20.mp3', 'reps/lam.mp3']);
      expect(player.resolveRepSubPaths(37), ['reps/30.mp3', 'reps/7.mp3']);
      expect(player.resolveRepSubPaths(55), ['reps/50.mp3', 'reps/lam.mp3']);
      expect(player.resolveRepSubPaths(99), ['reps/90.mp3', 'reps/9.mp3']);
    });

    test('Every number from 1 to 100 returns 1 or 2 valid non-empty files', () {
      for (int i = 1; i <= 100; i++) {
        final paths = player.resolveRepSubPaths(i);
        expect(paths.isNotEmpty, isTrue, reason: 'Failed for rep $i');
        expect(paths.length <= 2, isTrue, reason: 'Too many pieces for rep $i');
        for (final p in paths) {
          expect(p.startsWith('reps/'), isTrue);
          expect(p.endsWith('.mp3'), isTrue);
        }
      }
    });

    test('resolveAssetPaths with gender', () {
      final female = player.resolveAssetPaths(
        VoiceLineKey.rep,
        params: {'n': 21},
        gender: VoiceGender.female,
      );
      expect(female, ['audio/reps/20.mp3', 'audio/reps/mot.mp3']);

      final male = player.resolveAssetPaths(
        VoiceLineKey.rep,
        params: {'n': 21},
        gender: VoiceGender.male,
      );
      expect(male, ['audio/male/reps/20.mp3', 'audio/male/reps/mot.mp3']);
    });
  });
}
