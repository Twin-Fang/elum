import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/router/pop_or_home.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// 뒤로가기 안전망. `go` 로 열린 화면은 돌아갈 화면이 없으므로 지금 상태의 홈으로 간다.
void main() {
  late GoRouter router;

  /// 화면마다 이름과 "뒤로" 버튼만 있는 라우터.
  Widget page(String name) => Builder(
    builder: (context) => Scaffold(
      body: Column(
        children: [
          Text('화면 $name'),
          TextButton(onPressed: context.popOrHome, child: const Text('뒤로')),
        ],
      ),
    ),
  );

  Future<void> pump(
    WidgetTester tester, {
    required LocalStorage storage,
    InMemoryTokenStore? tokens,
  }) async {
    router = GoRouter(
      initialLocation: '/a',
      routes: [
        GoRoute(path: '/a', builder: (_, _) => page('a')),
        GoRoute(path: '/b', builder: (_, _) => page('b')),
        GoRoute(path: Routes.login, builder: (_, _) => page('로그인')),
        GoRoute(path: Routes.guardian, builder: (_, _) => page('보호자 홈')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          tokenStoreProvider.overrideWithValue(tokens ?? InMemoryTokenStore()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  String top() => router.routerDelegate.currentConfiguration.last.matchedLocation;

  testWidgets('쌓인 화면이 있으면 그대로 돌아간다', (tester) async {
    await pump(tester, storage: InMemoryStorage());
    router.push('/b');
    await tester.pumpAndSettle();

    await tester.tap(find.text('뒤로'));
    await tester.pumpAndSettle();

    expect(top(), '/a');
  });

  testWidgets('돌아갈 화면이 없으면 지금 상태의 홈으로 간다 — 세션 없음 → 로그인', (tester) async {
    await pump(tester, storage: InMemoryStorage());
    expect(router.canPop(), isFalse, reason: '전제: go 로 열린 화면이다');

    await tester.tap(find.text('뒤로'));
    await tester.pumpAndSettle();

    expect(top(), Routes.login);
    expect(tester.takeException(), isNull, reason: 'pop 이 오류를 던지면 안 된다');
  });

  testWidgets('보호자 세션이면 보호자 홈으로 간다', (tester) async {
    await pump(
      tester,
      storage: InMemoryStorage(onboardingCompleted: true),
      tokens: InMemoryTokenStore(accessToken: 'a', refreshToken: 'r'),
    );

    await tester.tap(find.text('뒤로'));
    await tester.pumpAndSettle();

    expect(top(), Routes.guardian);
  });

  testWidgets('이미 홈이면 아무것도 하지 않는다 — 같은 화면을 다시 띄우지 않는다', (tester) async {
    await pump(tester, storage: InMemoryStorage());
    router.go(Routes.login);
    await tester.pumpAndSettle();

    await tester.tap(find.text('뒤로'));
    await tester.pumpAndSettle();

    expect(top(), Routes.login);
    expect(router.routerDelegate.currentConfiguration.matches, hasLength(1));
  });

  testWidgets('저장소를 읽다 오류가 나면 로그인 화면으로 간다 — 누구나 들어갈 수 있는 곳이다', (tester) async {
    await pump(tester, storage: _BrokenStorage());

    await tester.tap(find.text('뒤로'));
    await tester.pumpAndSettle();

    expect(top(), Routes.login);
  });
}

/// 값을 읽으면 터지는 저장소 — 초기화가 꼬인 휴대폰을 흉내 낸다.
class _BrokenStorage extends InMemoryStorage {
  @override
  bool get isOnboardingCompleted => throw StateError('저장소 손상');
}
