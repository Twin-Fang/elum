import 'package:elum/shared/models/routine.dart';
import 'package:flutter_test/flutter_test.dart';

/// 일과의 언어(마스터 C5): 서버 `RoutineResponse.language`. 없으면 `ko`.
void main() {
  test('필드가 없는 옛 응답은 ko 다 — 기존 일과가 전부 한국어 일과다', () {
    expect(Routine.fromJson({'id': 'r1'}).language, 'ko');
    expect(const Routine(id: 'r1').language, 'ko');
  });

  test('서버가 준 언어 코드를 읽는다', () {
    for (final code in ['ko', 'en', 'ja', 'zh', 'es']) {
      expect(Routine.fromJson({'id': 'r1', 'language': code}).language, code);
    }
  });

  test('모르는 값·깨진 값은 ko 다 — 화면이 죽지 않는다', () {
    expect(Routine.fromJson({'id': 'r1', 'language': 'fr'}).language, 'ko');
    expect(Routine.fromJson({'id': 'r1', 'language': 'zh-Hans'}).language, 'ko');
    expect(Routine.fromJson({'id': 'r1', 'language': 7}).language, 'ko');
    expect(Routine.fromJson({'id': 'r1', 'language': null}).language, 'ko');
  });

  test('오프라인 캐시 왕복에서 언어가 남는다', () {
    final restored = Routine.fromJson(
      const Routine(id: 'r1', language: 'ja').toJson(),
    );
    expect(restored.language, 'ja');
  });
}
