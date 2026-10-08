import 'package:elum/core/config/app_config.dart';
import 'package:elum/features/child/data/speech_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 카드 읽어주기 테스트.
///
/// 글을 못 읽는 아동에게는 음성이 유일한 정보 경로다. 기기 음성이 없는
/// 환경에서도 소리가 나야 하므로 **폴백이 실제로 도는지** 고정한다.
void main() {
  // AudioPlayer가 생성 시 플랫폼 채널을 건드린다
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => dotenv.loadFromString(envString: '', isOptional: true));

  group('폴백 순서', () {
    test('기기 음성이 되면 서버를 부르지 않는다', () async {
      // 서버는 375KB를 받아야 해서 느리고 비싸다. 기기가 되면 그걸 쓴다.
      final device = _FakeSpeech(succeeds: true);
      final remote = _FakeSpeech(succeeds: true);

      final ok = await FallbackSpeech(device: device, remote: remote)
          .speak('옷을 입어요');

      expect(ok, isTrue);
      expect(device.spokenTexts, ['옷을 입어요']);
      expect(remote.spokenTexts, isEmpty);
    });

    test('기기 음성이 안 되면 서버로 넘어간다', () async {
      // 에뮬레이터·한국어 미설치 기기에서 실제로 일어난다
      final device = _FakeSpeech(succeeds: false);
      final remote = _FakeSpeech(succeeds: true);

      final ok = await FallbackSpeech(device: device, remote: remote)
          .speak('옷을 입어요');

      expect(ok, isTrue);
      expect(remote.spokenTexts, ['옷을 입어요']);
    });

    test('둘 다 실패해도 예외를 던지지 않는다', () async {
      final fallback = FallbackSpeech(
        device: _FakeSpeech(succeeds: false),
        remote: _FakeSpeech(succeeds: false),
      );

      expect(await fallback.speak('옷을 입어요'), isFalse);
    });

    test('빈 문자열은 아무것도 하지 않는다', () async {
      final device = _FakeSpeech(succeeds: true);
      final fallback = FallbackSpeech(
        device: device,
        remote: _FakeSpeech(succeeds: true),
      );

      expect(await fallback.speak('   '), isFalse);
      expect(device.spokenTexts, isEmpty);
    });

    test('정지하면 양쪽을 다 멈춘다', () async {
      // 어느 쪽이 울리는지 확신할 수 없다. 하나만 멈추면 소리가 남는다.
      final device = _FakeSpeech(succeeds: true);
      final remote = _FakeSpeech(succeeds: true);

      await FallbackSpeech(device: device, remote: remote).stop();

      expect(device.stopCount, 1);
      expect(remote.stopCount, 1);
    });
  });

  group('기기 음성 엔진', () {
    test('안드로이드에 Google 엔진이 있으면 그것으로 고정한다', () async {
      final tts = _FakeTts(engines: ['com.samsung.SMT', DeviceSpeech.googleEngine]);

      await DeviceSpeech(tts: tts, isAndroid: true).speak('옷을 입어요');

      expect(tts.engineSet, DeviceSpeech.googleEngine);
      expect(tts.spoken, ['옷을 입어요']);
    });

    test('Google 엔진이 없으면 기본 엔진 그대로 읽는다', () async {
      final tts = _FakeTts(engines: ['com.samsung.SMT']);

      final ok = await DeviceSpeech(tts: tts, isAndroid: true).speak('옷을 입어요');

      expect(ok, isTrue);
      expect(tts.engineSet, isNull);
    });

    test('엔진 목록을 못 읽어도 읽는다', () async {
      final tts = _FakeTts(engines: null, enginesThrow: true);

      final ok = await DeviceSpeech(tts: tts, isAndroid: true).speak('옷을 입어요');

      expect(ok, isTrue);
      expect(tts.spoken, ['옷을 입어요']);
    });

    test('안드로이드가 아니면 엔진을 건드리지 않는다', () async {
      final tts = _FakeTts(engines: [DeviceSpeech.googleEngine]);

      await DeviceSpeech(tts: tts, isAndroid: false).speak('옷을 입어요');

      expect(tts.engineSet, isNull);
    });

    test('기기가 그 언어를 못 읽으면 실패로 돌려 서버로 넘긴다', () async {
      final tts = _FakeTts(engines: [], languageAvailable: false);

      final ok = await DeviceSpeech(tts: tts, isAndroid: true).speak('옷을 입어요');

      expect(ok, isFalse);
      expect(tts.spoken, isEmpty);
    });

    test('언어 확인이 예외여도 읽는다', () async {
      final tts = _FakeTts(engines: [], languageThrows: true);

      final ok = await DeviceSpeech(tts: tts, isAndroid: true).speak('옷을 입어요');

      expect(ok, isTrue);
    });

    test('엔진은 처음 한 번만 고른다', () async {
      final tts = _FakeTts(engines: [DeviceSpeech.googleEngine]);
      final speech = DeviceSpeech(tts: tts, isAndroid: true);

      await speech.speak('하나');
      await speech.speak('둘');

      expect(tts.engineCalls, 1);
    });
  });

  group('서버 음성', () {
    test('키가 없으면 서버 폴백만 꺼진다', () {
      // 키가 없어도 기기 음성은 동작해야 한다 — 기능 전체가 죽지 않는다.
      // (AudioPlayer가 플랫폼 채널을 타 단위 테스트에서 실제 재생은 못 만든다)
      dotenv.loadFromString(envString: 'ELUM_TTS_API_KEY=');

      expect(AppConfig.ttsApiKey, isEmpty);
    });

    test('기본 서버 주소가 있다', () {
      // .env가 없어도 앱이 떠야 한다
      dotenv.loadFromString(envString: '', isOptional: true);

      expect(AppConfig.ttsBaseUrl, isNotEmpty);
    });

    test('CPU 전용 엔진을 쓴다', () {
      // GPU 엔진은 "한 번에 1개" 정책이라 대부분 꺼져 있어 503이 난다
      expect(RemoteSpeech.engine, 'supertonic');
    });

    test('서버 길이 제한을 안다', () {
      expect(RemoteSpeech.maxLength, 500);
    });
  });
}

/// 호출만 기록하는 대역. 실제 소리를 내지 않는다.
class _FakeSpeech implements SpeechService {
  _FakeSpeech({required this.succeeds});

  final bool succeeds;
  final spokenTexts = <String>[];
  var stopCount = 0;

  @override
  Future<bool> speak(String text, {String language = 'ko'}) async {
    spokenTexts.add(text);
    return succeeds;
  }

  @override
  Future<void> stop() async => stopCount++;

  @override
  void dispose() {}
}


/// 플랫폼 채널 없이 엔진 선택만 기록하는 가짜 TTS.
class _FakeTts extends FlutterTts {
  _FakeTts({
    required this.engines,
    this.enginesThrow = false,
    this.languageAvailable = true,
    this.languageThrows = false,
  });

  final List<String>? engines;
  final bool enginesThrow;
  final bool languageAvailable;
  final bool languageThrows;
  String? engineSet;
  var engineCalls = 0;
  final spoken = <String>[];

  @override
  Future<dynamic> get getEngines async {
    if (enginesThrow) throw Exception('엔진 목록 실패');
    return engines;
  }

  @override
  Future<dynamic> setEngine(String engine) async {
    engineCalls++;
    engineSet = engine;
  }

  @override
  Future<dynamic> isLanguageAvailable(String language) async {
    if (languageThrows) throw Exception('언어 확인 실패');
    return languageAvailable;
  }

  @override
  Future<dynamic> setLanguage(String language) async => 1;

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;

  @override
  Future<dynamic> stop() async => 1;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spoken.add(text);
    return 1;
  }
}
