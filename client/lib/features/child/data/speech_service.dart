import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/models/action_card.dart';
import 'card_speech_repository.dart';

export 'card_speech_repository.dart' show StoredSpeechSource;

/// 카드 문장을 소리로 읽어준다.
///
/// **글을 못 읽는 아동에게는 음성이 유일한 정보 경로다** (docs/README.md).
/// 화면은 이 인터페이스만 알면 되고, 어느 엔진이 소리를 냈는지 알 필요가 없다.
abstract interface class SpeechService {
  /// 읽어준다. **절대 throw하지 않는다** — 실패하면 false.
  ///
  /// [language] 는 읽을 글의 언어 — 일과 언어 코드(`ko` `en` `ja` `zh` `es`)다. 화면 언어가 아니다.
  /// [stored] 는 서버가 미리 만든 단계 음성 위치(#675). 없으면 기기·실시간 음성만 쓴다.
  Future<bool> speak(String text, {String language = 'ko', StoredSpeechSource? stored});

  /// 재생 중이면 멈춘다. 화면을 벗어날 때도 부른다.
  Future<void> stop();

  void dispose();
}

/// 일과 언어 → 기기 TTS 언어 태그. 모르는 값은 한국어다.
@visibleForTesting
String ttsLocaleOf(String language) => switch (language) {
  'en' => 'en-US',
  'ja' => 'ja-JP',
  'zh' => 'zh-CN',
  'es' => 'es-ES',
  _ => 'ko-KR',
};

/// 기기 내장 TTS.
///
/// 네트워크가 필요 없고 지연이 짧아 **1순위**다.
/// 다만 한국어 음성이 없는 기기·에뮬레이터에서는 조용히 실패한다.
class DeviceSpeech implements SpeechService {
  DeviceSpeech({FlutterTts? tts, bool? isAndroid})
    : _tts = tts ?? FlutterTts(),
      _isAndroid = isAndroid ?? defaultTargetPlatform == TargetPlatform.android;

  final FlutterTts _tts;
  final bool _isAndroid;
  String? _configuredLanguage;
  var _rateSet = false;
  var _engineChosen = false;

  /// 안드로이드 기본 엔진은 제조사마다 달라 느린 속도에서 소리가 갈라지는 것이 있다.
  /// Google 음성 서비스가 깔려 있으면 그것으로 고정한다.
  @visibleForTesting
  static const googleEngine = 'com.google.android.tts';

  /// 아동이 듣기 편한 속도. 기본값(1.0)은 조금 빠르다.
  static const _rate = 0.45;

  @override
  Future<bool> speak(String text, {String language = 'ko', StoredSpeechSource? stored}) async {
    try {
      // 폰에 그 언어 음성이 없으면 기기 엔진이 엉뚱한 발음으로 읽어 소리가 깨진다.
      // 못 읽는다고 알려 서버 음성으로 넘긴다.
      if (!await _ensureConfigured(language)) return false;

      // 이전 재생이 남아 있으면 겹친다
      await _tts.stop();

      final result = await _tts.speak(text);
      // 플랫폼마다 1 또는 null을 준다. null도 성공으로 본다 — iOS가 그렇다.
      return result == null || result == 1;
    } catch (e) {
      AppLogger.error('tts', '기기 음성 실패 → 서버로 넘어간다: $e');
      return false;
    }
  }

  /// 읽을 언어가 바뀐 때만 기기 음성을 다시 맞춘다 — 같은 기기에서 일과마다 언어가 다를 수 있다.
  ///
  /// 기기가 그 언어를 못 읽으면 false 다. 확인 자체가 실패하면(플랫폼이 답을 안 줌) 읽을 수 있다고 본다.
  Future<bool> _ensureConfigured(String language) async {
    await _preferGoogleEngine();
    final tag = ttsLocaleOf(language);
    if (_configuredLanguage != tag) {
      if (!await _isLanguageUsable(tag)) return false;
      await _tts.setLanguage(tag);
      _configuredLanguage = tag;
    }
    if (!_rateSet) {
      await _tts.setSpeechRate(_rate);
      _rateSet = true;
    }
    return true;
  }

  Future<bool> _isLanguageUsable(String tag) async {
    try {
      return await _tts.isLanguageAvailable(tag) != false;
    } catch (e) {
      AppLogger.error('tts', '기기 음성 언어 확인 실패 → 읽을 수 있다고 본다: $e');
      return true;
    }
  }

  /// 안드로이드에서 Google 엔진이 있으면 쓴다. 없거나 실패하면 기기 기본 엔진을 그대로 쓴다.
  ///
  /// 엔진을 못 고르는 것이 음성 자체를 막으면 안 되므로 예외는 삼키지 않고 기록만 하고 넘어간다.
  Future<void> _preferGoogleEngine() async {
    if (_engineChosen || !_isAndroid) return;
    _engineChosen = true;
    try {
      final engines = await _tts.getEngines;
      final isGoogleEngineInstalled =
          engines is List && engines.contains(googleEngine);
      if (isGoogleEngineInstalled) await _tts.setEngine(googleEngine);
      // 실기기에서 어느 엔진으로 읽는지 확인용 (목록이 비면 매니페스트 TTS_SERVICE 누락)
      AppLogger.speech(
        'device engines=$engines → '
        '${isGoogleEngineInstalled ? googleEngine : 'default'}',
      );
    } catch (e) {
      AppLogger.error('tts', 'Google 음성 엔진 고르기 실패 → 기기 기본 엔진을 쓴다: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      AppLogger.error('tts', '기기 음성 정지 실패: $e');
    }
  }

  @override
  void dispose() => _tts.stop();
}

/// 서버 TTS (Supertonic).
///
/// 기기에 한국어 음성이 없을 때 쓴다. WAV를 받아 재생하므로 네트워크가 필요하고
/// 파일이 크다(실측 375KB) — 그래서 **2순위**다.
///
/// 엔진은 `supertonic`을 고정한다. CPU 전용이라 "GPU 1개만 실행" 정책의 예외이며
/// 항상 켜져 있다. GPU 엔진을 고르면 꺼져 있어 503이 난다.
class RemoteSpeech implements SpeechService {
  RemoteSpeech({Dio? dio, AudioPlayer? player})
    : _dio = dio ?? Dio(),
      _player = player ?? AudioPlayer();

  final Dio _dio;
  final AudioPlayer _player;

  /// CPU 전용이라 항상 켜져 있는 엔진
  static const engine = 'supertonic';

  /// 여성 1 — 아동에게 친근한 톤
  static const voice = 'F1';

  /// 서버 제한. 넘기면 400이 온다.
  static const maxLength = 500;

  /// 서버 음성이 읽는 일과 언어 코드
  @visibleForTesting
  static const supportedLanguages = <String>{'ko'};

  @override
  Future<bool> speak(String text, {String language = 'ko', StoredSpeechSource? stored}) async {
    // 서버 음성은 한국어 `F1` 뿐 — 다른 언어는 요청하지 않고 실패해 글만 보여준다
    if (!supportedLanguages.contains(language)) {
      AppLogger.error('tts', '서버 음성이 $language 를 읽지 않아 건너뛴다');
      return false;
    }
    final apiKey = AppConfig.ttsApiKey;
    // 키가 없으면 서버를 부를 수 없다. 기기 음성만으로도 대개 동작한다.
    if (apiKey.isEmpty) {
      AppLogger.error('tts', '서버 키가 없어 건너뛴다');
      return false;
    }

    try {
      final res = await _dio.post<List<int>>(
        '${AppConfig.ttsBaseUrl}/tts',
        data: {
          // 길이 때문에 실패하느니 앞부분이라도 들리는 편이 낫다
          'text': text.length > maxLength ? text.substring(0, maxLength) : text,
          'engine': engine,
          'voice': voice,
        },
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'X-API-Key': apiKey},
        ),
      );

      final bytes = res.data;
      if (bytes == null || bytes.isEmpty) return false;

      await _player.stop();
      await _player.play(BytesSource(Uint8List.fromList(bytes)));
      return true;
    } catch (e) {
      AppLogger.error('tts', '서버 음성 실패: $e');
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      AppLogger.error('tts', '서버 음성 정지 실패: $e');
    }
  }

  @override
  void dispose() => _player.dispose();
}

/// 미리 만든 단계 음성 재생 (#675): 캐시 파일 > 없으면 받아서 재생
///
/// 한국어 일과만 (서버 음성이 한국어 목소리). 위치가 없거나 받지 못하면 false > 다음 순서로.
class StoredSpeech implements SpeechService {
  StoredSpeech({required CardSpeechRepository repository, AudioPlayer? player})
      : _repository = repository,
        _player = player ?? AudioPlayer();

  final CardSpeechRepository _repository;
  final AudioPlayer _player;

  @override
  Future<bool> speak(String text, {String language = 'ko', StoredSpeechSource? stored}) async {
    if (stored == null || !RemoteSpeech.supportedLanguages.contains(language)) return false;
    try {
      final file = await _repository.fileFor(stored);
      if (file == null) return false;
      await _player.stop();
      await _player.play(DeviceFileSource(file.path));
      return true;
    } catch (e) {
      AppLogger.error('tts', '저장 음성 재생 실패 → 기기 음성: $e');
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      AppLogger.error('tts', '저장 음성 정지 실패: $e');
    }
  }

  @override
  void dispose() => _player.dispose();
}

/// 순서대로 시도: 앞이 실패하면 다음 (안드로이드 저장 > 기기 > 실시간, 아이폰 기기 > 실시간)
///
/// 어느 쪽이 울리는지 확신할 수 없어 **정지할 때 전부 멈춘다** — 하나만 멈추면 소리가 남는다.
class FallbackSpeech implements SpeechService {
  FallbackSpeech(this.engines);

  final List<SpeechService> engines;

  @override
  Future<bool> speak(String text, {String language = 'ko', StoredSpeechSource? stored}) async {
    if (text.trim().isEmpty) return false;
    for (final engine in engines) {
      if (await engine.speak(text, language: language, stored: stored)) return true;
    }
    return false;
  }

  @override
  Future<void> stop() async {
    for (final engine in engines) {
      await engine.stop();
    }
  }

  @override
  void dispose() {
    for (final engine in engines) {
      engine.dispose();
    }
  }
}

/// 플랫폼별 재생 순서
///
/// 안드로이드: 기기 목소리가 기종마다 쉬고 흔들려(#675) 미리 만든 음성 먼저.
/// 아이폰: 기기 목소리가 좋아 그대로 (저장 음성은 만들지도 않음).
@visibleForTesting
List<SpeechService> speechEnginesFor({
  required bool isAndroid,
  required SpeechService Function() createStored,
  required SpeechService device,
  required SpeechService remote,
}) =>
    isAndroid ? [createStored(), device, remote] : [device, remote];

/// 일과 화면 진입 시 저장 음성 정리·미리 받기 (#675). 저장 음성을 쓰는 안드로이드만, 던지지 않음
void prefetchStoredSpeech(WidgetRef ref, String routineId, List<ActionCard> cards) {
  if (defaultTargetPlatform != TargetPlatform.android || routineId.isEmpty) return;
  unawaited(ref.read(cardSpeechRepositoryProvider).syncRoutine(routineId, cards));
}

final speechServiceProvider = Provider<SpeechService>((ref) {
  final service = FallbackSpeech(speechEnginesFor(
    isAndroid: defaultTargetPlatform == TargetPlatform.android,
    createStored: () => StoredSpeech(repository: ref.watch(cardSpeechRepositoryProvider)),
    device: DeviceSpeech(),
    remote: RemoteSpeech(),
  ));
  ref.onDispose(service.dispose);
  return service;
});
