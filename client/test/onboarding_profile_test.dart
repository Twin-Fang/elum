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
}
