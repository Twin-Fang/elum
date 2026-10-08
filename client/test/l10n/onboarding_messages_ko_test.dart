import 'package:elum/core/l10n/current_l10n.dart';
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/shared/models/character.dart';
import 'package:elum/features/onboarding/domain/image_style.dart';
import 'package:elum/features/onboarding/domain/onboarding_profile.dart';
import 'package:elum/shared/models/support_goal.dart';
import 'package:elum/features/onboarding/presentation/card_completion_screen.dart';
import 'package:elum/features/onboarding/presentation/character_screen.dart';
import 'package:elum/features/onboarding/presentation/goals_screen.dart';
import 'package:elum/features/onboarding/presentation/image_style_screen.dart';
import 'package:elum/features/onboarding/presentation/pin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/device_viewport.dart';
import '../helpers/pump_with_locale.dart';
import '../helpers/test_storage.dart';
import 'package:elum/core/router/routes.dart';

/// 온보딩 문구를 ARB 로 옮겨도 API·`ko` 문구가 같고, 서버로 가는 값(apiValue)은 그대로다.
void main() {
  useFigmaViewport();
  final ko = lookupAppLocalizations(const Locale('ko'));

  setUp(setAppL10nForTest);
  tearDown(setAppL10nForTest);

  group('enum — 라벨은 ARB, 서버 값은 그대로', () {
    test('캐릭터', () {
      expect(CardCharacter.cat.label, '고양이');
      expect(CardCharacter.cat.displayName, '루루');
      expect(CardCharacter.fox.label, '여우');
      expect(CardCharacter.fox.displayName, '포포');
      expect(AgentPersona.chick.label, '병아리');
      // 서버 CharacterType 으로 가는 값과 순서(화면 배치)
      expect(CardCharacter.values.map((c) => c.apiValue), ['LULU', 'POPO']);
      expect(CardCharacter.values.map((c) => c.name), ['cat', 'fox']);
      expect(CardCharacter.fromApiValue('POPO'), CardCharacter.fox);
      expect(CardCharacter.fromApiValue('여우'), isNull);
    });

    test('카드 그림 방식', () {
      expect(ImageStyle.cartoon.label, '만화');
      expect(ImageStyle.cartoon.description, '캐릭터가 나오는 그림이에요');
      expect(ImageStyle.realistic.label, '실사');
      expect(ImageStyle.realistic.description, '실제 물건 사진처럼 보여요');
      expect(ImageStyle.photoOnly.label, '기본 그림');
      expect(
        ImageStyle.photoOnly.description,
        '간단한 그림 기호가 들어가요. 사진으로 바꿀 수 있어요',
      );
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
      expect(SupportGoal.stepByStep.label, '해야 할 일을 순서대로 이해해요');
      expect(SupportGoal.prepareItems.label, '필요한 준비물을 스스로 챙겨요');
      expect(SupportGoal.prepareNew.label, '새로운 상황을 미리 준비해요');
      expect(SupportGoal.independent.label, '혼자 끝까지 해내는 경험을 만들어요');
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

  group('화면이 ARB 를 읽는다 — 비 ko 로케일은 ko 로 떨어진다', () {
    Widget host(Widget screen) => InheritedGoRouter(
      goRouter: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => screen),
          GoRoute(path: Routes.guardian, builder: (_, _) => const SizedBox()),
        ],
      ),
      child: screen,
    );

    Future<void> pumpScreen(
      WidgetTester tester,
      Widget screen, {
      Locale locale = const Locale('ko'),
    }) => pumpWithLocale(
      tester,
      host(screen),
      locale: locale,
      wrap: (app) =>
          ProviderScope(overrides: [testStorageOverride()], child: app),
    );

    for (final locale in const [Locale('ko'), Locale('en')]) {
      testWidgets('캐릭터 화면 (${locale.languageCode})', (tester) async {
        await pumpScreen(tester, const CharacterScreen(), locale: locale);
        expect(find.text('다음'), findsOneWidget);
        expect(find.text('이룸이의 하루를 함께할\n친구를 골라주세요'), findsOneWidget);
        expect(find.text('선택한 친구가 카드 속 주인공이 되어 도와줘요'), findsOneWidget);
      });

      testWidgets('도움 목표 화면 (${locale.languageCode})', (tester) async {
        await pumpScreen(tester, const GoalsScreen(), locale: locale);
        expect(find.text('이룸이의 어떤 순간을\n도와주고 싶으신가요?'), findsOneWidget);
        expect(find.text('여러 개를 선택할 수 있어요'), findsOneWidget);
        expect(find.text('해야 할 일을 순서대로 이해해요'), findsOneWidget);
      });

      testWidgets('그림 방식 화면 (${locale.languageCode})', (tester) async {
        await pumpScreen(tester, const ImageStyleScreen(), locale: locale);
        expect(find.text('카드 그림은 어떤 방식으로\n만들까요?'), findsOneWidget);
        expect(find.text('나중에 설정에서 바꿀 수 있어요'), findsOneWidget);
        expect(find.text('건너뛰기'), findsNothing);
        expect(find.text('만화'), findsOneWidget);
      });

      testWidgets('완료 화면 (${locale.languageCode})', (tester) async {
        await pumpScreen(tester, const CardCompletionScreen(), locale: locale);
        expect(find.text('내용 정리가 모두\n완료됐어요'), findsOneWidget);
        expect(find.text('100% 완료!'), findsOneWidget);
        // 1.5초 뒤 자동 이동 타이머를 비운다
        await tester.pump(const Duration(seconds: 2));
      });
    }

    testWidgets('입력한 이름이 제목에 들어간다 — 받침 있음·없음', (tester) async {
      for (final name in ['하늘', '바다']) {
        await pumpScreen(tester, const CharacterScreen());
        final container = ProviderScope.containerOf(
          tester.element(find.byType(CharacterScreen)),
        );
        container.read(onboardingProvider.notifier).setNickname(name);
        await tester.pump();
        expect(find.text('$name의 하루를 함께할\n친구를 골라주세요'), findsOneWidget);
      }
    });

    testWidgets('비밀암호 화면 — 만들기·재입력·불일치 안내', (tester) async {
      await pumpScreen(tester, const PinScreen());
      expect(find.text('보호자님만 아는\n비밀암호를 만들어주세요'), findsOneWidget);
      expect(find.text('보호자모드로 변경할 때 사용하는 암호예요'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pumpAndSettle();
      expect(find.text('암호를 한번 더\n입력해주세요'), findsOneWidget);

      // 재입력이 다르면 설명 자리에 안내가 뜬다
      await tester.enterText(find.byType(TextField), '1235');
      await tester.pumpAndSettle();
      expect(find.text('암호가 달라요. 다시 넣어주세요'), findsOneWidget);
      expect(find.text('보호자모드로 변경할 때 사용하는 암호예요'), findsNothing);

      // 다시 입력하기 시작하면 안내가 걷히고 원래 설명으로 돌아온다
      await tester.enterText(find.byType(TextField), '1');
      await tester.pumpAndSettle();
      expect(find.text('암호가 달라요. 다시 넣어주세요'), findsNothing);
      expect(find.text('보호자모드로 변경할 때 사용하는 암호예요'), findsOneWidget);
    });
  });
}
