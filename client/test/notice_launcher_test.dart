import 'dart:async';

import 'package:dio/dio.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/notice/data/notice_repository.dart';
import 'package:elum/features/notice/domain/app_notice.dart';
import 'package:elum/features/notice/presentation/guardian_notice_launcher.dart';
import 'package:elum/features/notice/presentation/notice_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_dio.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/app/dio_provider.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/router/routes.dart';

/// 보호자 홈에서만, 앱 실행 중 처음 한 번 (이슈 #371 · 명세 2장 · 3-2).
/// 여러 개면 **차례로**, `보지 않기` 는 공지마다 (이슈 #390).
void main() {
  useFigmaViewport();

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
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, _) =>
                MaterialApp.router(theme: AppTheme.light, routerConfig: router),
          ),
        ),
      );
      return router;
    }

    setUp(() => repo = _FakeRepo());

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
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, _) => MaterialApp(
              theme: AppTheme.light,
              home: const GuardianNoticeLauncher(
                child: Scaffold(body: Center(child: Text('보호자 홈'))),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder titleOf(String id) => find.byKey(ValueKey('notice-title-$id'));
    Future<void> close(WidgetTester tester) async {
      await tester.tap(find.byKey(NoticePopupCard.closeKey));
      await tester.pumpAndSettle();
    }

    testWidgets('N7 숨긴 공지도 판이 오르면 다시 뜬다', (tester) async {
      final storage = InMemoryStorage(onboardingCompleted: true);
      await launch(
        tester,
        storage,
        NoticeFeed(hideDays: 7, notices: [_notice('b')]),
      );
      await tester.tap(find.bySemanticsLabel('일주일간 보지 않기'));
      await close(tester);

      await launch(
        tester,
        storage,
        NoticeFeed(hideDays: 7, notices: [_notice('b')]),
      );
      expect(find.byKey(NoticePopupCard.cardKey), findsNothing);

      await launch(
        tester,
        storage,
        NoticeFeed(hideDays: 7, notices: [_notice('b', revision: 2)]),
      );
      expect(titleOf('b'), findsOneWidget);
    });

    testWidgets('#385 D 띄움·닫은 방법·숨김을 원문 없이 남긴다', (tester) async {
      final lines = <String>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
      // 테스트 본문이 끝나기 전에 되돌려야 한다 — 바인딩이 본문 직후에 검사한다
      try {
        final storage = InMemoryStorage(onboardingCompleted: true);
        await launch(
          tester,
          storage,
          NoticeFeed(
            hideDays: 7,
            notices: [_notice('a'), _notice('b', revision: 4)],
          ),
        );
        await close(tester);
        await tester.tap(find.bySemanticsLabel('일주일간 보지 않기'));
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
      } finally {
        debugPrint = original;
      }

      final log = lines.join('\n');
      expect(log, contains('event: show'));
      expect(log, contains('notice: a@1 | order: 1/2'));
      expect(log, contains('notice: a@1 | how: close | hide: false'));
      expect(log, contains('notice: b@4 | order: 2/2'));
      expect(log, contains('notice: b@4 | how: outside | hide: true'));
      expect(log, isNot(contains('본문이에요')));
      expect(log, isNot(contains('공지 a')));
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
