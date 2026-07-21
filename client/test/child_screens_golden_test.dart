import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/child/presentation/child_home_screen.dart';
import 'package:elum/features/child/presentation/child_stars_screen.dart';
import 'package:elum/features/child/domain/reward_character.dart';
import 'package:elum/features/child/presentation/reward_screen.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';

/// 아이 모드 화면 골든 (이슈 #69).
///
/// **골든은 "Figma와 같은가"를 판단해주지 못한다.** 첫 이미지가 틀리면
/// 틀린 것을 고정한다. 그래서 최초 승인은 반드시 사람이 눈으로 하고,
/// 이후에는 회귀 방지용으로 동작한다 (client/CLAUDE.md §6).
///
/// 이미지는 `test/goldens/`에 생성된다:
/// ```
/// flutter test --update-goldens test/child_screens_golden_test.dart
/// ```
void main() {
  useFigmaViewport();

  const cards = [
    ActionCard(
      id: 'c1',
      title: '옷을 입어요',
      description: '학교에 갈 옷을 차례대로 입어요',
      stepOrder: 1,
    ),
    ActionCard(
      id: 'c2',
      title: '우산을 챙겨요',
      description: '현관에서 우산을 챙겨요',
      stepOrder: 2,
    ),
  ];

  /// 폰트를 안 실어주면 글자가 전부 네모로 렌더된다.
  /// 골든에서는 그 자체가 회귀 신호를 죽이므로 실제 앱과 같은 폰트를 불러온다.
  setUpAll(() async {
    for (final family in ['TmoneyRoundWind']) {
      final loader = FontLoader(family)
        ..addFont(
          rootBundle.load('assets/fonts/TmoneyRoundWindExtraBold.ttf'),
        )
        ..addFont(rootBundle.load('assets/fonts/TmoneyRoundWindRegular.ttf'));
      await loader.load();
    }
  });

  Widget wrap(Widget screen) {
    return ProviderScope(
      overrides: [testStorageOverride(onboardingCompleted: true)],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          home: screen,
        ),
      ),
    );
  }

  testWidgets('아이 홈 — 일과 목록 (356:5079)', (tester) async {
    await tester.pumpWidget(wrap(const ChildHomeScreen()));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChildHomeScreen)),
    );
    container.read(routineFlowProvider.notifier).state = RoutineFlowState(
      routine: const Routine(
        id: 'r1',
        title: '비 오는 날 학교에 가요',
        status: 'CONFIRMED',
        steps: cards,
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ChildHomeScreen),
      matchesGoldenFile('goldens/child_home_list.png'),
    );
  });

  testWidgets('아이 홈 — 빈 상태 (343:4543)', (tester) async {
    await tester.pumpWidget(wrap(const ChildHomeScreen()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ChildHomeScreen),
      matchesGoldenFile('goldens/child_home_empty.png'),
    );
  });

  testWidgets('아이 별 모으기 (364:8219)', (tester) async {
    await tester.pumpWidget(wrap(const ChildStarsScreen()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ChildStarsScreen),
      matchesGoldenFile('goldens/child_stars.png'),
    );
  });

  // 보상 화면은 캐릭터를 **무작위로** 뽑는다. 그대로 골든을 찍으면 실행마다
  // 이미지가 달라져 회귀 신호가 죽는다. 캐릭터별로 따로 고정한다.
  for (final character in RewardCharacter.values) {
    testWidgets('아이 보상 — ${character.name}', (tester) async {
      await tester.pumpWidget(wrap(RewardScreen(character: character)));
      // 등장 애니메이션이 끝난 뒤를 찍는다
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await expectLater(
        find.byType(RewardScreen),
        matchesGoldenFile('goldens/child_reward_${character.name}.png'),
      );
    });
  }
}
