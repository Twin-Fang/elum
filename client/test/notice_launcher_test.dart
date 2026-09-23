import 'dart:async';

import 'package:dio/dio.dart';
import 'package:elum/core/network/dio_client.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/notice/data/notice_repository.dart';
import 'package:elum/features/notice/domain/app_notice.dart';
import 'package:elum/features/notice/presentation/guardian_notice_launcher.dart';
import 'package:elum/features/notice/presentation/notice_popup.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_dio.dart';

/// 보호자 홈에서만, 앱 실행 중 처음 한 번 (이슈 #371 · 명세 2장 · 3-2).
void main() {
  useFigmaViewport();

  Map<String, Object?> noticeJson(String id, {int revision = 1}) => {
    'id': id,
    'revision': revision,
    'title': '공지 $id',
    'body': '본문이에요',
    'imageUrl': null,
    'button': null,
  };

  /// 보호자 홈이 부르는 목록은 비워 둔다. 공지만 이 테스트의 관심사다.
  Map<String, Object?> homeRoutes({Object? notices}) => {
    'GET /api/routines': <Object?>[],
    'GET /api/routines/today': <Object?>[],
    'GET /api/routines/past': <Object?>[],
    'GET /api/app/notices': ?notices,
  };

  /// **앱과 같은 라우터**로 보호자 홈을 띄운다. 홈을 감싸는 자리가 빠지면 여기서 잡힌다.
  Future<Dio> pumpApp(
    WidgetTester tester, {
    required InMemoryStorage storage,
    Object? notices,
  }) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = FakeAdapter(homeRoutes(notices: notices));
    final router = createRouter()..go(Routes.guardian);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          dioProvider.overrideWithValue(dio),
          memberProvider.overrideWith((ref) async => null),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) =>
              MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return dio;
  }

  List<String> callsOf(Dio dio) => (dio.httpClientAdapter as FakeAdapter).calls;

  group('앱 라우터의 보호자 홈', () {
    testWidgets('N1 공지 API 가 아직 없어도(404) 홈이 평소처럼 뜨고 팝업·에러가 없다', (tester) async {
      final storage = InMemoryStorage(onboardingCompleted: true);
      final dio = await pumpApp(tester, storage: storage);

      expect(callsOf(dio), contains('GET /api/app/notices'));
      expect(find.text('오늘은 어떤 일과를 준비할까요?'), findsOneWidget);
      expect(find.byKey(NoticePopupCard.cardKey), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('보호자 홈이 처음 그려지면 공지를 띄운다', (tester) async {
      await pumpApp(
        tester,
        storage: InMemoryStorage(onboardingCompleted: true),
        notices: {
          'hideDays': 7,
          'notices': [noticeJson('a'), noticeJson('b')],
        },
      );

      expect(find.byKey(NoticePopupCard.cardKey), findsOneWidget);
      expect(find.text('공지 a'), findsWidgets);
      // 팝업 뒤에 홈이 이미 그려져 있다 — 공지가 홈을 막지 않는다
      expect(
        find.text('오늘은 어떤 일과를 준비할까요?', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('N10 이룸이 휴대폰이면 보호자 홈이 그려져도 띄우지 않고 묻지도 않는다', (tester) async {
      final storage = InMemoryStorage(onboardingCompleted: true);
      await storage.setElumiDevice(true);
      final dio = await pumpApp(
        tester,
        storage: storage,
        notices: {
          'hideDays': 7,
          'notices': [noticeJson('a')],
        },
      );

      expect(callsOf(dio), isNot(contains('GET /api/app/notices')));
      expect(find.byKey(NoticePopupCard.cardKey), findsNothing);
    });
  });

  group('N11 한 실행에 한 번', () {
    late _FakeRepo repo;

    /// 홈 · 일과 만들기 두 화면만 있는 앱. 공지 띄우개는 앱처럼 홈만 감싼다.
    Future<GoRouter> pumpFlow(WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: Routes.guardian,
        routes: [
          GoRoute(
            path: Routes.guardian,
            builder: (context, state) => const GuardianNoticeLauncher(
              child: Scaffold(body: Center(child: Text('보호자 홈'))),
            ),
          ),
          GoRoute(
            path: Routes.routineInput,
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('일과 입력'))),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            testStorage(InMemoryStorage(onboardingCompleted: true)),
            noticeRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      return router;
    }

    setUp(() => repo = _FakeRepo());

    testWidgets('일과 만들기로 갔다가 홈으로 돌아와도 다시 뜨지 않는다', (tester) async {
      repo.reply = NoticeFeed(hideDays: 7, notices: [_notice('a')]);
      final router = await pumpFlow(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(NoticePopupCard.cardKey), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('공지 닫기'));
      await tester.pumpAndSettle();

      // push 뒤 pop — 홈이 그대로 남아 있던 경우
      router.push(Routes.routineInput);
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(NoticePopupCard.cardKey), findsNothing);

      // go — 홈을 새로 그리는 경우
      router.go(Routes.routineInput);
      await tester.pumpAndSettle();
      router.go(Routes.guardian);
      await tester.pumpAndSettle();
      expect(find.text('보호자 홈'), findsOneWidget);
      expect(find.byKey(NoticePopupCard.cardKey), findsNothing);
      expect(repo.calls, 1);
    });

    testWidgets('공지를 기다리는 사이 일과 만들기로 넘어가면 그 위에 띄우지 않는다', (tester) async {
      final pending = Completer<NoticeFeed>();
      repo.pending = pending;
      final router = await pumpFlow(tester);
      await tester.pump(); // 첫 프레임 뒤에 묻는다
      // 기다리는 동안에도 홈은 이미 그려져 있다
      expect(find.text('보호자 홈'), findsOneWidget);

      router.push(Routes.routineInput);
      await tester.pumpAndSettle();
      pending.complete(NoticeFeed(hideDays: 7, notices: [_notice('a')]));
      await tester.pumpAndSettle();

      expect(find.text('일과 입력'), findsOneWidget);
      expect(find.byKey(NoticePopupCard.cardKey), findsNothing);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(NoticePopupCard.cardKey), findsNothing);
      expect(repo.calls, 1);
    });
  });

  group('숨김은 다음 실행까지 이어진다', () {
    /// 같은 휴대폰(저장소)에서 앱을 새로 켠다.
    Future<void> launch(
      WidgetTester tester,
      InMemoryStorage storage,
      NoticeFeed reply,
    ) async {
      final repo = _FakeRepo()..reply = reply;
      await tester.pumpWidget(const SizedBox()); // 이전 실행을 내린다
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            testStorage(storage),
            noticeRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const GuardianNoticeLauncher(
              child: Scaffold(body: Center(child: Text('보호자 홈'))),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('체크 없이 닫으면 다음 실행에 다시 뜬다', (tester) async {
      final storage = InMemoryStorage(onboardingCompleted: true);
      final feed = NoticeFeed(hideDays: 7, notices: [_notice('a')]);

      await launch(tester, storage, feed);
      await tester.tap(find.bySemanticsLabel('공지 닫기'));
      await tester.pumpAndSettle();

      await launch(tester, storage, feed);
      expect(find.byKey(NoticePopupCard.cardKey), findsOneWidget);
    });

    testWidgets('N27 체크하고 닫으면 넘겨 보지 않은 장까지 다음 실행에 안 뜬다 — N7 판이 오르면 다시 뜬다', (
      tester,
    ) async {
      final storage = InMemoryStorage(onboardingCompleted: true);

      await launch(
        tester,
        storage,
        NoticeFeed(
          hideDays: 7,
          notices: [_notice('a'), _notice('b'), _notice('c')],
        ),
      );
      // 첫 장만 보고 체크한 뒤 닫는다
      await tester.tap(find.bySemanticsLabel('일주일간 보지 않기'));
      await tester.tap(find.bySemanticsLabel('공지 닫기'));
      await tester.pumpAndSettle();

      await launch(
        tester,
        storage,
        NoticeFeed(
          hideDays: 7,
          notices: [_notice('a'), _notice('b'), _notice('c')],
        ),
      );
      expect(find.byKey(NoticePopupCard.cardKey), findsNothing);

      await launch(
        tester,
        storage,
        NoticeFeed(
          hideDays: 7,
          notices: [_notice('a'), _notice('b', revision: 2), _notice('c')],
        ),
      );
      expect(find.byKey(NoticePopupCard.cardKey), findsOneWidget);
      expect(find.text('공지 b'), findsWidgets);
      expect(
        find.byKey(NoticePopupCard.dotsKey),
        findsNothing,
        reason: 'b 한 장만 뜬다',
      );
    });
  });
}

AppNotice _notice(String id, {int revision = 1}) =>
    AppNotice(id: id, revision: revision, title: '공지 $id', body: '본문이에요');

// ignore: strict_top_level_inference
testStorage(LocalStorage storage) =>
    localStorageProvider.overrideWithValue(storage);

class _FakeRepo extends NoticeRepository {
  _FakeRepo() : super(Dio());

  NoticeFeed reply = NoticeFeed.empty;
  Completer<NoticeFeed>? pending;
  int calls = 0;

  @override
  Future<NoticeFeed> fetch(NoticePlatform platform) {
    calls++;
    return pending?.future ?? Future.value(reply);
  }
}
