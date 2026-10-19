import 'package:dio/dio.dart';
import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/member/data/member_repository.dart';
import 'package:elum/features/guardian/presentation/guardian_home_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_swipe_actions.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_dio.dart';
import 'helpers/svg_finder.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/features/guardian/data/routine_repository_impl.dart';
import 'package:elum/core/router/routes.dart';

/// 일과를 **누가 만들었는가** — 남이 만든 일과는 보기만 한다 (#362 · E30·E46).
///
/// 서버는 승인·수정·삭제를 만든 사람에게만 허락한다(403 `ROUTINE_NOT_CREATOR`). 앱은 그 버튼을
/// 숨긴다 — 누른 뒤에야 막히는 것보다 낫다. **서버가 최종 판단**이므로 숨기지 못한 자리(만든
/// 사람을 모르는 일과)에서 403 이 와도 이유와 코드를 보이고 머문다.
///
/// 서버 `RoutineResponse` 에 만든 사람 필드가 아직 없다 — 앱은 `createdByMe`·`creatorName` 을
/// 받을 준비를 하고, 없으면 지금처럼 모든 버튼을 보인다(알 수 없음 = 숨기지 않음).
void main() {
  useFigmaViewport();

  Map<String, Object?> routineJson(
    String id,
    String title, {
    bool? createdByMe,
    String? creatorName,
    String status = 'CONFIRMED',
  }) => {
    'id': id,
    'title': title,
    'status': status,
    'steps': [
      {'id': '$id-1', 'stepOrder': 1, 'description': '손을 씻어요'},
    ],
    'completedStepCount': 0,
    'totalStepCount': 1,
    'progressPercent': 0,
    'createdByMe': ?createdByMe,
    'creatorName': ?creatorName,
  };

  group('일과 응답', () {
    test('만든 사람 필드를 읽는다', () {
      final r = Routine.fromJson(routineJson('r1', '내 일과', createdByMe: false, creatorName: '엄마'));

      expect(r.createdByMe, isFalse);
      expect(r.creatorName, '엄마');
      expect(r.isEditableByMe, isFalse);
      expect(r.foreignCreatorLabel, '엄마가 만든 일과예요');
    });

    test('온보딩 예시 일과는 만든 사람 표시가 없다 — 이름을 모르는 남의 일과는 그대로 (#823)', () {
      final example = Routine.fromJson(
        {...routineJson('r1', '아침 준비', createdByMe: false), 'isExample': true},
      );
      final unknownForeign = Routine.fromJson(routineJson('r2', '남의 일과', createdByMe: false));

      expect(example.foreignCreatorLabel, isNull);
      expect(unknownForeign.foreignCreatorLabel, '다른 보호자가 만든 일과예요');
    });

  });

  group('보호자 홈', () {
    late FakeAdapter adapter;

    Future<void> pump(
      WidgetTester tester, {
      required List<Map<String, Object?>> today,
      Object? deleteResult,
    }) async {
      adapter = FakeAdapter({
        'GET /api/routines/today': today,
        'GET /api/routines/past': <Object>[],
        'GET /api/routines': today,
        'DELETE /api/routines/r-mine': ?deleteResult,
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
        ..httpClientAdapter = adapter;
      final storage = InMemoryStorage(onboardingCompleted: true);
      final router = GoRouter(
        initialLocation: Routes.guardian,
        routes: [
          GoRoute(path: Routes.guardian, builder: (_, _) => const GuardianHomeScreen()),
          GoRoute(path: Routes.routineReview, builder: (_, _) => const Scaffold(body: Text('카드 검토'))),
          GoRoute(path: Routes.onboardingName, builder: (_, _) => const Scaffold(body: Text('이룸이 등록'))),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageProvider.overrideWithValue(storage),
            routineRepositoryProvider.overrideWithValue(
              RoutineRepositoryImpl(dio: dio, storage: storage),
            ),
            memberProvider.overrideWith((ref) async => const Member(nickname: '하늘이')),
          ],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, _) => MaterialApp.router(theme: AppTheme.light, routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    bool swipeEnabled(WidgetTester tester, String title) => tester
        .widget<RoutineSwipeActions>(
          find.ancestor(of: find.text(title), matching: find.byType(RoutineSwipeActions)),
        )
        .enabled;

    testWidgets('남이 만든 일과는 밀어도 삭제·수정이 나오지 않는다 — 내 일과는 그대로다 (E46)', (tester) async {
      await pump(tester, today: [
        routineJson('r-mine', '내 일과', createdByMe: true),
        routineJson('r-theirs', '엄마의 일과', createdByMe: false, creatorName: '엄마'),
      ]);

      expect(swipeEnabled(tester, '내 일과'), isTrue);
      expect(swipeEnabled(tester, '엄마의 일과'), isFalse);
    });

    testWidgets('숨기지 못한 자리에서 서버가 403 을 주면 이유와 코드를 보이고 머문다 (E30)', (tester) async {
      await pump(
        tester,
        today: [routineJson('r-mine', '일과')],
        deleteResult: const FakeHttpError(
          403,
          errorCode: 'ROUTINE_NOT_CREATOR',
          errorMessage: '일과를 만든 사람만 바꿀 수 있어요.',
        ),
      );

      await tester.drag(find.text('일과'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      await tester.tap(svgWithAsset(AppAssets.iconTrash));
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();

      expect(find.textContaining('일과를 만든 사람만 바꿀 수 있어요.'), findsOneWidget);
      expect(find.text('ROUTINE_NOT_CREATOR'), findsOneWidget);
      // 화면에 머물고 목록도 그대로다
      expect(find.text('일과'), findsOneWidget);
    });
  });

  group('임시저장', () {
  });
}
