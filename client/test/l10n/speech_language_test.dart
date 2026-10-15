import 'package:elum/features/child/data/speech_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_test/flutter_test.dart';

/// 음성도 일과 언어를 따른다. 기기 TTS 언어를 일과 언어로 맞춘다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ttsLocaleOf', () {
    test('일과 언어 → 기기 TTS 언어 태그', () {
      expect(ttsLocaleOf('ko'), 'ko-KR');
      expect(ttsLocaleOf('en'), 'en-US');
      expect(ttsLocaleOf('ja'), 'ja-JP');
      expect(ttsLocaleOf('zh'), 'zh-CN');
      expect(ttsLocaleOf('es'), 'es-ES');
      expect(ttsLocaleOf('fr'), 'ko-KR');
    });
  });

  group('DeviceSpeech', () {
    test('일과 언어로 기기 음성을 맞춘다', () async {
      final tts = _FakeTts();
      final speech = DeviceSpeech(tts: tts);

      await speech.speak('服を着ます', language: 'ja');

      expect(tts.languages, ['ja-JP']);
    });

  });

  group('FallbackSpeech', () {
    test('언어를 기기·서버 양쪽에 그대로 넘긴다', () async {
      final device = _LangSpeech(succeeds: false);
      final remote = _LangSpeech(succeeds: true);

      await FallbackSpeech(device: device, remote: remote).speak('x', language: 'ja');

      expect(device.languages, ['ja']);
      expect(remote.languages, ['ja']);
    });
  });
}

class _FakeTts extends FlutterTts {
  final languages = <String>[];
  final spoken = <String>[];
  var rateCalls = 0;

  @override
  Future<dynamic> setLanguage(String language) async {
    languages.add(language);
    return 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    rateCalls++;
    return 1;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spoken.add(text);
    return 1;
  }

  @override
  Future<dynamic> stop() async => 1;
}

class _LangSpeech implements SpeechService {
  _LangSpeech({required this.succeeds});

  final bool succeeds;
  final languages = <String>[];

  @override
  Future<bool> speak(String text, {String language = 'ko'}) async {
    languages.add(language);
    return succeeds;
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}
