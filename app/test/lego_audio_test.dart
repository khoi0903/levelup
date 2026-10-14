import 'dart:io';

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

  group('Đếm số', () {
    test('mỗi số 1..100 là một file có thật, đủ cả giọng nữ và nam', () {
      for (final gender in VoiceGender.values) {
        for (var n = 1; n <= 100; n++) {
          final path = player.resolveAssetPath(
            VoiceLineKey.rep,
            params: {'n': n},
            gender: gender,
          );
          expect(path, isNotNull, reason: 'rep $n');
          final file = File('assets/$path');
          expect(file.existsSync() && file.lengthSync() > 0, isTrue,
              reason: 'thiếu hoặc rỗng: assets/$path');
        }
      }
    });

    test('ngoài 1..100 thì đọc bằng TTS', () {
      expect(player.resolveAssetPath(VoiceLineKey.rep, params: {'n': 0}), isNull);
      expect(player.resolveAssetPath(VoiceLineKey.rep, params: {'n': 101}), isNull);
    });

    test('giọng nam lấy trong thư mục male', () {
      expect(
        player.resolveAssetPath(VoiceLineKey.rep,
            params: {'n': 21}, gender: VoiceGender.male),
        'audio/male/reps/21.mp3',
      );
      expect(player.resolveAssetPath(VoiceLineKey.rep, params: {'n': 21}),
          'audio/reps/21.mp3');
    });
  });

  group('Không đoán file theo nội dung chữ', () {
    test('mẹo đầu bài có chữ "tay", "hông" không phát nhầm câu nhắc tư thế', () {
      for (final text in [
        'Hạ ngực chậm, khuỷu tay chếch về sau',
        'Đặt khuỷu tay dưới vai, giữ hông ngang thân',
        'Nghỉ tay chút rồi chiến tiếp',
      ]) {
        expect(player.resolveAssetPath(null, text: text), isNull, reason: text);
      }
    });

    test('nhắc tư thế chỉ dùng MP3 khi đúng câu của bài', () {
      expect(
        player.resolveAssetPath(null,
            slug: 'jumping-jack', issueCode: 'arms_not_overhead'),
        'audio/form/hands_overhead.mp3',
      );
      expect(
        player.resolveAssetPath(null,
            slug: 'push-up', issueCode: 'pushup_not_deep_enough'),
        isNull,
      );
      expect(
        player.resolveAssetPath(null,
            slug: 'bodyweight-squat', issueCode: 'shallow_depth'),
        isNull,
      );
    });
  });

  group('Phong cách giọng', () {
    test('phong cách mặc định "coach" dùng câu nhắc thu sẵn', () {
      expect(player.resolveAssetPath(VoiceLineKey.go), 'audio/countdown/go.mp3');
      expect(player.resolveAssetPath(VoiceLineKey.setDone),
          'audio/cues/set_done.mp3');
    });

    test('chọn phong cách riêng thì câu nhắc đọc bằng TTS, số vẫn dùng MP3', () {
      expect(player.resolveAssetPath(VoiceLineKey.go, styledLines: true), isNull);
      expect(player.resolveAssetPath(VoiceLineKey.setDone, styledLines: true),
          isNull);
      expect(
        player.resolveAssetPath(VoiceLineKey.rep,
            params: {'n': 7}, styledLines: true),
        'audio/reps/7.mp3',
      );
      expect(
        player.resolveAssetPath(VoiceLineKey.startCountdown,
            params: {'n': 3}, styledLines: true),
        'audio/countdown/3.mp3',
      );
    });
  });
}
