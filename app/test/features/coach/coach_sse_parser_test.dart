import 'dart:convert';
import 'dart:typed_data';
import 'package:fitness_app/features/coach/data/sse/coach_sse_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Coach SSE Parser', () {
    test('nhiều event trong một chunk', () async {
      const chunk =
          'event: delta\n'
          'data: {"text":"Chào Khôi, "}\n'
          '\n'
          'event: delta\n'
          'data: {"text":"hôm nay "}\n'
          '\n'
          'event: done\n'
          'data: {"userMessage":{"id":"u1","role":"user","content":"Hi"},"reply":{"id":"c1","role":"coach","content":"Chào Khôi, hôm nay bạn thấy thế nào?"},"remainingToday":8,"source":"claude"}\n'
          '\n';

      final events = await parseCoachSseStringChunks(
        Stream.value(chunk),
      ).toList();

      expect(events, hasLength(3));
      expect(events[0], isA<CoachDeltaEvent>());
      expect((events[0] as CoachDeltaEvent).text, 'Chào Khôi, ');

      expect(events[1], isA<CoachDeltaEvent>());
      expect((events[1] as CoachDeltaEvent).text, 'hôm nay ');

      expect(events[2], isA<CoachDoneEvent>());
      final done = events[2] as CoachDoneEvent;
      expect(done.response.reply.content, 'Chào Khôi, hôm nay bạn thấy thế nào?');
      expect(done.response.remainingToday, 8);
    });

    test('event bị cắt giữa hai chunk', () async {
      const chunk1 = 'event: delta\nda';
      const chunk2 = 'ta: {"text":"Tập tốt lắm!"}\n\n';

      final events = await parseCoachSseStringChunks(
        Stream.fromIterable([chunk1, chunk2]),
      ).toList();

      expect(events, hasLength(1));
      expect(events[0], isA<CoachDeltaEvent>());
      expect((events[0] as CoachDeltaEvent).text, 'Tập tốt lắm!');
    });

    test('tiếng Việt UTF-8 bị cắt giữa byte', () async {
      // "Khôi" có ký tự 'ô' là 2 byte (0xC3, 0xB4)
      // "tiếp tục" có ký tự 'ế' là 3 byte (0xE1, 0xBA, 0xBF)
      const text = 'event: delta\ndata: {"text":"Chào Khôi, tiếp tục nhé!"}\n\n';
      final allBytes = utf8.encode(text);

      // Cắt allBytes ở chính giữa byte sequence của 'ế'
      final indexOfE = text.indexOf('ế');
      final prefixBytes = utf8.encode(text.substring(0, indexOfE));
      // Byte đầu tiên của 'ế'
      final splitIndex = prefixBytes.length + 1;

      final chunk1Bytes = allBytes.sublist(0, splitIndex);
      final chunk2Bytes = allBytes.sublist(splitIndex);

      final events = await parseCoachSseByteStream(
        Stream.fromIterable([chunk1Bytes, chunk2Bytes]),
      ).toList();

      expect(events, hasLength(1));
      expect(events[0], isA<CoachDeltaEvent>());
      expect((events[0] as CoachDeltaEvent).text, 'Chào Khôi, tiếp tục nhé!');
    });

    test('luồng Stream<Uint8List> như Dio trả về (không lỗi kiểu Utf8Decoder)', () async {
      final bytes = Uint8List.fromList(
        utf8.encode('event: delta\ndata: {"text":"Chào Khôi"}\n\n'),
      );
      final Stream<Uint8List> dioStream = Stream.fromIterable([
        bytes.sublist(0, 10),
        bytes.sublist(10),
      ]);

      final events = await parseCoachSseByteStream(dioStream).toList();

      expect(events, hasLength(1));
      expect((events[0] as CoachDeltaEvent).text, 'Chào Khôi');
    });

    test('parse event error', () async {
      const chunk =
          'event: error\n'
          'data: {"code":"COACH_LIMIT","message":"Đã hết lượt"}\n'
          '\n';

      final events = await parseCoachSseStringChunks(
        Stream.value(chunk),
      ).toList();

      expect(events, hasLength(1));
      expect(events[0], isA<CoachErrorEvent>());
      final err = events[0] as CoachErrorEvent;
      expect(err.code, 'COACH_LIMIT');
      expect(err.message, 'Đã hết lượt');
    });
  });
}
