import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/presentation/draft_routines_screen.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/test_storage.dart';

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

Future<void> _pump(WidgetTester tester, List<Routine> all, {Object? error}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
        if (error == null)
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
}
