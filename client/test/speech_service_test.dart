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

  });

  group('기기 음성 엔진', () {
    test('기기가 그 언어를 못 읽으면 실패로 돌려 서버로 넘긴다', () async {
      final tts = _FakeTts(engines: [], languageAvailable: false);

      final ok = await DeviceSpeech(tts: tts, isAndroid: true).speak('옷을 입어요');

      expect(ok, isFalse);
      expect(tts.spoken, isEmpty);
    });

  });

  group('서버 음성', () {
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
    this.languageAvailable = true,
  });

  final List<String>? engines;
  final bool languageAvailable;
  String? engineSet;
  var engineCalls = 0;
  final spoken = <String>[];

  @override
  Future<dynamic> get getEngines async {
    return engines;
  }

  @override
  Future<dynamic> setEngine(String engine) async {
    engineCalls++;
    engineSet = engine;
  }

  @override
  Future<dynamic> isLanguageAvailable(String language) async {
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
