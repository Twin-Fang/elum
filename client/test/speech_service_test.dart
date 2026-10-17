import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:elum/features/child/data/speech_service.dart';
import 'package:flutter/services.dart';
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

      final ok = await FallbackSpeech([device, remote])
          .speak('옷을 입어요');

      expect(ok, isTrue);
      expect(device.spokenTexts, ['옷을 입어요']);
      expect(remote.spokenTexts, isEmpty);
    });

    test('기기 음성이 안 되면 서버로 넘어간다', () async {
      // 에뮬레이터·한국어 미설치 기기에서 실제로 일어난다
      final device = _FakeSpeech(succeeds: false);
      final remote = _FakeSpeech(succeeds: true);

      final ok = await FallbackSpeech([device, remote])
          .speak('옷을 입어요');

      expect(ok, isTrue);
      expect(remote.spokenTexts, ['옷을 입어요']);
    });

    test('둘 다 실패해도 예외를 던지지 않는다', () async {
      final fallback = FallbackSpeech([_FakeSpeech(succeeds: false), _FakeSpeech(succeeds: false)]);

      expect(await fallback.speak('옷을 입어요'), isFalse);
    });

  });

  group('플랫폼별 순서 (#675)', () {
    const stored = (routineId: 'r-1', stepId: 's-1', speechPath: 's-1/a.wav');

    test('안드로이드는 저장 음성이 되면 기기 음성을 부르지 않는다 — 유령 목소리가 나지 않게', () async {
      final storedSpeech = _FakeSpeech(succeeds: true);
      final device = _FakeSpeech(succeeds: true);
      final engines = speechEnginesFor(
        isAndroid: true, createStored: () => storedSpeech, device: device, remote: _FakeSpeech(succeeds: true));

      await FallbackSpeech(engines).speak('옷을 입어요', stored: stored);

      expect(storedSpeech.storedSources, [stored]);
      expect(device.spokenTexts, isEmpty);
    });

    test('안드로이드에서 저장 음성이 없으면 기기 음성으로 읽는다 — 소리가 끊기지 않게', () async {
      final device = _FakeSpeech(succeeds: true);
      final engines = speechEnginesFor(
        isAndroid: true, createStored: () => _FakeSpeech(succeeds: false), device: device,
        remote: _FakeSpeech(succeeds: true));

      expect(await FallbackSpeech(engines).speak('옷을 입어요', stored: stored), isTrue);
      expect(device.spokenTexts, ['옷을 입어요']);
    });

    test('아이폰은 저장 음성을 만들지도 부르지도 않는다 — 잘 되던 아이폰이 바뀌지 않게', () {
      var isStoredCreated = false;
      final engines = speechEnginesFor(
        isAndroid: false,
        createStored: () {
          isStoredCreated = true;
          return _FakeSpeech(succeeds: true);
        },
        device: _FakeSpeech(succeeds: true),
        remote: _FakeSpeech(succeeds: true));

      expect(engines, hasLength(2));
      expect(isStoredCreated, isFalse);
    });

    test('정지하면 셋 다 멈춘다', () async {
      final all = [_FakeSpeech(succeeds: true), _FakeSpeech(succeeds: true), _FakeSpeech(succeeds: true)];

      await FallbackSpeech(all).stop();

      expect(all.map((e) => e.stopCount), [1, 1, 1]);
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
    late _RecordingAdapter adapter;
    late _SilentPlayer player;
    late RemoteSpeech remote;

    setUp(() {
      // 플레이어 생성 시 부르는 플랫폼 채널을 비워 둔다
      for (final channel in ['xyz.luan/audioplayers.global', 'xyz.luan/audioplayers']) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
      }
      dotenv.loadFromString(envString: 'ELUM_TTS_API_KEY=test-key');
      adapter = _RecordingAdapter();
      player = _SilentPlayer();
      remote = RemoteSpeech(dio: Dio()..httpClientAdapter = adapter, player: player);
    });

    test('ko 는 supertonic F1 요청을 그대로 보낸다', () async {
      final ok = await remote.speak('옷을 입어요');

      expect(ok, isTrue);
      expect(adapter.bodies, [
        {'text': '옷을 입어요', 'engine': 'supertonic', 'voice': 'F1'},
      ]);
      expect(adapter.headers.single['X-API-Key'], 'test-key');
      expect(adapter.paths.single, endsWith('/tts'));
      expect(player.playCount, 1);
    });

    test('ko 가 아닌 언어는 서버를 부르지 않고 false 다 — 한국어 음성이 읽지 않게', () async {
      for (final language in ['en', 'ja', 'zh', 'es']) {
        expect(await remote.speak('Put on your clothes', language: language), isFalse);
      }
      expect(adapter.bodies, isEmpty);
      expect(player.playCount, 0);
    });
  });
}

/// 호출만 기록하는 대역. 실제 소리를 내지 않는다.
class _FakeSpeech implements SpeechService {
  _FakeSpeech({required this.succeeds});

  final bool succeeds;
  final spokenTexts = <String>[];
  final storedSources = <StoredSpeechSource?>[];
  var stopCount = 0;

  @override
  Future<bool> speak(String text, {String language = 'ko', StoredSpeechSource? stored}) async {
    spokenTexts.add(text);
    storedSources.add(stored);
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

/// 요청만 기록하고 가짜 음성 바이트를 돌려주는 어댑터.
class _RecordingAdapter implements HttpClientAdapter {
  final bodies = <Object?>[];
  final headers = <Map<String, dynamic>>[];
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    bodies.add(options.data);
    headers.add(options.headers);
    paths.add(options.path);
    return ResponseBody.fromBytes([1, 2, 3], 200);
  }

  @override
  void close({bool force = false}) {}
}

/// 소리를 내지 않고 재생 횟수만 센다.
class _SilentPlayer extends AudioPlayer {
  var playCount = 0;

  @override
  Future<void> play(Source source, {double? volume, double? balance, AudioContext? ctx, Duration? position, PlayerMode? mode}) async => playCount++;

  @override
  Future<void> stop() async {}
}
