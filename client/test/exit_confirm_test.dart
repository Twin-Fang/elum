import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_dialog.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_flow_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';

/// 일과를 만들다 나갈 때 확인 (이슈 #242 · #387).
///
/// **카드 생성은 AI 호출이라 30초 넘게 걸린다.** 잘못 눌러 날리면 그 시간을
/// 다시 쓴다. 그런데 잃을 것이 없을 때 묻는 팝업이 가장 성가시므로, 묻는
/// 조건도 함께 고정한다.
///
/// **무엇을 잃는지가 시점마다 다르다 (#387).** 카드를 만들기 전에는 적은 것이
/// 정말 남지 않는다. 카드를 만든 뒤에는 서버에 임시저장으로 남는다 — 거기에
/// `사라져요`라고 쓰면 사실이 아니다.
void main() {
  useFigmaViewport();

  Widget wrap({RoutineLeave? leave, bool askOnBack = true}) {
    final router = GoRouter(
      initialLocation: '/flow',
      routes: [
        GoRoute(
          path: '/before',
          builder: (context, state) => const Scaffold(body: Text('앞 화면')),
          routes: [
            GoRoute(
              path: 'flow',
              builder: (context, state) => RoutineFlowScaffold(
                leave: leave,
                askOnBack: askOnBack,
                onBack: () => context.pop(),
                child: const SizedBox.shrink(),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/flow',
          builder: (context, state) => RoutineFlowScaffold(
            leave: leave,
            askOnBack: askOnBack,
            onBack: () => context.pop(),
            child: const SizedBox.shrink(),
          ),
        ),
        GoRoute(
          path: Routes.guardian,
          builder: (context, state) => const Scaffold(body: Text('보호자 홈')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [testStorageOverride()],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  /// 배경(aurora)이 무한 반복해 `pumpAndSettle`을 쓸 수 없다.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('홈을 누르면 확인을 먼저 묻는다', (tester) async {
    await tester.pumpWidget(wrap(leave: RoutineLeave.discard));
    await settle(tester);

    await tester.tap(find.byType(GestureDetector).last);
    await settle(tester);

    expect(find.text('일과 만들기를 그만둘까요?'), findsOneWidget);
    expect(find.text('지금 나가면 적은 내용은 남지 않아요'), findsOneWidget);
    expect(find.text('계속 만들기'), findsOneWidget);
    expect(find.text('나가기'), findsOneWidget);
    // 아직 나가지 않았다
    expect(find.text('보호자 홈'), findsNothing);
  });

  testWidgets('계속 만들기를 누르면 화면에 남는다', (tester) async {
    await tester.pumpWidget(wrap(leave: RoutineLeave.discard));
    await settle(tester);

    await tester.tap(find.byType(GestureDetector).last);
    await settle(tester);
    await tester.tap(find.text('계속 만들기'));
    await settle(tester);

    expect(find.text('보호자 홈'), findsNothing);
    expect(find.byType(RoutineFlowScaffold), findsOneWidget);
  });

  testWidgets('나가기를 누르면 홈으로 간다', (tester) async {
    await tester.pumpWidget(wrap(leave: RoutineLeave.discard));
    await settle(tester);

    await tester.tap(find.byType(GestureDetector).last);
    await settle(tester);
    await tester.tap(find.text('나가기'));
    await settle(tester);

    expect(find.text('보호자 홈'), findsOneWidget);
  });

  testWidgets('잃을 것이 없으면 묻지 않는다', (tester) async {
    await tester.pumpWidget(wrap());
    await settle(tester);

    await tester.tap(find.byType(GestureDetector).last);
    await settle(tester);

    // 물어볼 것이 없는데 묻는 팝업이 가장 성가시다
    expect(find.byType(ElumDialogCard<bool>), findsNothing);
    expect(find.text('보호자 홈'), findsOneWidget);
  });

  /// 나가기 팝업을 띄우고 그 카드를 돌려준다.
  Future<ElumDialogCard<bool>> openLeave(
    WidgetTester tester,
    RoutineLeave leave,
  ) async {
    await tester.pumpWidget(wrap(leave: leave));
    await settle(tester);
    await tester.tap(find.byType(GestureDetector).last);
    await settle(tester);
    return tester.widget<ElumDialogCard<bool>>(find.byType(ElumDialogCard<bool>));
  }

  ElumDialogTone leaveTone(ElumDialogCard<bool> card) =>
      card.actions.firstWhere((a) => a.value == true).tone;

  group('시점마다 맞는 말을 한다 (#387)', () {
    testWidgets('카드 만들기 전 — 그만둘까요 · 경고 톤 (T3·T5)', (tester) async {
      final card = await openLeave(tester, RoutineLeave.discard);

      expect(card.title, '일과 만들기를 그만둘까요?');
      expect(card.message, '지금 나가면 적은 내용은 남지 않아요');
      // 정말 잃는다 — 노란 경고 톤 (#242 그대로)
      expect(card.icon, ElumDialogIcon.warning);
      expect(leaveTone(card), ElumDialogTone.warn);
    });

    testWidgets('카드 만든 뒤 — 임시저장에 두고 · 경고가 아니다 (T1)', (tester) async {
      final card = await openLeave(tester, RoutineLeave.draft);

      expect(card.title, '임시저장에 두고 나갈까요?');
      expect(card.message, '설정의 임시저장에서\n이어서 만들 수 있어요');
      // 되돌릴 수 없는 동작이 아니다 — 경고 아이콘도 경고 버튼도 없다.
      expect(card.icon, isNull);
      expect(leaveTone(card), isNot(anyOf(ElumDialogTone.warn, ElumDialogTone.danger)));
      expect(find.text('계속 만들기'), findsOneWidget);
      expect(find.text('나가기'), findsOneWidget);
    });

    testWidgets('카드 만드는 중 — 다 만들어지면 임시저장에 남는다 (T4)', (tester) async {
      final card = await openLeave(tester, RoutineLeave.draftWhenReady);

      expect(card.title, '임시저장에 두고 나갈까요?');
      expect(card.message, '카드가 다 만들어지면 임시저장에 남아요\n설정에서 이어서 만들 수 있어요');
      expect(card.icon, isNull);
      expect(leaveTone(card), isNot(anyOf(ElumDialogTone.warn, ElumDialogTone.danger)));
    });

    testWidgets('이미 저장한 일과를 고치다 — 저장하지 않고 나갈까요', (tester) async {
      final card = await openLeave(tester, RoutineLeave.edit);

      expect(card.title, '저장하지 않고 나갈까요?');
      expect(card.message, '뺀 카드는 저장하기를 눌러야 빠져요');
      expect(card.icon, isNull);
    });

    for (final leave in RoutineLeave.values) {
      test('${leave.name} — 해요체 · 피동형·"사라져요" 없음', () {
        final (title, message) = RoutineLeave.copyOf(leave);
        for (final text in [title, message]) {
          expect(text, isNot(contains('사라져')));
          expect(text, isNot(contains('되었')));
          expect(text, anyOf(endsWith('요'), endsWith('요?')));
        }
      });
    }
  });

  testWidgets('로딩처럼 뒤로가 흐름 안 한 칸이면 뒤로는 묻지 않는다 — 홈만 묻는다', (tester) async {
    await tester.pumpWidget(
      wrap(leave: RoutineLeave.draftWhenReady, askOnBack: false),
    );
    await settle(tester);

    // 홈은 흐름을 떠난다 — 묻는다
    await tester.tap(find.byType(GestureDetector).last);
    await settle(tester);
    expect(find.byType(ElumDialogCard<bool>), findsOneWidget);
    await tester.tap(find.text('계속 만들기'));
    await settle(tester);

    // 시스템 뒤로는 그냥 한 칸 — 묻지 않는다
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(ElumDialogCard<bool>), findsNothing);
  });

  test('warn과 danger는 다른 색이다 (이슈 #242)', () {
    const colors = AppColors.light;

    // 아동도 보는 화면이라 붉은 경고를 함부로 쓰지 않는다.
    // `danger`는 되돌릴 수 없는 파괴(회원탈퇴)에만 쓴다.
    expect(colors.warn, isNot(colors.danger));
    expect(colors.warnText, colors.surface);
  });
}
