import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/presentation/draft_routines_screen.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/core/router/routes.dart';

/// 임시저장 = 만들다 만 일과 (`PENDING_REVIEW`).
///
/// **`승인 대기`가 아니다.** 만들다 만 것이지 심사가 아니다 (용어 규칙 · #349).
Routine _routine(String id, String title, String status) => Routine(
  id: id,
  title: title,
  status: status,
  rawInputText: '',
  sanitizedInputText: '',
);

Future<void> _pump(
  WidgetTester tester,
  List<Routine> all, {
  Object? error,
  List<Object> extra = const [],
  // extra 가 목록 provider 를 직접 덮을 때는 끈다 (같은 provider 를 두 번 덮을 수 없다)
  bool overrideRoutines = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
        ...extra.cast(),
        if (!overrideRoutines)
          ...const <Never>[]
        else if (error == null)
          myRoutinesProvider.overrideWith((ref) async => all)
        else
          myRoutinesProvider.overrideWith((ref) async => throw error),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp.router(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          routerConfig: GoRouter(
            initialLocation: Routes.guardianDrafts,
            routes: [
              GoRoute(
                path: Routes.guardianDrafts,
                builder: (context, state) => const DraftRoutinesScreen(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // 시안과 같은 393×852 로 그린다 — 밀어야 하는 거리와 버튼 자리가 시안 기준이 된다
  useFigmaViewport();

  testWidgets('만들다 만 일과만 보인다 — 확인을 마친 것은 빠진다', (tester) async {
    await _pump(tester, [
      _routine('1', '아침 준비', 'PENDING_REVIEW'),
      _routine('2', '이미 확인한 일과', 'CONFIRMED'),
      _routine('3', '다 끝낸 일과', 'COMPLETED'),
      _routine('4', '저녁 준비', 'PENDING_REVIEW'),
    ]);

    expect(find.text('아침 준비'), findsOneWidget);
    expect(find.text('저녁 준비'), findsOneWidget);
    expect(
      find.text('이미 확인한 일과'),
      findsNothing,
      reason: '확인을 마친 일과는 만들다 만 것이 아니다',
    );
    expect(find.text('다 끝낸 일과'), findsNothing);
  });

  // 0건과 로딩을 같은 화면으로 두면 느린 연결에서 "없다"고 잘못 읽는다.
  testWidgets('0건이면 빈 상태를 보여준다', (tester) async {
    await _pump(tester, [_routine('2', '확인한 일과', 'CONFIRMED')]);

    expect(find.text('만들다 만 일과가 없어요'), findsOneWidget);
    expect(find.text('일과를 만들다 그만두면 여기에 남아요'), findsOneWidget);
  });

  testWidgets('불러오지 못하면 재시도와 에러 코드를 보여준다 — 무한 로딩 금지', (tester) async {
    await _pump(tester, const [], error: StateError('서버가 응답하지 않음'));

    expect(find.text('임시저장을 불러오지 못했어요'), findsOneWidget);
    // 제보를 받았을 때 어디서 터졌는지 가릴 단서다.
    expect(find.textContaining('E-DRAFT'), findsWidgets);
  });

  // 밀어서 삭제 + 확인 팝업 (#496 · 시안 1274:9262)
  group('임시저장 밀어서 삭제', () {
    late _Repo repo;
    late List<Routine> store;

    Future<void> pumpTwo(WidgetTester tester) async {
      repo = _Repo();
      store = [
        _routine('1', '아침 준비', 'PENDING_REVIEW'),
        _routine('2', '저녁 준비', 'PENDING_REVIEW'),
      ];
      await _pump(
        tester,
        const [],
        overrideRoutines: false,
        extra: [
          routineRepositoryProvider.overrideWithValue(repo),
          // 지운 뒤 다시 받으면 줄어든 목록이 오게 한다
          myRoutinesProvider.overrideWith((ref) async => List.of(store)),
        ],
      );
    }

    // 둘째 줄을 왼쪽으로 밀고 휴지통을 누른다
    Future<void> swipeAndTapTrash(WidgetTester tester, String title) async {
      await tester.drag(find.text(title), const Offset(-80, 0));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .byWidgetPredicate(
              (w) => w is Semantics && w.properties.label == '임시저장 삭제',
            )
            // 줄마다 삭제 버튼이 깔려 있다 — 밀어 둔 둘째 줄의 것이 마지막이다
            .last,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('휴지통을 눌러도 바로 지우지 않고 먼저 묻는다', (tester) async {
      await pumpTwo(tester);

      await swipeAndTapTrash(tester, '저녁 준비');

      expect(find.text('임시저장을 삭제하실건가요?'), findsOneWidget);
      expect(repo.deleted, isEmpty, reason: '팝업에서 삭제를 누르기 전에는 지우지 않는다');
    });

    testWidgets('취소하면 아무것도 지우지 않는다', (tester) async {
      await pumpTwo(tester);

      await swipeAndTapTrash(tester, '저녁 준비');
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(repo.deleted, isEmpty);
      expect(find.text('저녁 준비'), findsOneWidget);
    });

    testWidgets('삭제를 누르면 그 일과만 지우고 목록에서 빠진다', (tester) async {
      await pumpTwo(tester);

      await swipeAndTapTrash(tester, '저녁 준비');
      // 서버에서 지워지면 다시 받는 목록에서도 빠진다
      store.removeWhere((r) => r.id == '2');
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();

      expect(repo.deleted, ['2']);
      expect(find.text('저녁 준비'), findsNothing);
      expect(find.text('아침 준비'), findsOneWidget, reason: '다른 줄은 그대로다');
    });

    testWidgets('지우지 못하면 줄을 그대로 두고 에러 코드를 보여준다', (tester) async {
      await pumpTwo(tester);
      repo.failure = const AppFailure(fault: NetworkFault.app);

      await swipeAndTapTrash(tester, '저녁 준비');
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();

      // 제목과 할 일이 한 문장으로 이어져 나온다
      expect(find.textContaining('임시저장을 삭제하지 못했어요'), findsOneWidget);
      expect(find.textContaining('E-DRAFT-DEL'), findsWidgets);
      expect(find.text('저녁 준비'), findsOneWidget, reason: '실패하면 줄이 남아야 한다');
    });

    testWidgets('열려 있는 줄을 누르면 이어서 만들지 않고 닫는다', (tester) async {
      await pumpTwo(tester);

      await tester.drag(find.text('저녁 준비'), const Offset(-80, 0));
      await tester.pumpAndSettle();
      // 밀려 열린 줄의 `이어서` 알약(둘째 줄 것)을 누른다
      await tester.tap(find.text('이어서').last);
      await tester.pumpAndSettle();

      // 이어서 만들기로 넘어갔다면 이 화면의 줄이 사라진다(테스트 라우터엔 그 길이 없다)
      expect(find.text('저녁 준비'), findsOneWidget);
      expect(find.text('아침 준비'), findsOneWidget);
    });
  });

  testWidgets('보상이 없으면 완료 시 미설정이라 적는다', (tester) async {
    await _pump(tester, [_routine('1', '아침 준비', 'PENDING_REVIEW')]);

    expect(find.text('완료 시'), findsOneWidget);
    expect(find.text('미설정'), findsOneWidget);
    expect(find.text('이어서'), findsOneWidget);
  });
}

class _Repo implements RoutineRepository {
  final deleted = <String>[];
  AppFailure? failure;

  @override
  Future<AppFailure?> delete(String routineId) async {
    deleted.add(routineId);
    return failure;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
