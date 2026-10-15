
import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/widgets/app_pressable.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/routine_input_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/svg_finder.dart';
import 'helpers/test_storage.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/core/router/routes.dart';

/// Figma `보호자_새로운 일과 만들기`(238:1643) 정합 테스트.
///
/// 기존 화면과 완전히 다른 디자인이라 통째로 다시 만들었다.
/// 하단 CTA가 사라지고 입력창 안 화살표가 그 자리를 대신한다.
void main() {
  /// 전송 버튼(입력창 안 화살표)을 찾는다
  /// 배경이 무한 반복하므로 `pumpAndSettle`은 절대 끝나지 않는다.
  /// 프레임을 정해진 만큼만 진행시킨다.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  group('일과 만들기 화면 구성', () {
    testWidgets('뒤로가기로 나가면 입력칸이 포커스를 놓는다 (#301)', (tester) async {
      // 뒤로 갈 곳이 있어야 pop 이 성립한다 — 이 화면만 띄우면 스택이 비어 있다.
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => context.push(Routes.routineInput),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: Routes.routineInput,
            builder: (context, state) => const RoutineInputScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            testStorageOverride(onboardingCompleted: true),
            routineSuggestionsProvider.overrideWith(
              (ref) async => RoutineSuggestion.fallback,
            ),
          ],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, _) =>
                MaterialApp.router(theme: AppTheme.light, routerConfig: router),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('열기'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
        isTrue,
        reason: '먼저 키보드가 올라온 상태를 만든다',
      );

      await tester.tap(
        find
            .ancestor(
              of: svgWithAsset(AppAssets.iconBack),
              matching: find.byType(AppPressable),
            )
            .first,
      );
      // 배경 오로라가 계속 돌아 pumpAndSettle 이 끝나지 않는다. 시간을 직접 민다.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // iOS 는 입력칸이 포커스를 쥔 채 라우트가 닫히면 키보드를 내리지 않는다.
      // 홈으로 돌아왔는데 키보드가 화면 아래를 덮고 있던 것이 이 때문이다.
      expect(find.byType(RoutineInputScreen), findsNothing, reason: '화면은 닫혔다');
      expect(find.byType(EditableText), findsNothing, reason: '입력칸도 함께 사라진다');
    });
  });

  group('추천 문구 칩', () {
    // #393 S3 — 글꼴 2.0 에서 두 칩이 한 줄을 다 차지해 화면 끝에 붙었다. 칩 묶음에
    // 본문과 같은 좌우 여백(24)을 둔다. 글꼴 1.0 에서는 칩이 좁아 자리가 그대로다.
  });

  group('전송 버튼', () {
    testWidgets('입력값이 notifier에 반영된다', (tester) async {
      late WidgetRef ref;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [testStorageOverride(onboardingCompleted: true)],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, _) => MaterialApp(
              theme: AppTheme.light,
              home: Consumer(
                builder: (context, r, _) {
                  ref = r;
                  return const RoutineInputScreen();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), '내일 병원 가기');
      await settle(tester);

      expect(ref.read(routineFlowProvider).rawInput, '내일 병원 가기');
    });
  });

  group('배경 애니메이션', () {
  });

  group('누를 수 있는 것에 읽을 이름이 있다 (#339)', () {
  });
}
