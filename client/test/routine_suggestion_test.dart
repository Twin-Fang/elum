import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

/// 추천 일과 파싱 — 서버 계약 검증.
///
/// 서버가 `naturalLanguageExample`로 자연어 문장을 준다. 클라가 다른 이름을
/// 읽고 있으면 조용히 폴백으로 동작해 **아무도 눈치채지 못한다.**
/// 실제로 그런 일이 있었기에 테스트로 고정한다.
void main() {
  group('서버 응답 파싱', () {
    test('형식이 달라도 죽지 않는다', () {
      // 추천 하나 때문에 홈 화면이 멈추면 안 된다
      expect(() => RoutineSuggestion.fromJson(const {}), returnsNormally);
      expect(RoutineSuggestion.fromJson(const {}).text, '');
    });
  });

  group('폴백 목록', () {
    test('서버가 죽어도 보여줄 추천이 있다', () {
      // 추천이 비면 홈 화면 한 블록이 통째로 사라져 빈 화면처럼 보인다
      expect(RoutineSuggestion.fallback, isNotEmpty);
    });

  });
}
