import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/shared/models/character.dart';
import 'package:elum/features/onboarding/domain/image_style.dart';
import 'package:elum/features/onboarding/domain/onboarding_profile.dart';
import 'package:elum/shared/models/support_goal.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';


/// 온보딩 문구를 ARB 로 옮겨도 API·`ko` 문구가 같고, 서버로 가는 값(apiValue)은 그대로다.
void main() {
  final ko = lookupAppLocalizations(const Locale('ko'));

  group('enum — 라벨은 ARB, 서버 값은 그대로', () {
    test('캐릭터', () {
      // 서버 CharacterType 으로 가는 값과 순서(화면 배치)
      expect(CardCharacter.values.map((c) => c.apiValue), ['LULU', 'POPO']);
      expect(CardCharacter.values.map((c) => c.name), ['cat', 'fox']);
      expect(CardCharacter.fromApiValue('POPO'), CardCharacter.fox);
      expect(CardCharacter.fromApiValue('여우'), isNull);
    });

    test('카드 그림 방식', () {
      expect(ImageStyle.values.map((s) => s.apiValue), [
        'PHOTO_ONLY',
        'CARTOON',
        'REALISTIC',
      ]);
      expect(ImageStyle.fromApiValue('PHOTO_ONLY'), ImageStyle.photoOnly);
      // 라벨(한글)은 식별자가 아니다 — 알 수 없는 값은 기본 만화
      expect(ImageStyle.fromApiValue('실사'), ImageStyle.cartoon);
    });

    test('도움 목표 — 서버로 가는 supportGoals 값', () {
      expect(SupportGoal.values.map((g) => g.apiValue), [
        'STEP_BY_STEP',
        'PREPARE_ITEMS',
        'PREPARE_NEW',
        'INDEPENDENT',
      ]);
      expect(SupportGoal.fromApiValue('INDEPENDENT'), SupportGoal.independent);
      expect(SupportGoal.fromApiValue('혼자 끝까지 해내는 경험을 만들어요'), isNull);
    });

    test('호칭이 비면 이룸이로 대신한다', () {
      expect(const OnboardingProfile().displayName, '이룸이');
      expect(const OnboardingProfile(childNickname: '  ').displayName, '이룸이');
      expect(const OnboardingProfile(childNickname: ' 하늘 ').displayName, '하늘');
    });
  });

  group('이름이 들어가는 제목 — 받침 있음·없음', () {
    test('캐릭터 고르기', () {
      expect(ko.onboardingCharacterTitle('하늘'), '하늘의 하루를 함께할\n친구를 골라주세요');
      expect(ko.onboardingCharacterTitle('바다'), '바다의 하루를 함께할\n친구를 골라주세요');
    });

    test('도움 목표', () {
      expect(ko.onboardingGoalsTitle('하늘'), '하늘의 어떤 순간을\n도와주고 싶으신가요?');
      expect(ko.onboardingGoalsTitle('바다'), '바다의 어떤 순간을\n도와주고 싶으신가요?');
    });
  });
}
