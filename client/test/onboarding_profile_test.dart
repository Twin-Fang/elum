import 'package:elum/features/onboarding/domain/character.dart';
import 'package:elum/features/onboarding/domain/onboarding_profile.dart';
import 'package:elum/features/onboarding/domain/support_goal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OnboardingProfile 진행 조건', () {
    test('호칭이 비어있으면 다음으로 갈 수 없다', () {
      const profile = OnboardingProfile();
      expect(profile.canProceedFromName, isFalse);
    });

    test('공백만 입력한 것은 입력하지 않은 것으로 본다', () {
      const profile = OnboardingProfile(childNickname: '   ');
      expect(profile.canProceedFromName, isFalse);
    });

    test('목표는 최소 1개를 골라야 한다', () {
      const empty = OnboardingProfile();
      expect(empty.canProceedFromGoals, isFalse);

      const picked = OnboardingProfile(supportGoals: {SupportGoal.prepareItems});
      expect(picked.canProceedFromGoals, isTrue);
    });

    test('PIN은 4자리를 채워야 완료된다', () {
      const short = OnboardingProfile(guardianPin: '12');
      expect(short.isPinComplete, isFalse);

      const full = OnboardingProfile(guardianPin: '1234');
      expect(full.isPinComplete, isTrue);
    });

    test('호칭이 없으면 제목용 대체어를 준다', () {
      // 딥링크로 중간 진입하면 "의 어떤 순간을..."처럼 조사만 남는다
      const empty = OnboardingProfile();
      expect(empty.displayName, '우리 아이');

      const named = OnboardingProfile(childNickname: '하늘이');
      expect(named.displayName, '하늘이');
    });

    test('4개 항목이 모두 채워져야 온보딩이 완료된다', () {
      const profile = OnboardingProfile(
        childNickname: '하늘이',
        supportGoals: {SupportGoal.prepareItems},
        cardCharacter: CardCharacter.fox,
        guardianPin: '1234',
      );
      expect(profile.isComplete, isTrue);
    });
  });

  group('SupportGoal 서버 계약', () {
    // 서버 enum(SupportGoal.java)과 값이 어긋나면 카드 생성이 조용히 실패한다.
    test('apiValue가 서버 enum name과 일치한다', () {
      expect(SupportGoal.stepByStep.apiValue, 'STEP_BY_STEP');
      expect(SupportGoal.prepareItems.apiValue, 'PREPARE_ITEMS');
      expect(SupportGoal.prepareNew.apiValue, 'PREPARE_NEW');
      expect(SupportGoal.independent.apiValue, 'INDEPENDENT');
    });

    test('모르는 값이 와도 예외 대신 null을 준다', () {
      expect(SupportGoal.fromApiValue('UNKNOWN_GOAL'), isNull);
      expect(SupportGoal.fromApiValue('PREPARE_ITEMS'), SupportGoal.prepareItems);
    });
  });

  group('CardCharacter 서버 계약', () {
    // 서버 CharacterType(LULU/POPO)과 어긋나면 PATCH /api/member/character가
    // 역직렬화에 실패해 캐릭터 저장이 조용히 실패한다 (이슈 #89).
    test('apiValue가 서버 CharacterType enum name과 일치한다', () {
      expect(CardCharacter.cat.apiValue, 'LULU');
      expect(CardCharacter.fox.apiValue, 'POPO');
    });

    // 순서가 화면 배치다 — 고양이가 왼쪽, 여우가 오른쪽. 뒤집히면 화면이 조용히 바뀐다.
    test('enum 순서가 화면 배치(고양이, 여우)를 유지한다', () {
      expect(CardCharacter.values, [CardCharacter.cat, CardCharacter.fox]);
    });
  });
}
