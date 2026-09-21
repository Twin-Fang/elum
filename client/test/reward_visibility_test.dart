import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/child/domain/reward_character.dart';
import 'package:elum/features/child/presentation/reward_screen.dart';
import 'package:elum/features/child/presentation/widgets/reward_banner.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';

/// 보상이 이룸이에게 보이는 자리 (이슈 #239).
///
/// 🔴 **수행 중 노출이 2026-09-13 자문의 핵심 요구다.** 완료 후에만 보여주는
/// 별(⭐) 연출과 다른 기능 — 하는 동안 "다 하면 무엇을 받는지"가 보여야 한다.
///
/// 보호자가 **건너뛸 수 있으므로**, 보상이 없을 때 빈 자리가 남지 않는 것도
/// 함께 고정한다.
void main() {
  useFigmaViewport();

  Widget wrap(Widget child) => ProviderScope(
        overrides: [testStorageOverride(nickname: '하늘이')],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(body: child),
          ),
        ),
      );

  group('보상 배너', () {
    testWidgets('보상이 있으면 다 하면과 함께 보여준다', (tester) async {
      const routine = Routine(
        id: 'r1',
        rewardText: '젤리 먹기',
        rewardPresetKey: 'SNACK',
      );

      await tester.pumpWidget(wrap(RewardBanner.maybe(routine)));
      await tester.pump();

      // 조건을 먼저 말해야 보상만 보고 넘어가지 않는다
      expect(find.text('다 하면'), findsOneWidget);
      expect(find.text('젤리 먹기'), findsOneWidget);
      expect(find.text('🍪'), findsOneWidget);
    });

    testWidgets('보상이 없으면 자리도 없다', (tester) async {
      const routine = Routine(id: 'r1');

      await tester.pumpWidget(wrap(RewardBanner.maybe(routine)));
      await tester.pump();

      // 빈 배너가 남으면 무엇이 빠진 것처럼 보인다
      expect(find.text('다 하면'), findsNothing);
      expect(find.byType(RewardBanner), findsNothing);
    });

    testWidgets('모르는 프리셋 키가 와도 글자는 나온다 — 그림은 지어내지 않는다 (#275)', (
      tester,
    ) async {
      const routine = Routine(
        id: 'r1',
        rewardText: '새로 생긴 보상',
        rewardPresetKey: 'SOMETHING_NEW',
      );

      await tester.pumpWidget(wrap(RewardBanner.maybe(routine)));
      await tester.pump();

      // 서버에 프리셋이 늘었는데 앱이 아직 모를 때 화면이 죽으면 안 된다
      expect(find.text('새로 생긴 보상'), findsOneWidget);
      // 모르는 것을 별로 메우지 않는다 — 별은 일과를 끝냈을 때의 연출이라 뜻이 겹친다
      expect(find.text('⭐'), findsNothing);
    });

    testWidgets('수행 중에는 작게 — 카드를 가리지 않는다', (tester) async {
      const routine = Routine(id: 'r1', rewardText: '산책', rewardPresetKey: 'WALK');

      await tester.pumpWidget(wrap(RewardBanner.maybe(routine, compact: true)));
      await tester.pump();

      final compact = tester.getSize(find.byType(RewardBanner)).height;

      await tester.pumpWidget(wrap(RewardBanner.maybe(routine)));
      await tester.pump();
      final large = tester.getSize(find.byType(RewardBanner)).height;

      expect(compact, lessThan(large));
    });
  });

  group('완료 화면', () {
    testWidgets('보상을 받으면 별과 함께 보여준다', (tester) async {
      await tester.pumpWidget(
        wrap(
          const RewardScreen(
            character: RewardCharacter.lumi,
            reward: (emoji: '🍪', text: '젤리 먹기'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      // 별은 "해냈다", 보상은 "이제 받는다" — 서로를 대신하지 못한다
      expect(find.text('젤리 먹기'), findsOneWidget);
    });

    testWidgets('보상 없이 끝내면 별 연출만 돈다', (tester) async {
      await tester.pumpWidget(
        wrap(const RewardScreen(character: RewardCharacter.lumi)),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(RewardBanner), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
