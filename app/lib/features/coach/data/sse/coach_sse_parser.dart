import 'dart:convert';

import '../../domain/models/coach_models.dart';

sealed class CoachStreamEvent {
  const CoachStreamEvent();
}

class CoachDeltaEvent extends CoachStreamEvent {
  final String text;

  const CoachDeltaEvent(this.text);

  @override
  String toString() => 'CoachDeltaEvent($text)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachDeltaEvent &&
          runtimeType == other.runtimeType &&
          text == other.text;

  @override
  int get hashCode => text.hashCode;
}

class CoachDoneEvent extends CoachStreamEvent {
  final SendCoachResponse response;

  const CoachDoneEvent(this.response);

  @override
  String toString() => 'CoachDoneEvent($response)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachDoneEvent &&
          runtimeType == other.runtimeType &&
          response == other.response;

  @override
  int get hashCode => response.hashCode;
}

class CoachErrorEvent extends CoachStreamEvent {
  final String code;
  final String? message;

  const CoachErrorEvent({required this.code, this.message});

  @override
  String toString() => 'CoachErrorEvent(code: $code, message: $message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachErrorEvent &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          message == other.message;

  @override
  int get hashCode => Object.hash(code, message);
}

/// Chuyển đổi luồng byte SSE thành các [CoachStreamEvent].
/// Xử lý việc UTF-8 bị cắt byte giữa các chunk và event bị cắt giữa các dòng.
Stream<CoachStreamEvent> parseCoachSseByteStream(Stream<List<int>> byteStream) {
  return parseCoachSseStringChunks(
    byteStream.transform(utf8.decoder),
  );
}

/// Chuyển đổi luồng chuỗi SSE thành các [CoachStreamEvent].
Stream<CoachStreamEvent> parseCoachSseStringChunks(Stream<String> stringStream) {
  return parseCoachSseLines(
    stringStream.transform(const LineSplitter()),
  );
}

/// Tách các block event SSE theo dòng trống và phân tích event: / data:.
Stream<CoachStreamEvent> parseCoachSseLines(Stream<String> lines) async* {
  String? currentEvent;
  final dataLines = <String>[];

  await for (final line in lines) {
    final trimmed = line.trimRight();
    if (trimmed.isEmpty) {
      if (currentEvent != null || dataLines.isNotEmpty) {
        final parsed = _parseEvent(currentEvent, dataLines.join('\n'));
        if (parsed != null) yield parsed;
        currentEvent = null;
        dataLines.clear();
      }
      continue;
    }

    if (line.startsWith(':')) {
      // Dòng comment SSE, bỏ qua
      continue;
    }

    final colonIdx = line.indexOf(':');
    if (colonIdx == -1) {
      // Trường không có giá trị
      if (line == 'event') currentEvent = '';
      continue;
    }

    final field = line.substring(0, colonIdx);
    var value = line.substring(colonIdx + 1);
    if (value.startsWith(' ')) {
      value = value.substring(1);
    }

    if (field == 'event') {
      currentEvent = value.trim();
    } else if (field == 'data') {
      dataLines.add(value);
    }
  }

  // Xử lý event cuối nếu stream kết thúc mà không có dòng trống kết thúc
  if (currentEvent != null || dataLines.isNotEmpty) {
    final parsed = _parseEvent(currentEvent, dataLines.join('\n'));
    if (parsed != null) yield parsed;
  }
}

CoachStreamEvent? _parseEvent(String? eventType, String rawData) {
  final trimmedData = rawData.trim();
  if (trimmedData.isEmpty) return null;

  try {
    final dynamic decoded = jsonDecode(trimmedData);
    if (decoded is! Map<String, dynamic>) {
      if (eventType == 'delta') return CoachDeltaEvent(trimmedData);
      return null;
    }

    if (eventType == 'delta') {
      final text = decoded['text']?.toString() ?? '';
      return CoachDeltaEvent(text);
    }

    if (eventType == 'done') {
      return CoachDoneEvent(SendCoachResponse.fromJson(decoded));
    }

    if (eventType == 'error') {
      final code = decoded['code']?.toString() ?? 'UNKNOWN_ERROR';
      final message = decoded['message']?.toString();
      return CoachErrorEvent(code: code, message: message);
    }

    // Tự suy đoán nếu không có trường event:
    if (decoded.containsKey('reply')) {
      return CoachDoneEvent(SendCoachResponse.fromJson(decoded));
    }
    if (decoded.containsKey('code')) {
      return CoachErrorEvent(
        code: decoded['code']?.toString() ?? 'UNKNOWN_ERROR',
        message: decoded['message']?.toString(),
      );
    }
    if (decoded.containsKey('text')) {
      return CoachDeltaEvent(decoded['text']?.toString() ?? '');
    }
  } catch (_) {
    if (eventType == 'delta') {
      return CoachDeltaEvent(trimmedData);
    }
  }
  return null;
}
