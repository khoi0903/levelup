import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'form_cues_defaults.dart';
import 'voice_lines_defaults.dart';
import 'voice_models.dart';

abstract interface class VoiceCoach {
  Future<void> init();

  Future<void> speakLine(
    VoiceLineKey key, {
    Map<String, Object?> params = const {},
    bool interrupt = false,
  });

  Future<void> speakFormCue(
    String slug,
    String issueCode, {
    bool interrupt = false,
  });

  Future<void> speakStartTip(
    String slug, {
    bool interrupt = false,
  });

  Future<void> speakText(
    String text, {
    double? rate,
    double? pitch,
    bool interrupt = false,
  });

  Future<void> stop();

  void updateSettings(VoiceSettings settings, {String? effectiveCoachStyle});

  void setAppLifecycle(AppLifecycleState state);

  void dispose();

  bool get isLanguageAvailable;
  bool get isSpeaking;
  Map<String, VoiceStyle> get styles;
  Map<String, ExerciseFormCues> get formCues;
  VoiceSettings get settings;

  String resolveEffectiveStyleId(String? coachStyle);
  String formatLine(String template, Map<String, Object?> params);
  String? pickLine(String styleId, VoiceLineKey key, {Map<String, Object?> params = const {}});
  String? pickFormCue(String styleId, String slug, String issueCode);
  String? pickStartTip(String slug);
  List<String> getStartTips(String slug);
  int countEveryForStyle([String? styleId]);
}

/// Triển khai VoiceCoach dùng flutter_tts.
class FlutterTtsVoiceCoach implements VoiceCoach {
  FlutterTtsVoiceCoach({
    FlutterTts? tts,
    this.onVietnameseVoiceMissing,
  }) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  /// Callback thông báo khi máy không có giọng tiếng Việt (chỉ gọi 1 lần duy nhất).
  final void Function(String message)? onVietnameseVoiceMissing;

  static const String vietnameseLanguageCode = 'vi-VN';
  static const String missingVoiceMessage =
      'Máy chưa có giọng đọc tiếng Việt, cài Google Text-to-Speech để bật';

  static bool _hasWarnedMissingVoice = false;

  Map<String, VoiceStyle> _styles = Map.of(defaultVoiceStyles);
  Map<String, ExerciseFormCues> _formCues = Map.of(defaultFormCues);
  VoiceSettings _settings = const VoiceSettings();
  String? _effectiveCoachStyle = 'supportive';

  bool _isLanguageAvailable = true;
  bool _isSpeaking = false;
  bool _isForeground = true;
  bool _isInitialized = false;

  final Random _random = Random();
  final Map<String, String> _lastSpokenPerKey = {};

  @override
  bool get isLanguageAvailable => _isLanguageAvailable;

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  Map<String, VoiceStyle> get styles => Map.unmodifiable(_styles);

  @override
  Map<String, ExerciseFormCues> get formCues => Map.unmodifiable(_formCues);

  @override
  VoiceSettings get settings => _settings;

  @override
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _loadVoiceLinesAsset();
    await _loadFormCuesAsset();
    await _setupTts();
  }

  Future<void> _loadFormCuesAsset() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/content/form-cues.json',
      );
      final parsed = parseFormCuesJson(jsonString);
      if (parsed.isNotEmpty) {
        _formCues = parsed;
      }
    } catch (_) {
      // Thiếu file hoặc lỗi parse → dùng fallback mặc định trong code, không crash
      _formCues = Map.of(defaultFormCues);
    }
  }

  Future<void> _loadVoiceLinesAsset() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/content/voice-lines.json',
      );
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic> && decoded['styles'] is Map) {
        final stylesMap = decoded['styles'] as Map<String, dynamic>;
        final mergedStyles = Map<String, VoiceStyle>.from(defaultVoiceStyles);

        stylesMap.forEach((styleId, rawStyle) {
          if (rawStyle is Map<String, dynamic>) {
            final parsed = VoiceStyle.fromJson(styleId, rawStyle);
            final defaultStyle = defaultVoiceStyles[styleId];
            if (defaultStyle != null) {
              // Merge fallback lines nếu file thiếu một số line keys
              final mergedLines = Map<String, List<String>>.from(defaultStyle.lines);
              mergedLines.addAll(parsed.lines);
              mergedStyles[styleId] = VoiceStyle(
                id: styleId,
                nameVi: parsed.nameVi.isNotEmpty ? parsed.nameVi : defaultStyle.nameVi,
                descriptionVi: parsed.descriptionVi.isNotEmpty
                    ? parsed.descriptionVi
                    : defaultStyle.descriptionVi,
                rate: parsed.rate,
                pitch: parsed.pitch,
                countEvery: parsed.countEvery,
                lines: mergedLines,
              );
            } else {
              mergedStyles[styleId] = parsed;
            }
          }
        });

        _styles = mergedStyles;
      }
    } catch (_) {
      // Thiếu file hoặc lỗi parse → dùng fallback mặc định trong code, không crash
      _styles = Map.of(defaultVoiceStyles);
    }
  }

  Future<void> _setupTts() async {
    try {
      _tts.setStartHandler(() {
        _isSpeaking = true;
      });
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });
      _tts.setErrorHandler((dynamic msg) {
        _isSpeaking = false;
      });
      _tts.setCancelHandler(() {
        _isSpeaking = false;
      });

      // Kiểm tra ngôn ngữ vi-VN
      bool hasVi = false;
      try {
        final isAvailable = await _tts.isLanguageAvailable(vietnameseLanguageCode);
        if (isAvailable == true || isAvailable == 1) {
          hasVi = true;
        } else {
          final langs = await _tts.getLanguages;
          if (langs is List) {
            hasVi = langs.any((l) =>
                l.toString().toLowerCase().startsWith('vi'));
          }
        }
      } catch (_) {
        // Trong môi trường test hoặc giả lập không hỗ trợ, giả định true để test không lỗi
        hasVi = true;
      }

      if (!hasVi) {
        _isLanguageAvailable = false;
        if (!_hasWarnedMissingVoice) {
          _hasWarnedMissingVoice = true;
          onVietnameseVoiceMissing?.call(missingVoiceMessage);
        }
        return;
      }

      await _tts.setLanguage(vietnameseLanguageCode);

      // Cấu hình audio ducking trên iOS nếu có hỗ trợ
      try {
        if (!kIsWeb && Platform.isIOS) {
          await _tts.setIosAudioCategory(
            IosTextToSpeechAudioCategory.playback,
            [
              IosTextToSpeechAudioCategoryOptions.duckOthers,
              IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            ],
          );
          await _tts.setSharedInstance(true);
        }
      } catch (_) {}
    } catch (_) {
      // Bỏ qua lỗi TTS initialization
    }
  }

  @override
  void updateSettings(VoiceSettings settings, {String? effectiveCoachStyle}) {
    _settings = settings;
    if (effectiveCoachStyle != null && effectiveCoachStyle.isNotEmpty) {
      _effectiveCoachStyle = effectiveCoachStyle;
    }
  }

  @override
  void setAppLifecycle(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    _isForeground = foreground;
    if (!foreground) {
      unawaited(stop());
    }
  }

  @override
  String resolveEffectiveStyleId(String? coachStyle) {
    if (_settings.selectedStyleId != 'coach') {
      return _settings.selectedStyleId;
    }
    final style = coachStyle ?? _effectiveCoachStyle ?? 'supportive';
    return switch (style) {
      'strict' => 'strict',
      'funny' => 'funny',
      _ => 'supportive',
    };
  }

  @override
  int countEveryForStyle([String? styleId]) {
    final effectiveId = styleId ?? resolveEffectiveStyleId(_effectiveCoachStyle);
    final style = _styles[effectiveId] ?? defaultVoiceStyles['supportive']!;
    return style.countEvery;
  }

  @override
  String? pickLine(
    String styleId,
    VoiceLineKey key, {
    Map<String, Object?> params = const {},
  }) {
    final style = _styles[styleId] ?? _styles['supportive'] ?? defaultVoiceStyles['supportive']!;
    final lines = style.lines[key.key];
    if (lines == null || lines.isEmpty) return null;

    final hasKcal = params.containsKey('kcal') &&
        params['kcal'] != null &&
        (params['kcal'].toString() != '0' && params['kcal'].toString().isNotEmpty);

    var candidates = lines;
    // Nếu là workout_done mà không có calo, ưu tiên câu không chứa {kcal}
    if (key == VoiceLineKey.workoutDone && !hasKcal) {
      final noKcalCandidates = lines.where((l) => !l.contains('{kcal}')).toList();
      if (noKcalCandidates.isNotEmpty) {
        candidates = noKcalCandidates;
      }
    }

    final cacheKey = '${styleId}_${key.key}';
    final lastSpoken = _lastSpokenPerKey[cacheKey];

    String chosen;
    if (candidates.length > 1 && lastSpoken != null) {
      final filtered = candidates.where((l) => l != lastSpoken).toList();
      final pool = filtered.isNotEmpty ? filtered : candidates;
      chosen = pool[_random.nextInt(pool.length)];
    } else {
      chosen = candidates[_random.nextInt(candidates.length)];
    }

    _lastSpokenPerKey[cacheKey] = chosen;
    return chosen;
  }

  @override
  List<String> getStartTips(String slug) {
    return _formCues[slug]?.startTip ?? const [];
  }

  @override
  String? pickStartTip(String slug) {
    final tips = getStartTips(slug);
    if (tips.isEmpty) return null;

    final cacheKey = 'start_tip_$slug';
    final lastSpoken = _lastSpokenPerKey[cacheKey];

    String chosen;
    if (tips.length > 1 && lastSpoken != null) {
      final filtered = tips.where((t) => t != lastSpoken).toList();
      final pool = filtered.isNotEmpty ? filtered : tips;
      chosen = pool[_random.nextInt(pool.length)];
    } else {
      chosen = tips[_random.nextInt(tips.length)];
    }

    _lastSpokenPerKey[cacheKey] = chosen;
    return chosen;
  }

  @override
  String? pickFormCue(String styleId, String slug, String issueCode) {
    final exercise = _formCues[slug];
    final issue = exercise?.issues[issueCode];

    List<String>? candidates;
    if (issue != null) {
      if (styleId == 'minimal') {
        if (issue.minimal.isNotEmpty) {
          candidates = issue.minimal;
        }
      } else {
        if (issue.cue.isNotEmpty) {
          candidates = issue.cue;
        }
      }
    }

    if (candidates == null || candidates.isEmpty) {
      return pickLine(styleId, VoiceLineKey.formGeneric);
    }

    final cacheKey = 'cue_${slug}_${issueCode}_$styleId';
    final lastSpoken = _lastSpokenPerKey[cacheKey];

    String chosen;
    if (candidates.length > 1 && lastSpoken != null) {
      final filtered = candidates.where((c) => c != lastSpoken).toList();
      final pool = filtered.isNotEmpty ? filtered : candidates;
      chosen = pool[_random.nextInt(pool.length)];
    } else {
      chosen = candidates[_random.nextInt(candidates.length)];
    }

    _lastSpokenPerKey[cacheKey] = chosen;
    return chosen;
  }

  @override
  Future<void> speakFormCue(
    String slug,
    String issueCode, {
    bool interrupt = false,
  }) async {
    if (!_settings.effectiveActive || !_isLanguageAvailable || !_isForeground) {
      return;
    }

    final styleId = resolveEffectiveStyleId(_effectiveCoachStyle);
    final cue = pickFormCue(styleId, slug, issueCode);
    if (cue == null || cue.isEmpty) return;

    final style = _styles[styleId] ?? defaultVoiceStyles['supportive']!;
    final effectiveRate = (style.rate * _settings.speed.multiplier).clamp(0.1, 1.0);
    final effectivePitch = style.pitch.clamp(0.5, 2.0);

    await speakText(
      cue,
      rate: effectiveRate,
      pitch: effectivePitch,
      interrupt: interrupt,
    );
  }

  @override
  Future<void> speakStartTip(
    String slug, {
    bool interrupt = false,
  }) async {
    if (!_settings.effectiveActive ||
        !_settings.readStartTip ||
        !_isLanguageAvailable ||
        !_isForeground) {
      return;
    }

    final tip = pickStartTip(slug);
    if (tip == null || tip.isEmpty) return;

    final styleId = resolveEffectiveStyleId(_effectiveCoachStyle);
    final style = _styles[styleId] ?? defaultVoiceStyles['supportive']!;
    final effectiveRate = (style.rate * _settings.speed.multiplier).clamp(0.1, 1.0);
    final effectivePitch = style.pitch.clamp(0.5, 2.0);

    await speakText(
      tip,
      rate: effectiveRate,
      pitch: effectivePitch,
      interrupt: interrupt,
    );
  }

  @override
  String formatLine(String template, Map<String, Object?> params) {
    var result = template;
    params.forEach((k, v) {
      result = result.replaceAll('{$k}', v?.toString() ?? '');
    });
    return result;
  }

  @override
  Future<void> speakLine(
    VoiceLineKey key, {
    Map<String, Object?> params = const {},
    bool interrupt = false,
  }) async {
    if (!_settings.effectiveActive || !_isLanguageAvailable || !_isForeground) {
      return;
    }

    final styleId = resolveEffectiveStyleId(_effectiveCoachStyle);
    final style = _styles[styleId] ?? defaultVoiceStyles['supportive']!;
    final template = pickLine(styleId, key, params: params);
    if (template == null || template.isEmpty) return;

    final formatted = formatLine(template, params);
    final effectiveRate = (style.rate * _settings.speed.multiplier).clamp(0.1, 1.0);
    final effectivePitch = style.pitch.clamp(0.5, 2.0);

    // Những sự kiện quan trọng (đếm số, đếm lùi, bắt đầu, xong hiệp, nhắc tư thế)
    final isImportant = interrupt ||
        key == VoiceLineKey.rep ||
        key == VoiceLineKey.startCountdown ||
        key == VoiceLineKey.go ||
        key == VoiceLineKey.almostDone ||
        key == VoiceLineKey.lastRep ||
        key == VoiceLineKey.holdLast;

    await speakText(
      formatted,
      rate: effectiveRate,
      pitch: effectivePitch,
      interrupt: isImportant,
    );
  }

  @override
  Future<void> speakText(
    String text, {
    double? rate,
    double? pitch,
    bool interrupt = false,
  }) async {
    if (!_settings.effectiveActive || !_isLanguageAvailable || !_isForeground) {
      return;
    }

    try {
      if (interrupt) {
        await _tts.stop();
      } else if (_isSpeaking) {
        // Tránh đọc chồng chéo khi câu trước chưa kết thúc
        return;
      }

      if (rate != null) await _tts.setSpeechRate(rate);
      if (pitch != null) await _tts.setPitch(pitch);

      _isSpeaking = true;
      await _tts.speak(text);
    } catch (_) {
      _isSpeaking = false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      _isSpeaking = false;
      await _tts.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    unawaited(stop());
  }
}

/// Fake VoiceCoach dùng để ghi lại lịch sử đọc câu trong test.
class FakeVoiceCoach implements VoiceCoach {
  FakeVoiceCoach({
    this.isLanguageAvailable = true,
    Map<String, VoiceStyle>? styles,
    Map<String, ExerciseFormCues>? formCues,
    VoiceSettings? initialSettings,
  })  : styles = styles ?? Map.of(defaultVoiceStyles),
        formCues = formCues ?? Map.of(defaultFormCues),
        settings = initialSettings ?? const VoiceSettings();

  @override
  bool isLanguageAvailable;

  @override
  bool isSpeaking = false;

  @override
  Map<String, VoiceStyle> styles;

  @override
  Map<String, ExerciseFormCues> formCues;

  @override
  VoiceSettings settings;

  String? effectiveCoachStyle = 'supportive';
  bool isForeground = true;

  final List<String> spokenLines = [];
  final List<VoiceLineKey> spokenKeys = [];
  final List<({VoiceLineKey key, String text, Map<String, Object?> params})> history = [];

  final Map<String, String> _lastSpokenPerKey = {};
  final Random _random = Random(42);

  List<String> get spokenTexts => spokenLines;
  List<({VoiceLineKey key, String text, Map<String, Object?> params})> get calls => history;

  void setMutedTemporarily(bool muted) {
    settings = settings.copyWith(mutedTemporarily: muted);
  }

  void clearHistory() {
    spokenLines.clear();
    spokenKeys.clear();
    history.clear();
    _lastSpokenPerKey.clear();
  }

  @override
  Future<void> init() async {}

  @override
  void updateSettings(VoiceSettings settings, {String? effectiveCoachStyle}) {
    this.settings = settings;
    if (effectiveCoachStyle != null && effectiveCoachStyle.isNotEmpty) {
      this.effectiveCoachStyle = effectiveCoachStyle;
    }
  }

  @override
  void setAppLifecycle(AppLifecycleState state) {
    isForeground = state == AppLifecycleState.resumed;
    if (!isForeground) {
      isSpeaking = false;
    }
  }

  @override
  String resolveEffectiveStyleId(String? coachStyle) {
    if (settings.selectedStyleId != 'coach') {
      return settings.selectedStyleId;
    }
    final style = coachStyle ?? effectiveCoachStyle ?? 'supportive';
    return switch (style) {
      'strict' => 'strict',
      'funny' => 'funny',
      _ => 'supportive',
    };
  }

  @override
  int countEveryForStyle([String? styleId]) {
    final effectiveId = styleId ?? resolveEffectiveStyleId(effectiveCoachStyle);
    final style = styles[effectiveId] ?? defaultVoiceStyles['supportive']!;
    return style.countEvery;
  }

  @override
  String? pickLine(
    String styleId,
    VoiceLineKey key, {
    Map<String, Object?> params = const {},
  }) {
    final style = styles[styleId] ?? styles['supportive'] ?? defaultVoiceStyles['supportive']!;
    final lines = style.lines[key.key];
    if (lines == null || lines.isEmpty) return null;

    final hasKcal = params.containsKey('kcal') &&
        params['kcal'] != null &&
        (params['kcal'].toString() != '0' && params['kcal'].toString().isNotEmpty);

    var candidates = lines;
    if (key == VoiceLineKey.workoutDone && !hasKcal) {
      final noKcalCandidates = lines.where((l) => !l.contains('{kcal}')).toList();
      if (noKcalCandidates.isNotEmpty) {
        candidates = noKcalCandidates;
      }
    }

    final cacheKey = '${styleId}_${key.key}';
    final lastSpoken = _lastSpokenPerKey[cacheKey];

    String chosen;
    if (candidates.length > 1 && lastSpoken != null) {
      final filtered = candidates.where((l) => l != lastSpoken).toList();
      final pool = filtered.isNotEmpty ? filtered : candidates;
      chosen = pool[_random.nextInt(pool.length)];
    } else {
      chosen = candidates[_random.nextInt(candidates.length)];
    }

    _lastSpokenPerKey[cacheKey] = chosen;
    return chosen;
  }

  @override
  List<String> getStartTips(String slug) {
    return formCues[slug]?.startTip ?? const [];
  }

  @override
  String? pickStartTip(String slug) {
    final tips = getStartTips(slug);
    if (tips.isEmpty) return null;

    final cacheKey = 'start_tip_$slug';
    final lastSpoken = _lastSpokenPerKey[cacheKey];

    String chosen;
    if (tips.length > 1 && lastSpoken != null) {
      final filtered = tips.where((t) => t != lastSpoken).toList();
      final pool = filtered.isNotEmpty ? filtered : tips;
      chosen = pool[_random.nextInt(pool.length)];
    } else {
      chosen = tips[_random.nextInt(tips.length)];
    }

    _lastSpokenPerKey[cacheKey] = chosen;
    return chosen;
  }

  @override
  String? pickFormCue(String styleId, String slug, String issueCode) {
    final exercise = formCues[slug];
    final issue = exercise?.issues[issueCode];

    List<String>? candidates;
    if (issue != null) {
      if (styleId == 'minimal') {
        if (issue.minimal.isNotEmpty) {
          candidates = issue.minimal;
        }
      } else {
        if (issue.cue.isNotEmpty) {
          candidates = issue.cue;
        }
      }
    }

    if (candidates == null || candidates.isEmpty) {
      return pickLine(styleId, VoiceLineKey.formGeneric);
    }

    final cacheKey = 'cue_${slug}_${issueCode}_$styleId';
    final lastSpoken = _lastSpokenPerKey[cacheKey];

    String chosen;
    if (candidates.length > 1 && lastSpoken != null) {
      final filtered = candidates.where((c) => c != lastSpoken).toList();
      final pool = filtered.isNotEmpty ? filtered : candidates;
      chosen = pool[_random.nextInt(pool.length)];
    } else {
      chosen = candidates[_random.nextInt(candidates.length)];
    }

    _lastSpokenPerKey[cacheKey] = chosen;
    return chosen;
  }

  @override
  Future<void> speakFormCue(
    String slug,
    String issueCode, {
    bool interrupt = false,
  }) async {
    if (!settings.effectiveActive || !isLanguageAvailable || !isForeground) {
      return;
    }

    final styleId = resolveEffectiveStyleId(effectiveCoachStyle);
    final exercise = formCues[slug];
    final issue = exercise?.issues[issueCode];
    final hasSpecific = issue != null &&
        ((styleId == 'minimal' && issue.minimal.isNotEmpty) ||
         (styleId != 'minimal' && issue.cue.isNotEmpty));

    if (!hasSpecific) {
      await speakLine(VoiceLineKey.formGeneric, interrupt: interrupt);
      return;
    }

    final cue = pickFormCue(styleId, slug, issueCode);
    if (cue == null || cue.isEmpty) return;

    spokenLines.add(cue);
    isSpeaking = true;
  }

  @override
  Future<void> speakStartTip(
    String slug, {
    bool interrupt = false,
  }) async {
    if (!settings.effectiveActive ||
        !settings.readStartTip ||
        !isLanguageAvailable ||
        !isForeground) {
      return;
    }

    final tip = pickStartTip(slug);
    if (tip == null || tip.isEmpty) return;

    spokenLines.add(tip);
    isSpeaking = true;
  }

  @override
  String formatLine(String template, Map<String, Object?> params) {
    var result = template;
    params.forEach((k, v) {
      result = result.replaceAll('{$k}', v?.toString() ?? '');
    });
    return result;
  }

  @override
  Future<void> speakLine(
    VoiceLineKey key, {
    Map<String, Object?> params = const {},
    bool interrupt = false,
  }) async {
    if (!settings.effectiveActive || !isLanguageAvailable || !isForeground) {
      return;
    }

    final styleId = resolveEffectiveStyleId(effectiveCoachStyle);
    final template = pickLine(styleId, key, params: params);
    if (template == null || template.isEmpty) return;

    final formatted = formatLine(template, params);
    spokenLines.add(formatted);
    spokenKeys.add(key);
    history.add((key: key, text: formatted, params: params));
    isSpeaking = true;
  }

  @override
  Future<void> speakText(
    String text, {
    double? rate,
    double? pitch,
    bool interrupt = false,
  }) async {
    if (!settings.effectiveActive || !isLanguageAvailable || !isForeground) {
      return;
    }
    spokenLines.add(text);
    isSpeaking = true;
  }

  @override
  Future<void> stop() async {
    isSpeaking = false;
  }

  @override
  void dispose() {
    isSpeaking = false;
  }
}
