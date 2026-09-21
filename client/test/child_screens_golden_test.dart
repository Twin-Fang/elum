@Tags(['golden'])
library;

// 이 파일은 **CI에서 돌지 않는다** (`--exclude-tags golden`).
// 골든은 픽셀 비교라 macOS에서 만든 기준을 Linux CI가 통과하지 못한다 —
// blur·그라데이션 래스터가 환경마다 다르다. 코드 회귀가 아니다.
// 로컬에서는 그대로 돌아 회귀를 잡는다. 근거: 이슈 #218

import 'package:elum/core/theme/app_motion.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/child/presentation/child_home_screen.dart';
import 'package:elum/features/child/presentation/child_stars_screen.dart';
import 'package:elum/features/child/domain/reward_character.dart';
import 'package:elum/features/child/presentation/reward_screen.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';
import 'helpers/precache_images.dart';
import 'helpers/fake_dio.dart';
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

  Widget wrap(Widget screen) {
    return ProviderScope(
      overrides: [
        // 빈 상태 골든은 "서버가 0건을 줬을 때"를 그린다. mock을 걷어낸 뒤(#263)
        // 응답을 주지 않으면 조회가 실패해 에러 화면이 그려진다 — 빈 상태와 다르다.
        fakeDioOverride(const {'GET /api/routines/today': <dynamic>[]}),
        testStorageOverride(onboardingCompleted: true),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) =>
            MaterialApp(theme: AppTheme.light, home: screen),
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
    // 별은 PNG라 로딩을 기다려야 그려진다 (안 기다리면 빈 밤하늘이 굳는다)
    await precacheAllImages(tester);

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
      // 별의 둥둥 애니메이션이 repeat()로 무한 반복이라 pumpAndSettle은
      // 영원히 끝나지 않는다. 등장 연출(700ms)이 끝날 시간만큼만 명시적으로
      // 흘려보내고, float 주기(AppMotion.float)의 정확히 2배 지점 —
      // 즉 sin 곡선이 0으로 돌아오는 시점 — 에서 프레임을 고정해
      // 캡처마다 오프셋이 달라지지 않게 한다.
      await tester.pump();
      await precacheAllImages(tester);
      await tester.pump(AppMotion.float * 2);

      await expectLater(
        find.byType(RewardScreen),
        matchesGoldenFile('goldens/child_reward_${character.name}.png'),
      );
    });
  }
}
