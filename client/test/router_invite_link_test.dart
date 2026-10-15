import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/profile/domain/invite_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';
import 'package:elum/core/router/routes.dart';

/// 초대 링크가 열렸을 때 라우터의 동작 (#365).
///
/// 링크 주소는 우리 라우트가 아니다. 이 테스트는 **실제 GoRouter 가 OS 가 넘기는 방식 그대로**
/// (앱이 꺼져 있다 열릴 때는 초기 경로, 켜져 있을 때는 `pushRouteInformation`) 주소를 받았을 때
/// 오류 화면이 뜨지 않고, 하던 화면을 지키며, 코드가 우편함 콜백으로 넘어가는지를 본다.
///
/// 켜져 있는 앱의 링크는 평소 `InviteLinkHost` 가 라우터보다 먼저 가져간다 (`invite_link_intake_test.dart`).
/// 여기의 켜져 있을 때 시험은 **그 앞단이 놓친 경우의 안전망**이다 — 이때 go_router 는 현재 자리로 되돌려
/// 오류 화면은 막지만 위에 쌓은 화면(`push`)은 다시 짜면서 잃는다. 그래서 안전망이지 주 경로가 아니다.
void main() {
  useFigmaViewport();

  late GoRouter router;
  late List<InviteLink> received;

  bool elumiDevice = false;

  GoRouter build({bool elumi = false}) {
    received = [];
    elumiDevice = elumi;
    return router = createRouter(
      isElumiDevice: () => elumi,
      onInviteLink: received.add,
    );
  }

  /// 진짜 라우터에 진짜 시작 화면을 올린다. 시작 화면의 1.7초 타이머는 테스트 끝에서 화면을 내려 취소한다.
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 이룸이 휴대폰은 로그인이 없다. 보호자는 세션이 있어 시작 화면이 온보딩 쪽으로 기다린다
          testStorageOverride(onboardingCompleted: false, elumiDevice: elumiDevice),
          tokenStoreProvider.overrideWithValue(
            elumiDevice ? InMemoryTokenStore() : InMemoryTokenStore(accessToken: 'a', refreshToken: 'r'),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, child) => MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// 앱이 켜져 있을 때 OS 가 새 주소를 밀어 넣는 경로 — `pushRouteInformation`.
  Future<void> pushFromOs(WidgetTester tester, String uri) async {
    final message = const JSONMethodCodec().encodeMethodCall(
      MethodCall('pushRouteInformation', {'location': uri}),
    );
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      message,
      (_) {},
    );
    await tester.pump();
    await tester.pump();
  }

  String location() => router.routerDelegate.currentConfiguration.uri.toString();

  group('위치를 고르는 규칙', () {
  });

  group('앱이 꺼져 있다 링크로 열릴 때', () {
    for (final raw in [
      'elum://invite?code=A7K3M9',
      '/invite?code=A7K3M9',
      'https://twin-fang.github.io/elum/invite/?code=A7K3M9',
    ]) {
      testWidgets('$raw → 오류 화면 없이 시작 화면에 서고 코드를 우편함에 맡긴다', (tester) async {
        tester.binding.platformDispatcher.defaultRouteNameTestValue = raw;
        addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
        build();
        await pump(tester);

        expect(received.map((l) => l.code), ['A7K3M9']);
        expect(location(), Routes.splash);
        expect(find.text('화면을 찾을 수 없어요'), findsNothing);
      });
    }

    testWidgets('이룸이 휴대폰에서는 우편함에 맡기지 않고 무시한다', (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = 'elum://invite?code=A7K3M9';
      addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
      build(elumi: true);
      await pump(tester);

      expect(received, isEmpty);
      expect(location(), Routes.splash);
      expect(find.text('화면을 찾을 수 없어요'), findsNothing);
    });
  });

  group('앱이 켜져 있을 때 링크가 오면', () {
    testWidgets('초대 링크가 아닌 주소는 맡기지 않는다 — 소셜 로그인 콜백을 건드리지 않는다', (tester) async {
      build();
      await pump(tester);

      await pushFromOs(tester, '/somewhere');

      expect(received, isEmpty);
    });
  });
}
