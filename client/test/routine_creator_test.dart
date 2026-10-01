import 'package:dio/dio.dart';
import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/data/member_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/presentation/guardian_home_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_swipe_actions.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_dio.dart';
import 'helpers/svg_finder.dart';

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

    test('필드가 없으면 알 수 없다 — 숨기지 않는다 (옛 서버·아직 안 내려주는 서버)', () {
      final r = Routine.fromJson(routineJson('r1', '일과'));

      expect(r.createdByMe, isNull);
      expect(r.isEditableByMe, isTrue);
      expect(r.foreignCreatorLabel, isNull);
    });

    test('내가 만들었으면 라벨이 없다', () {
      final r = Routine.fromJson(routineJson('r1', '일과', createdByMe: true, creatorName: '아빠'));

      expect(r.isEditableByMe, isTrue);
      expect(r.foreignCreatorLabel, isNull);
    });

    test('만든 사람 이름이 없으면 다른 보호자라고 한다', () {
      final r = Routine.fromJson(routineJson('r1', '일과', createdByMe: false));

      expect(r.foreignCreatorLabel, '다른 보호자가 만든 일과예요');
    });

    test('이름 끝 글자 받침에 맞춰 조사를 고른다', () {
      final r = Routine.fromJson(routineJson('r1', '일과', createdByMe: false, creatorName: '센터 선생님'));

      expect(r.foreignCreatorLabel, '센터 선생님이 만든 일과예요');
    });

    test('모양이 달라도 죽지 않는다', () {
      final r = Routine.fromJson({'id': 'r1', 'createdByMe': 'yes', 'creatorName': 7});

      expect(r.createdByMe, isNull);
      expect(r.creatorName, '7');
    });

    test('오프라인 캐시에도 남는다 — 목록을 못 받아도 남의 일과 버튼이 도로 생기지 않는다', () {
      final r = Routine.fromJson(routineJson('r1', '일과', createdByMe: false, creatorName: '엄마'));

      final again = Routine.fromJson(r.toJson());

      expect(again.createdByMe, isFalse);
      expect(again.creatorName, '엄마');
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

    testWidgets('만든 사람을 모르는 일과는 지금처럼 밀 수 있다', (tester) async {
      await pump(tester, today: [routineJson('r-mine', '일과')]);

      expect(swipeEnabled(tester, '일과'), isTrue);
    });

    testWidgets('남의 일과를 누르면 보기 시트만 열린다 — 편집하기가 없고 만든 사람 이름을 보인다 (E46)', (tester) async {
      await pump(tester, today: [
        routineJson('r-theirs', '엄마의 일과', createdByMe: false, creatorName: '엄마'),
      ]);

      await tester.tap(find.text('엄마의 일과'));
      await tester.pumpAndSettle();

      expect(find.text('엄마가 만든 일과예요'), findsOneWidget);
      expect(find.text('편집하기'), findsNothing);
      // 순서 손잡이도 없다 — 카드 순서는 고치는 일이다
      expect(svgWithAsset(AppAssets.sheetReorderHandle), findsNothing);
      // 카드 내용은 볼 수 있다
      expect(find.text('손을 씻어요'), findsWidgets);
    });

    testWidgets('내 일과의 시트에는 편집하기가 있고 만든 사람 줄은 없다', (tester) async {
      await pump(tester, today: [
        routineJson('r-mine', '내 일과', createdByMe: true, creatorName: '아빠'),
      ]);

      await tester.tap(find.text('내 일과'));
      await tester.pumpAndSettle();

      expect(find.text('편집하기'), findsOneWidget);
      expect(find.textContaining('만든 일과예요'), findsNothing);
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
    test('남이 만든 임시저장은 빠진다 — 이어서 만들 수 없다 (서버는 이룸이의 임시저장을 모두 준다)', () async {
      final container = ProviderContainer(
        overrides: [
          myRoutinesProvider.overrideWith(
            (ref) async => [
              Routine.fromJson(routineJson('a', '내 것', createdByMe: true, status: 'PENDING_REVIEW')),
              Routine.fromJson(routineJson('b', '남의 것', createdByMe: false, creatorName: '엄마', status: 'PENDING_REVIEW')),
              Routine.fromJson(routineJson('c', '모르는 것', status: 'PENDING_REVIEW')),
              Routine.fromJson(routineJson('d', '승인한 것', createdByMe: true)),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final drafts = await container.read(draftRoutinesProvider.future);

      expect(drafts.map((r) => r.title), ['내 것', '모르는 것']);
    });
  });
}
