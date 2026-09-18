import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/svg_finder.dart';
import 'helpers/test_storage.dart';

/// 로그인 화면 (이슈 #207 · 명세 §2-1).
///
/// 첫 화면에서 **바로** 로그인할 수 있어야 한다. 제목은 로고가 대신한다 —
/// 로고 바로 밑에서 같은 말을 한 번 더 하지 않는다.
///
/// ## 시작 화면과 같은 그림을 쓴다
///
/// `시작하기`를 없애면서 두 화면이 하나가 됐다. 로그인 화면은 시작 화면의
/// 장면(`SplashScene`)을 그대로 깔고 그 위에 제공자 버튼만 얹는다. 배경이
/// 통째로 바뀌면 다른 앱으로 튄 것처럼 보이기 때문이다.
///
/// 그 장면은 새싹·구슬이 무한 반복으로 부유하므로 `pumpAndSettle()`이 끝나지
/// 않는다. 화면이 OS "동작 줄이기"를 존중해 idle을 멈추므로 그 설정을 켜고 돌린다.
void main() {
  useFigmaViewport();

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
            .platformDispatcher
            .accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  Widget wrap() {
    final router = GoRouter(
      initialLocation: Routes.login,
      routes: [
        GoRoute(
          path: Routes.login,
          builder: (context, state) => const LoginScreen(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [testStorageOverride()],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  testWidgets('글자 제목 대신 로고를 쓴다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(svgWithAsset(AppAssets.logo), findsOneWidget);
    // 로고가 이미 이름을 말하고 있다. 밑에서 또 말하지 않는다.
    expect(find.textContaining('시작해볼까요'), findsNothing);
  });

  testWidgets('시작 화면의 문구를 그대로 이어받는다 (이슈 #207)', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 시작 화면에서 넘어오자마자 문구가 바뀌면 화면이 갈아끼워진 것처럼 보인다.
    expect(find.text('오늘의 하루,'), findsOneWidget);
    expect(find.text('차근차근 함께해요'), findsOneWidget);
  });

  testWidgets('로그인 수단이 첫 화면에 모두 있다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 한 번 더 눌러 들어가는 화면이 아니다.
    expect(find.text('카카오로 시작하기'), findsOneWidget);
    expect(find.text('네이버로 시작하기'), findsOneWidget);
  });

  testWidgets('구글은 빠졌다 (이슈 #230)', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 시안에서 제공자가 넷에서 셋으로 줄었다. 버튼이 되살아나면 여기서 잡는다.
    expect(find.textContaining('Google'), findsNothing);
  });

  testWidgets('버튼마다 제공자 로고가 붙는다 (이슈 #230)', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 로고를 코드로 그리다 형태가 어긋난 적이 있다. 에셋을 쓰는지 직접 본다.
    // 애플은 iOS에서만 뜨므로 여기서는 보지 않는다.
    expect(svgWithAsset(AppAssets.loginKakao), findsOneWidget);
    expect(svgWithAsset(AppAssets.loginNaver), findsOneWidget);
  });

  testWidgets('시작 화면의 병아리 장면을 그대로 쓴다 (이슈 #207)', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 병아리를 따로 조립했다가 얼굴 없는 덩어리가 된 적이 있다.
    // 이제는 시작 화면과 **같은 위젯**을 쓰므로 구성 요소가 전부 따라온다.
    expect(svgWithAsset(AppAssets.splashChickBody), findsOneWidget);
    expect(svgWithAsset(AppAssets.splashCharLeft), findsOneWidget);
    expect(svgWithAsset(AppAssets.splashCharRight), findsOneWidget);
    expect(svgWithAsset(AppAssets.splashCenter), findsOneWidget);
    expect(svgWithAsset(AppAssets.splashHill), findsOneWidget);
    expect(svgWithAsset(AppAssets.splashFade), findsOneWidget);
  });

  testWidgets('버튼이 화면 밖으로 밀려나지 않는다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 그림 위에 겹쳐 얹는 구조라 버튼 묶음이 아래로 새면 마지막 버튼이 잘린다.
    // 애플은 iOS 전용이라 테스트 환경(호스트 OS)에서 마지막은 네이버다.
    final lastButton = tester.getRect(find.text('네이버로 시작하기'));
    expect(lastButton.bottom, lessThan(tester.view.physicalSize.height));
  });
}
