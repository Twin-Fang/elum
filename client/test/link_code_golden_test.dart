@Tags(['golden'])
library;

import 'package:dio/dio.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/link/data/device_link_repository.dart';
import 'package:elum/features/link/domain/link_status.dart';
import 'package:elum/features/link/presentation/link_code_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';

/// 연결 암호 세 상태 (Figma 732:5334 · 732:5702 · 732:5850 · 이슈 #232).
///
/// **진짜 `LinkCodeScreen`을 렌더한다.** 1초 타이머가 계속 돌아
/// `pumpAndSettle()`은 쓸 수 없다 — 필요한 만큼만 `pump()`한다.
void main() {
  useFigmaViewport();

  late _FakeLink repo;

  setUp(() => repo = _FakeLink());

  Widget wrap() {
    final router = GoRouter(
      initialLocation: Routes.linkCode,
      routes: [
        GoRoute(
          path: Routes.linkCode,
          builder: (context, state) =>
              const LinkCodeScreen(fromOnboarding: true),
        ),
        GoRoute(
          path: Routes.guardian,
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        deviceLinkRepositoryProvider.overrideWithValue(repo),
        testStorageOverride(nickname: '하늘이'),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        useInheritedMediaQuery: true,
        builder: (context, child) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  testWidgets('대기 — 암호·카운트다운·다시 만들기', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(LinkCodeScreen),
      matchesGoldenFile('goldens/link_waiting.png'),
    );
  });

  testWidgets('연결 성공 팝업', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    repo.linked = true;
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 팝업은 화면 위에 뜨므로 앱 전체를 찍는다.
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/link_success_popup.png'),
    );
  });

  testWidgets('연결됨 — 타이머도 다시 만들기도 없다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    repo.linked = true;
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.tap(find.text('확인'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(LinkCodeScreen),
      matchesGoldenFile('goldens/link_linked.png'),
    );
  });
}

class _FakeLink extends DeviceLinkRepository {
  _FakeLink()
      : super(
          dio: Dio(),
          tokens: InMemoryTokenStore(),
          storage: InMemoryStorage(),
        );

  bool linked = false;

  @override
  Future<Attempt<IssuedLinkCode>> issue() async => Attempt.ok(
        IssuedLinkCode.fromNow(code: '5NJ280', expiresInSeconds: 599),
      );

  @override
  Future<LinkStatus> status() async => LinkStatus(
        devices: linked
            ? [LinkedDevice(linkId: 'l1', linkedAt: DateTime(2026, 9, 18))]
            : const [],
      );
}
