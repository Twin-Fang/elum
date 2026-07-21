import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/routine_input_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/aurora_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/svg_finder.dart';
import 'helpers/test_storage.dart';

/// Figma `보호자_새로운 일과 만들기`(238:1643) 정합 테스트.
///
/// 기존 화면과 완전히 다른 디자인이라 통째로 다시 만들었다.
/// 하단 CTA가 사라지고 입력창 안 화살표가 그 자리를 대신한다.
void main() {
  Widget wrap({bool reduceMotion = false}) {
    final router = GoRouter(
      initialLocation: Routes.routineInput,
      routes: [
        GoRoute(
          path: Routes.routineInput,
          builder: (context, state) => const RoutineInputScreen(),
        ),
        GoRoute(
          path: Routes.routineQuestion,
          builder: (context, state) => const Scaffold(body: Text('추가질문 화면')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [testStorageOverride(onboardingCompleted: true)],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reduceMotion),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  /// 전송 버튼(입력창 안 화살표)을 찾는다
  Finder sendButton() => find.byKey(RoutineInputScreen.sendButtonKey);

  /// 배경이 무한 반복하므로 `pumpAndSettle`은 절대 끝나지 않는다.
  /// 프레임을 정해진 만큼만 진행시킨다.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  group('일과 만들기 화면 구성', () {
    testWidgets('Figma 문구가 보인다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.text('오늘은 어떤 준비가\n필요한가요?'), findsOneWidget);
      expect(find.text('AI 루미가 작은 행동 단계로 나눠드려요'), findsOneWidget);
      expect(find.text('아이의 정보를 안전하게 보호해요'), findsOneWidget);
    });

    testWidgets('하단 고정 CTA가 없다', (tester) async {
      // Figma에서 전송이 입력창 안 화살표로 옮겨갔다.
      // 다시 하단 버튼을 넣으면 이 테스트가 막는다.
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.byType(ElumButton), findsNothing);
    });

    testWidgets('sparkles를 코드로 그리지 않고 SVG로 렌더링한다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(svgWithAsset(AppAssets.iconSparklesLarge), findsOneWidget);
    });

    testWidgets('뒤로가기가 있다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(svgWithAsset(AppAssets.iconBack), findsOneWidget);
    });
  });

  group('추천 문구 칩', () {
    testWidgets('Figma 5개가 순서대로 보인다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      for (final s in RoutineSuggestion.values) {
        expect(find.text(s.label), findsOneWidget);
      }
      expect(RoutineSuggestion.values.length, 5);
    });

    testWidgets('칩을 누르면 입력창에 문구가 채워진다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.tap(find.text(RoutineSuggestion.rainyCommute.label));
      await settle(tester);

      expect(find.text('비 오는 날 등교'), findsWidgets);
    });

    testWidgets('입력창에는 이모지를 넣지 않는다', (tester) async {
      // 이모지는 칩 장식이다. 서버로 보내는 문구에 섞이면 안 된다.
      expect(RoutineSuggestion.rainyCommute.inputText, '비 오는 날 등교');
      expect(RoutineSuggestion.afterSchool.inputText, '여름방학 방과후 수업 준비');
    });
  });

  group('전송 버튼', () {
    testWidgets('입력 전에는 보이지 않는다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(sendButton(), findsNothing);
    });

    testWidgets('입력하면 나타난다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.enterText(find.byType(TextField), '내일 병원 가기');
      await settle(tester);

      expect(sendButton(), findsOneWidget);
    });

    testWidgets('공백만 입력하면 나타나지 않는다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.enterText(find.byType(TextField), '   ');
      await settle(tester);

      expect(sendButton(), findsNothing);
    });

    testWidgets('누르면 다음 단계로 간다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.enterText(find.byType(TextField), '내일 병원 가기');
      await settle(tester);
      await tester.tap(sendButton());
      await settle(tester);

      expect(find.text('추가질문 화면'), findsOneWidget);
    });

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
    testWidgets('배경을 그린다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.byType(AuroraBackground), findsOneWidget);
    });

    testWidgets('배경만 다시 그리도록 격리한다', (tester) async {
      // 이게 없으면 원이 움직일 때마다 텍스트까지 재페인트된다
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(AuroraBackground),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
    });

    testWidgets('애니메이션 끄기를 켜면 컨트롤러가 돌지 않는다', (tester) async {
      // 움직임에 민감한 사용자가 있다 (docs/motion.md)
      await tester.pumpWidget(wrap(reduceMotion: true));
      await tester.pump();

      // 애니메이션이 돌면 pumpAndSettle이 타임아웃난다
      await tester.pumpAndSettle();

      expect(find.byType(AuroraBackground), findsOneWidget);
    });
  });
}
