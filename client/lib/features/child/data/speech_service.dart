import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/config/app_config.dart';

/// 카드 문장을 소리로 읽어준다.
///
/// **글을 못 읽는 아동에게는 음성이 유일한 정보 경로다** (docs/README.md).
/// 화면은 이 인터페이스만 알면 되고, 어느 엔진이 소리를 냈는지 알 필요가 없다.
abstract interface class SpeechService {
  /// 읽어준다. **절대 throw하지 않는다** — 실패하면 false.
  Future<bool> speak(String text);

  /// 재생 중이면 멈춘다. 화면을 벗어날 때도 부른다.
  Future<void> stop();

  void dispose();
}

/// 기기 내장 TTS.
///
/// 네트워크가 필요 없고 지연이 짧아 **1순위**다.
/// 다만 한국어 음성이 없는 기기·에뮬레이터에서는 조용히 실패한다.
class DeviceSpeech implements SpeechService {
  DeviceSpeech({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  var _configured = false;

  /// 아동이 듣기 편한 속도. 기본값(1.0)은 조금 빠르다.
  static const _rate = 0.45;

  @override
  Future<bool> speak(String text) async {
    try {
      await _ensureConfigured();

      // 이전 재생이 남아 있으면 겹친다
      await _tts.stop();

      final result = await _tts.speak(text);
      // 플랫폼마다 1 또는 null을 준다. null도 성공으로 본다 — iOS가 그렇다.
      return result == null || result == 1;
    } catch (e) {
      debugPrint('[tts] 기기 음성 실패 → 서버로 넘어간다: $e');
      return false;
    }
  }

  Future<void> _ensureConfigured() async {
    if (_configured) return;

    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(_rate);
    _configured = true;
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('[tts] 기기 음성 정지 실패: $e');
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

  @override
  Future<bool> speak(String text) async {
    final apiKey = AppConfig.ttsApiKey;
    // 키가 없으면 서버를 부를 수 없다. 기기 음성만으로도 대개 동작한다.
    if (apiKey.isEmpty) {
      debugPrint('[tts] 서버 키가 없어 건너뛴다');
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
      debugPrint('[tts] 서버 음성 실패: $e');
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('[tts] 서버 음성 정지 실패: $e');
    }
  }

  @override
  void dispose() => _player.dispose();
}

/// 기기 → 서버 순으로 시도한다.
///
/// 어느 쪽이 성공했는지 기억해 **정지할 때 양쪽을 다 멈춘다** — 어느 하나만
/// 멈추면 소리가 남는다.
class FallbackSpeech implements SpeechService {
  FallbackSpeech({required this.device, required this.remote});

  final SpeechService device;
  final SpeechService remote;

  @override
  Future<bool> speak(String text) async {
    if (text.trim().isEmpty) return false;

    if (await device.speak(text)) return true;
    return remote.speak(text);
  }

  @override
  Future<void> stop() async {
    // 둘 다 멈춘다. 어느 쪽이 울리는지 확신할 수 없다.
    await device.stop();
    await remote.stop();
  }

  @override
  void dispose() {
    device.dispose();
    remote.dispose();
  }
}

final speechServiceProvider = Provider<SpeechService>((ref) {
  final service = FallbackSpeech(
    device: DeviceSpeech(),
    remote: RemoteSpeech(),
  );
  ref.onDispose(service.dispose);
  return service;
});
