import 'package:fitness_app/core/voice/voice_commands.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hiểu các câu lệnh thường gặp, có dấu hay không dấu', () {
    expect(parseVoiceCommand('Bỏ bài'), VoiceCommand.skip);
    expect(parseVoiceCommand('bo qua di'), VoiceCommand.skip);
    expect(parseVoiceCommand('đổi bài khác'), VoiceCommand.skip);
    expect(parseVoiceCommand('Tập tiếp'), VoiceCommand.resume);
    expect(parseVoiceCommand('huỷ'), VoiceCommand.resume);
    expect(parseVoiceCommand('không bỏ'), VoiceCommand.resume);
    expect(parseVoiceCommand('Tạm dừng'), VoiceCommand.pause);
    expect(parseVoiceCommand('dừng lại chút'), VoiceCommand.pause);
    expect(parseVoiceCommand('Xong hiệp'), VoiceCommand.finishSet);
    expect(parseVoiceCommand('xong rồi'), VoiceCommand.finishSet);
    expect(parseVoiceCommand('tiếp'), VoiceCommand.resume);
  });

  test('không chắc thì không làm gì (nói chuyện khác, câu dài, rỗng)', () {
    expect(parseVoiceCommand(''), isNull);
    expect(parseVoiceCommand('hôm nay trời đẹp quá'), isNull);
    expect(parseVoiceCommand('mai mình đi ăn bún bò rồi bỏ qua chuyện đó luôn nhé'), isNull);
    expect(parseVoiceCommand('bóng đá'), isNull);
  });

  test('chuẩn hoá tiếng Việt', () {
    expect(normalizeVi('  Đổi BÀI!! '), 'doi bai');
  });
}
