import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

/// 추천 일과 파싱 — 서버 계약 검증.
///
/// 서버가 `naturalLanguageExample`로 자연어 문장을 준다. 클라가 다른 이름을
/// 읽고 있으면 조용히 폴백으로 동작해 **아무도 눈치채지 못한다.**
/// 실제로 그런 일이 있었기에 테스트로 고정한다.
void main() {
  group('서버 응답 파싱', () {
    test('naturalLanguageExample을 입력 문구로 읽는다', () {
      // 실측 응답 (GET /api/routines/suggestions)
      final s = RoutineSuggestion.fromJson(const {
        'icon': '🩺',
        'text': '건강검진 받기',
        'naturalLanguageExample': '아이가 건강검진을 받으러 병원에 가야 돼',
      });

      expect(s.icon, '🩺');
      expect(s.text, '건강검진 받기');
      // 입력창에는 자연어가 들어가야 한다. 명사구를 넣으면 맥락이 얇다.
      expect(s.inputText, '아이가 건강검진을 받으러 병원에 가야 돼');
    });

    test('칩에는 이모지와 라벨을 함께 보여준다', () {
      final s = RoutineSuggestion.fromJson(const {
        'icon': '👕',
        'text': '혼자 옷 갈아입기',
        'naturalLanguageExample': '아이가 혼자 옷을 갈아입는 연습을 하고 있어',
      });

      expect(s.label, '👕 혼자 옷 갈아입기');
    });

    test('자연어가 없으면 라벨로 폴백한다', () {
      // 서버가 옛 형태로 응답해도 화면이 비지 않아야 한다
      final s = RoutineSuggestion.fromJson(const {
        'icon': '🎨',
        'text': '미술 활동 준비',
      });

      expect(s.inputText, '미술 활동 준비');
    });

    test('이모지가 없어도 라벨이 깨지지 않는다', () {
      final s = RoutineSuggestion.fromJson(const {'text': '병원 방문 준비'});

      expect(s.label, '병원 방문 준비');
    });

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

    test('폴백도 자연어 문장을 갖는다', () {
      for (final s in RoutineSuggestion.fallback) {
        expect(s.inputText, isNotEmpty);
        // 명사구가 아니라 문장이어야 한다
        expect(s.inputText.length, greaterThan(s.text.length));
      }
    });
  });
}
