import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/profile/application/invite_inbox.dart';
import 'package:elum/features/profile/application/invite_link_intake.dart';
import 'package:elum/features/profile/data/profile_repository.dart';
import 'package:elum/features/profile/presentation/invite_link_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/profile_fixtures.dart';
import 'helpers/test_storage.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/core/router/routes.dart';

/// 링크가 열려서 코드가 채워진 입력 화면에 닿기까지 — **`ElumApp` 과 같은 배선**으로 끝에서 끝까지 (#365).
///
/// 진짜 라우터(`createRouter`)·진짜 받는 쪽(`InviteLinkHost`)·진짜 판단(`InviteLinkIntake`)·진짜 우편함·
/// 진짜 입력 화면을 잇는다. 서버만 가짜다. 조각마다 따로 검증한 것이 **이어 붙였을 때도 되는지** 본다.
void main() {
  useFigmaViewport();

  late FakeProfileRepository repo;
  late InviteInbox inbox;
  late GoRouter router;
  var session = true;

  Future<void> pumpApp(WidgetTester tester) async {
    repo = FakeProfileRepository();
    inbox = InviteInbox();
    late InviteLinkIntake intake;
    router = createRouter(
      isOnboardingCompleted: () => false,
      hasToken: () => session,
      isElumiDevice: () => false,
      hasRole: () => true,
      onInviteLink: (link) => intake.accept(link),
    );
    intake = InviteLinkIntake(
      inbox: inbox,
      isElumiDevice: () => false,
      hasSession: () => session,
      topLocation: () => router.routerDelegate.currentConfiguration.lastOrNull?.matchedLocation,
      open: () => router.push(Routes.inviteEnter),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          testStorageOverride(onboardingCompleted: false),
          tokenStoreProvider.overrideWithValue(
            InMemoryTokenStore(accessToken: session ? 'a' : null, refreshToken: session ? 'r' : null),
          ),
          profileRepositoryProvider.overrideWithValue(repo),
          memberProvider.overrideWith((ref) async => memberWith([kProfileB])),
          inviteInboxProvider.overrideWithValue(inbox),
        ],
        child: InviteLinkHost(
          router: router,
          intake: intake,
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, child) => MaterialApp.router(theme: AppTheme.light, routerConfig: router),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// 화면 전환과 다음 프레임에 예약된 열기까지 마친다.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> pushFromOs(WidgetTester tester, String uri) async {
    final message = const JSONMethodCodec().encodeMethodCall(
      MethodCall('pushRouteInformation', {'location': uri}),
    );
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage('flutter/navigation', message, (_) {});
    await settle(tester);
  }

  setUp(() => session = true);

  testWidgets('앱이 꺼져 있다 링크로 열리면: 시작 화면 → 이름 화면에 닿았을 때 코드가 채워진 입력 화면이 얹힌다', (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = 'elum://invite?code=A7K3M9';
    addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
    await pumpApp(tester);

    // 오류 화면이 아니라 시작 화면이고, 코드는 우편함에 맡겨져 있다
    expect(find.text('화면을 찾을 수 없어요'), findsNothing);
    expect(inbox.hasPending, isTrue);

    // 시작 화면이 보호자를 온보딩 이름 화면으로 보낸다 (여기서는 그 도착을 직접 만든다)
    router.go(Routes.onboardingName);
    await settle(tester);

    expect(find.text('함께하기'), findsOneWidget);
    for (final ch in 'A7K3M9'.split('')) {
      expect(find.text(ch), findsOneWidget);
    }
    // 자동으로 합류하지 않는다
    expect(repo.sentCodes, isEmpty);
    expect(inbox.hasPending, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('로그인 전에 열리면: 로그인·약관을 마치고 이름 화면에 닿은 뒤에야 입력 화면이 열린다', (tester) async {
    session = false;
    tester.binding.platformDispatcher.defaultRouteNameTestValue = 'elum://invite?code=A7K3M9';
    addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
    await pumpApp(tester);

    expect(inbox.hasPending, isTrue);
    expect(find.text('함께하기'), findsNothing);

    // 로그인을 마쳤다
    session = true;
    router.go(Routes.onboardingName);
    await settle(tester);

    expect(find.text('함께하기'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('입력 화면이 열려 있는 채로 새 링크가 오면 제자리에서 새 코드로 바뀐다', (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = 'elum://invite?code=A7K3M9';
    addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
    await pumpApp(tester);
    router.go(Routes.onboardingName);
    await settle(tester);
    expect(find.text('A'), findsOneWidget);

    // 보호자가 코드를 다시 만들어 새 링크를 보냈다
    await pushFromOs(tester, 'elum://invite?code=B2C4D6');

    expect(find.text('함께하기'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('A'), findsNothing);
    expect(repo.sentCodes, isEmpty);
    // 두 겹 쌓이지 않았다 — 뒤로 한 번이면 이름 화면이다
    router.pop();
    await settle(tester);
    expect(router.routerDelegate.currentConfiguration.last.matchedLocation, Routes.onboardingName);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('쓸 수 없는 코드의 링크면 빈 입력 화면과 에러 코드가 열린다', (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = 'elum://invite?code=ZZZ';
    addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
    await pumpApp(tester);
    router.go(Routes.onboardingName);
    await settle(tester);

    expect(find.textContaining('E-INV-LINK'), findsOneWidget);
    expect(find.text('함께하기'), findsNothing);
    expect(repo.sentCodes, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
