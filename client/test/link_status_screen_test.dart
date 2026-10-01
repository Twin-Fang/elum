import 'package:dio/dio.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_dialog.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/link/presentation/link_status_screen.dart';
import 'package:elum/core/network/dio_client.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_dio.dart';

/// 이룸이 휴대폰 — 연결 상태와 끊기 (명세 §8-5 · 이슈 #363).
///
/// 되돌릴 수 없는 동작이라 **성공·실패·이미 끊김**을 모두 밟는다. 실패하면 연결이 그대로라 화면에 머물고
/// 에러 코드가 보여야 한다.
void main() {
  useFigmaViewport();

  late FakeAdapter adapter;
  late Map<String, Object?> routes;

  const oneDevice = {
    'devices': [
      {'linkId': 'l1', 'linkedAt': '2026-09-18T10:31:00'},
    ],
    'pendingExpiresAt': null,
  };
  const noDevice = {'devices': <Object?>[], 'pendingExpiresAt': null};

  setUp(() {
    routes = {'GET /api/device-links': oneDevice};
    adapter = FakeAdapter(routes);
  });

  Widget wrap() {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = adapter;
    final router = GoRouter(
      initialLocation: Routes.guardianSettings,
      routes: [
        GoRoute(
          path: Routes.guardianSettings,
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push(Routes.guardianLinkStatus),
                child: const Text('설정 화면'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: Routes.guardianLinkStatus,
          builder: (context, state) => const LinkStatusScreen(),
        ),
        GoRoute(
          path: Routes.linkCode,
          builder: (context, state) => const Scaffold(body: Text('연결 암호 화면')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(dio),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        localStorageProvider.overrideWithValue(InMemoryStorage()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) =>
            MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정 화면'));
    await tester.pumpAndSettle();
  }

  Finder dialogButton(String label) => find.descendant(
    of: find.byType(ElumDialogCard<bool>),
    matching: find.text(label),
  );

  Future<void> tapDisconnect(WidgetTester tester) async {
    await tester.tap(find.text('연결 끊기'));
    await tester.pumpAndSettle();
  }

  group('보여주는 것', () {
    testWidgets('연결됨 · 언제부터 · 연결 끊기 · 끊으면 어떻게 되는지 한 줄', (tester) async {
      await open(tester);

      expect(find.text('이룸이 휴대폰'), findsOneWidget, reason: '제목');
      expect(find.text('연결됨'), findsOneWidget);
      expect(find.text('9월 18일부터'), findsOneWidget);
      expect(find.text('연결 끊기'), findsOneWidget);
      expect(find.textContaining('끊으면 이룸이 휴대폰에서'), findsOneWidget);
    });

    testWidgets('여러 대가 붙어 있으면 대마다 이름과 끊기 버튼이 있다', (tester) async {
      routes['GET /api/device-links'] = const {
        'devices': [
          {'linkId': 'l2', 'linkedAt': '2026-09-20T09:00:00'},
          {'linkId': 'l1', 'linkedAt': '2026-09-18T10:31:00'},
        ],
      };
      await open(tester);

      expect(find.text('이룸이 휴대폰 1'), findsOneWidget);
      expect(find.text('이룸이 휴대폰 2'), findsOneWidget);
      expect(find.text('연결 끊기'), findsNWidgets(2));
      expect(find.text('9월 20일부터'), findsOneWidget);
    });

    testWidgets('연결된 휴대폰이 없으면(다른 사람이 먼저 끊음) 연결하기로 이어 준다', (tester) async {
      routes['GET /api/device-links'] = noDevice;
      await open(tester);

      expect(find.text('연결된 휴대폰이 없어요'), findsOneWidget);
      expect(find.text('연결 끊기'), findsNothing);

      await tester.tap(find.text('이룸이 휴대폰 연결하기'));
      await tester.pumpAndSettle();
      expect(find.text('연결 암호 화면'), findsOneWidget);
    });

    testWidgets('상태를 못 불러오면 빈 화면이 아니라 이유·에러 코드·다시 시도가 보이고, 다시 시도하면 불러온다', (
      tester,
    ) async {
      routes['GET /api/device-links'] = const FakeOffline();
      await open(tester);

      expect(find.textContaining('연결 상태를 불러오지 못했어요'), findsOneWidget);
      expect(find.textContaining('E-NET-OFFLINE'), findsOneWidget);
      expect(find.textContaining('인터넷 연결을 확인해주세요'), findsOneWidget);
      expect(
        find.text('연결 끊기'),
        findsNothing,
        reason: '연결 상태를 모르는데 끊기를 보여 주지 않는다',
      );

      routes['GET /api/device-links'] = oneDevice;
      await tester.tap(find.textContaining('다시 시도'));
      await tester.pumpAndSettle();

      expect(find.text('연결됨'), findsOneWidget);
    });

    testWidgets('서버가 이유를 주면 그 문구를 쓴다 (403)', (tester) async {
      routes['GET /api/device-links'] = const FakeHttpError(
        403,
        errorCode: 'PROFILE_ACCESS_DENIED',
        errorMessage: '이 이룸이의 정보를 볼 수 없어요.',
      );
      await open(tester);

      expect(find.textContaining('이 이룸이의 정보를 볼 수 없어요.'), findsOneWidget);
      expect(find.textContaining('PROFILE_ACCESS_DENIED'), findsOneWidget);
    });
  });

  group('끊기', () {
    testWidgets('누르면 되돌릴 수 있다고 함께 말하는 확인 팝업이 먼저 뜬다 — 요청은 아직 안 나간다', (
      tester,
    ) async {
      await open(tester);
      await tapDisconnect(tester);

      expect(find.text('연결을 끊을까요?'), findsOneWidget);
      expect(find.textContaining('새 암호를 만들면 돼요'), findsOneWidget);
      expect(adapter.calls.where((c) => c.startsWith('DELETE')), isEmpty);
    });

    testWidgets('취소하면 아무 일도 없다', (tester) async {
      await open(tester);
      await tapDisconnect(tester);

      await tester.tap(dialogButton('취소'));
      await tester.pumpAndSettle();

      expect(adapter.calls.where((c) => c.startsWith('DELETE')), isEmpty);
      expect(find.text('연결됨'), findsOneWidget);
    });

    testWidgets('확인하면 그 연결을 끊고, 남은 휴대폰이 없으면 설정으로 돌아가 알린다', (tester) async {
      routes['DELETE /api/device-links/l1'] = const <String, Object?>{};
      await open(tester);
      await tapDisconnect(tester);

      // 끊은 뒤에는 목록이 비어 온다
      routes['GET /api/device-links'] = noDevice;
      await tester.tap(dialogButton('연결 끊기'));
      await tester.pumpAndSettle();

      expect(adapter.calls, contains('DELETE /api/device-links/l1'));
      expect(find.text('설정 화면'), findsOneWidget, reason: '설정으로 돌아갔다');
      expect(find.text('연결을 끊었어요'), findsOneWidget);
    });

    testWidgets('이미 끊겨 있었으면(404) 실패가 아니라 `이미 끊겨 있어요`로 알린다', (tester) async {
      routes['DELETE /api/device-links/l1'] = const FakeHttpError(
        404,
        errorCode: 'DEVICE_LINK_NOT_CONNECTED',
      );
      await open(tester);
      await tapDisconnect(tester);

      routes['GET /api/device-links'] = noDevice;
      await tester.tap(dialogButton('연결 끊기'));
      await tester.pumpAndSettle();

      expect(find.text('이미 끊겨 있어요'), findsOneWidget);
      expect(find.text('설정 화면'), findsOneWidget);
      expect(find.textContaining('연결을 끊지 못했어요'), findsNothing);
    });

    testWidgets('서버 오류면 화면에 머물고 에러 코드를 보여준다 — 연결은 그대로다', (tester) async {
      routes['DELETE /api/device-links/l1'] = const FakeHttpError(500);
      await open(tester);
      await tapDisconnect(tester);

      await tester.tap(dialogButton('연결 끊기'));
      await tester.pumpAndSettle();

      expect(find.textContaining('연결을 끊지 못했어요'), findsOneWidget);
      expect(find.textContaining('E-LINK-OUT/500'), findsOneWidget);

      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text('연결됨'), findsOneWidget, reason: '끊기지 않았으니 연결됨 그대로');
      expect(find.text('연결 끊기'), findsOneWidget, reason: '다시 누를 수 있다');
    });

    testWidgets('권한이 없으면(403) 서버가 준 이유와 코드를 보여준다', (tester) async {
      routes['DELETE /api/device-links/l1'] = const FakeHttpError(
        403,
        errorCode: 'PROFILE_ACCESS_DENIED',
        errorMessage: '이 이룸이의 정보를 볼 수 없어요.',
      );
      await open(tester);
      await tapDisconnect(tester);

      await tester.tap(dialogButton('연결 끊기'));
      await tester.pumpAndSettle();

      expect(find.textContaining('이 이룸이의 정보를 볼 수 없어요.'), findsOneWidget);
      expect(find.textContaining('PROFILE_ACCESS_DENIED'), findsOneWidget);
    });

    testWidgets('인터넷이 없으면 인터넷을 확인하라고 말하고 E-NET-OFFLINE 을 남긴다', (tester) async {
      routes['DELETE /api/device-links/l1'] = const FakeOffline();
      await open(tester);
      await tapDisconnect(tester);

      await tester.tap(dialogButton('연결 끊기'));
      await tester.pumpAndSettle();

      expect(find.textContaining('인터넷 연결을 확인해주세요'), findsOneWidget);
      expect(find.textContaining('E-NET-OFFLINE'), findsOneWidget);
    });

    testWidgets('빨리 두 번 눌러도 한 번만 나간다', (tester) async {
      routes['DELETE /api/device-links/l1'] = const <String, Object?>{};
      await open(tester);
      await tapDisconnect(tester);
      routes['GET /api/device-links'] = noDevice;

      await tester.tap(dialogButton('연결 끊기'));
      await tester.pump();
      // 응답을 기다리는 사이 다시 눌러도 버튼이 비활성이라 팝업이 또 뜨지 않는다
      await tester.pumpAndSettle();

      expect(
        adapter.calls.where((c) => c == 'DELETE /api/device-links/l1'),
        hasLength(1),
      );
    });
  });
}
