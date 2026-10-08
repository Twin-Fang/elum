import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/router/routes.dart';

/// 이름 화면은 어디로 들어와도 뒤로 갈 수 있어야 한다.
/// go 로 들어오면(앱 재시작·함께 돌보기 그만두기 뒤) 쌓인 화면이 없어 pop 이 안 되므로,
/// 저장된 역할을 지우고 역할 선택으로 간다. 진짜 라우터(가드 포함)로 검증한다.
void main() {
  useFigmaViewport();

  late GoRouter router;
  late InMemoryStorage storage;

  Future<void> pump(WidgetTester tester) async {
    storage = InMemoryStorage(onboardingCompleted: false);
    await storage.setSelectedRole('guardian');
    router = createRouter(
      isOnboardingCompleted: () => storage.isOnboardingCompleted,
      hasToken: () => true,
      isElumiDevice: () => false,
      hasRole: () => storage.selectedRole != null,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          tokenStoreProvider.overrideWithValue(
            InMemoryTokenStore(accessToken: 'a', refreshToken: 'r'),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, child) =>
              MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      ),
    );
    router.go(Routes.onboardingName);
    await tester.pumpAndSettle();
  }

  String top() =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  Finder backButton() => find.bySemanticsLabel('뒤로 가기');

  testWidgets('go 로 들어와도 뒤로가기가 있고 누르면 역할을 지우고 역할 선택으로 간다', (tester) async {
    await pump(tester);
    expect(top(), Routes.onboardingName);
    expect(backButton(), findsOneWidget);

    await tester.tap(backButton());
    await tester.pumpAndSettle();

    expect(top(), Routes.roleSelect);
    expect(storage.selectedRole, isNull);
  });

  testWidgets('시스템 뒤로가기도 같은 곳으로 간다', (tester) async {
    await pump(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(top(), Routes.roleSelect);
    expect(storage.selectedRole, isNull);
  });

  testWidgets('역할 선택에서 push 로 들어왔으면 역할을 건드리지 않고 pop 한다', (tester) async {
    await pump(tester);
    router.go(Routes.roleSelect);
    await tester.pumpAndSettle();
    router.push(Routes.onboardingName);
    await tester.pumpAndSettle();
    expect(top(), Routes.onboardingName);

    await tester.tap(backButton());
    await tester.pumpAndSettle();

    expect(top(), Routes.roleSelect);
    expect(storage.selectedRole, 'guardian');
  });
}
