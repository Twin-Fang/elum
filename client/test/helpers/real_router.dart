import 'package:dio/dio.dart';
import 'package:elum/core/network/dio_client.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_scaffold.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_dio.dart';
import 'no_disk_cache.dart';

/// 실제 앱 라우터(`createRouter`)를 저장소·토큰과 묶어 띄운다. 가드·뒤로가기·로그아웃 도착지 테스트는 이것으로 한다.
/// 가드 없는 가짜 `GoRouter` 로는 가드와 화면 쌓기의 충돌이 보이지 않는다.
///
/// - 시작 화면의 자동 이동이 끝난 뒤 [start] 로 옮긴다. 늦게 온 자동 이동이 시험 중 이동을 덮지 않게.
/// - 로그인 장면이 무한 반복이라 동작 줄이기를 켠다.
Future<({GoRouter router, ProviderContainer container})> pumpRealRouter(
  WidgetTester tester, {
  required LocalStorage storage,
  required InMemoryTokenStore tokens,
  required String start,
  Map<String, Object?> routes = const {},

  /// 화면이 더 필요로 하는 provider (약관 목록·앱 버전 등).
  List overrides = const [],
}) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  binding.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);

  final router = createRouter(
    isOnboardingCompleted: () => storage.isOnboardingCompleted,
    hasToken: () => tokens.hasSession,
    isElumiDevice: () => storage.isElumiDevice,
    hasRole: () => storage.selectedRole != null,
  );
  addTearDown(router.dispose);
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
    ..httpClientAdapter = FakeAdapter(Map.of(routes));

  // 앱 재시작을 흉내 낼 때 이전 ProviderScope 를 먼저 내린다
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(dio),
        tokenStoreProvider.overrideWithValue(tokens),
        localStorageProvider.overrideWithValue(storage),
        noDiskCacheOverride(),
        ...overrides,
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) =>
            MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    ),
  );
  // 시작 화면의 연출 대기(1.7초)와 자동 이동을 끝낸다
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
  if (start != Routes.splash) {
    router.go(start);
    await tester.pumpAndSettle();
  }
  return (
    router: router,
    container: ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
    ),
  );
}

/// 맨 위 화면. `currentConfiguration.uri` 는 push 로 쌓은 화면을 반영하지 않아 쓰지 않는다 (go_router 17).
String topOf(GoRouter router) =>
    router.routerDelegate.currentConfiguration.last.matchedLocation;

/// 공통 뼈대의 뒤로가기를 누른다.
Future<void> tapBack(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel(ElumScaffold.backLabel).last);
  await tester.pumpAndSettle();
}
