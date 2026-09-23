import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/widgets/app_pressable.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/routine_input_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/aurora_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/svg_finder.dart';
import 'helpers/semantics_audit.dart';
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
        // 입력 다음은 로딩 화면(262:4569)이다. DLP·질문 생성을 여기서
        // 기다린 뒤에야 추가질문 화면으로 넘어간다.
        GoRoute(
          path: Routes.routineMasking,
          builder: (context, state) => const Scaffold(body: Text('로딩 화면')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        testStorageOverride(onboardingCompleted: true),
        // 실서버를 타지 않는다. 추천은 서버가 개수를 정하므로 고정 목록을 넣는다.
        routineSuggestionsProvider
            .overrideWith((ref) async => RoutineSuggestion.fallback),
      ],
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

      // 시안(238:1643)이 담은 글자는 셋뿐이다 — 제목·부제·플레이스홀더.
      expect(find.text('오늘은 어떤 준비가\n필요한가요?'), findsOneWidget);
      expect(find.text('AI 루미가 작은 행동 단계로 나눠드려요'), findsOneWidget);
      // 시안(238:1723) 문구. 한 글자라도 다르면 여기서 막힌다.
      expect(find.text('평소 이야기하듯 입력해주세요'), findsOneWidget);

      // 시안에서 빠진 문구다 (#305). 예전 시안에는 있었고 테스트가 그 상태를
      // 붙잡고 있었다 — 시안이 바뀌면 여기도 함께 바뀌어야 한다.
      expect(find.text('이룸이 정보를 안전하게 지켜요'), findsNothing);
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
    testWidgets('서버가 준 목록이 모두 보인다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      for (final s in RoutineSuggestion.fallback) {
        expect(find.text(s.label), findsOneWidget);
      }
    });

    testWidgets('칩을 누르면 입력창에 자연어 문장이 채워진다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      final first = RoutineSuggestion.fallback.first;
      await tester.tap(find.text(first.label));
      await settle(tester);

      // 칩 라벨이 아니라 prompt가 들어가야 한다 (이슈 #39)
      expect(find.text(first.prompt), findsWidgets);
    });

    test('입력창에는 이모지를 넣지 않는다', () {
      // 이모지는 칩 장식이다. 서버로 보내는 문구에 섞이면 안 된다.
      for (final s in RoutineSuggestion.fallback) {
        expect(s.inputText, isNot(contains(s.icon)));
      }
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

    testWidgets('누르면 로딩 화면으로 간다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.enterText(find.byType(TextField), '내일 병원 가기');
      await settle(tester);
      await tester.tap(sendButton());
      await settle(tester);

      expect(find.text('로딩 화면'), findsOneWidget);
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

  group('누를 수 있는 것에 읽을 이름이 있다 (#339)', () {
    testWidgets('뒤로가기와 보내기 화살표가 읽힌다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      expectLabeledButton(tester, '뒤로 가기');

      // 보내기는 입력이 있을 때만 나타난다
      await tester.enterText(find.byType(TextField), '내일 병원 가기');
      await settle(tester);

      expectLabeledButton(tester, '보내기');
      expect(unnamedTapTargets(tester), isEmpty);
    });
  });
}
