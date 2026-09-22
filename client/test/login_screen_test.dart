import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/data/oauth_sdk.dart';
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
/// ## 그림은 플랫폼마다 다르다 (이슈 #338)
///
/// 시안이 `로그인_iOS`(238:1808)와 `로그인_AOS`(1022:4333) 둘로 나왔다.
/// 병아리가 서로 **반대쪽을 보고**, 새싹도 화면 반대편에 있으며, 몸통 크기까지
/// 다르다. 그래서 `LoginScene`이 배치 한 벌(`LoginSceneLayout`)을 갈아끼운다.
///
/// 어느 쪽을 그리는지는 `LoginScreen.debugPretendIos`로 정한다. 그 값 하나가
/// **애플 버튼 유무와 장면 배치를 함께** 정하므로, 시안에 없는 조합(얼굴 +
/// 버튼 셋)이 시험에서 만들어지지 않는다.
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
    expect(find.text('카카오로 로그인'), findsOneWidget);
    expect(find.text('네이버로 로그인'), findsOneWidget);
  });

  testWidgets('애플이 승인한 문구를 쓴다 (이슈 #237)', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 애플은 `Apple로 로그인`·`Apple로 계속하기`·`Apple로 가입` 셋만 허용한다.
    // 셋 중 하나에 카카오·네이버도 맞췄다 — 애플만 다르면 버튼이 어긋난다.
    expect(find.textContaining('로 시작하기'), findsNothing);
    expect(find.text('카카오로 로그인'), findsOneWidget);
    expect(find.text('네이버로 로그인'), findsOneWidget);
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

  group('배치가 시안대로 갈린다 (이슈 #338)', () {
    tearDown(() => LoginScreen.debugPretendIos = null);

    testWidgets('iOS는 뒤돌아본 병아리 — 왼쪽 새싹, 작은 몸통', (tester) async {
      LoginScreen.debugPretendIos = true;
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // 병아리를 따로 조립했다가 형태가 어긋난 적이 있다 — 에셋을 그대로 쓴다.
      expect(imageWithAsset(AppAssets.splashChickBody), findsOneWidget);
      expect(svgWithAsset(AppAssets.splashHill), findsOneWidget);
      expect(imageWithAsset(AppAssets.splashOrb), findsOneWidget);
      // 안드로이드 전용 에셋이 섞이면 새싹이 반대로 휜다
      expect(imageWithAsset(AppAssets.splashChickBodyAos), findsNothing);
      expect(svgWithAsset(AppAssets.splashHillAos), findsNothing);
    });

    testWidgets('안드로이드는 앞을 보는 병아리 — 오른쪽 새싹, 큰 몸통', (tester) async {
      LoginScreen.debugPretendIos = false;
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(imageWithAsset(AppAssets.splashChickBodyAos), findsOneWidget);
      expect(svgWithAsset(AppAssets.splashHillAos), findsOneWidget);
      expect(imageWithAsset(AppAssets.splashOrb), findsOneWidget);
      expect(imageWithAsset(AppAssets.splashChickBody), findsNothing);
      expect(svgWithAsset(AppAssets.splashHill), findsNothing);
    });

    testWidgets('새싹이 시안 자리에 온다 — 두 배치가 화면 반대편이다', (tester) async {
      // 좌표를 두 벌 복사하다 한쪽만 고쳐지는 사고를 막는다.
      LoginScreen.debugPretendIos = true;
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      final iosStem = tester.getRect(svgWithAsset(AppAssets.splashHill)).left;

      LoginScreen.debugPretendIos = false;
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      final aosStem = tester.getRect(svgWithAsset(AppAssets.splashHillAos)).left;

      expect(iosStem, closeTo(87, 1)); // 시안 238:1808
      expect(aosStem, closeTo(183.5, 1)); // 시안 1022:4333
    });

    testWidgets('상단 문구가 안드로이드에서 더 위에 있다', (tester) async {
      LoginScreen.debugPretendIos = true;
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      final iosTitle = tester.getRect(find.text('차근차근 함께해요')).top;

      LoginScreen.debugPretendIos = false;
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      final aosTitle = tester.getRect(find.text('차근차근 함께해요')).top;

      // 시안 y: iOS 168 · AOS 131.7 (글꼴 베이스라인 때문에 값 자체가 아니라
      // 둘의 차이를 본다 — 36.3만큼 위로 올라가야 한다)
      expect(iosTitle - aosTitle, closeTo(36.3, 1.5));
    });
  });

  group('idle 부유 모션 (시작 화면에서 옮겨 옴 — 이슈 #338)', () {
    /// 줄기+구슬 부유 위젯 안의 Transform.translate 세로 offset을 읽는다.
    double stemOffsetY(WidgetTester tester) {
      final transform = tester.widget<Transform>(
        find.descendant(
          of: find.byKey(const ValueKey('splash-stem-float')),
          matching: find.byType(Transform),
        ),
      );
      return transform.transform.getTranslation().y;
    }

    testWidgets('줄기와 구슬이 부유한다', (tester) async {
      // 병아리 몸은 고정, 줄기+구슬만 아주 살짝 상하로 떠다닌다.
      // 동작 줄이기가 켜져 있으면 멈추므로 이 시험만 꺼 둔다.
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 200));

      final before = stemOffsetY(tester);
      await tester.pump(const Duration(milliseconds: 700));

      expect(stemOffsetY(tester), isNot(before));
    });

    testWidgets('동작 줄이기 설정에서는 idle이 정지한다', (tester) async {
      // 움직임에 민감한 사용자 보호 (motion.md §접근성).
      // 반복 중이면 pumpAndSettle이 타임아웃으로 실패한다.
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(imageWithAsset(AppAssets.splashOrb), findsOneWidget);
    });
  });

  /// 지난번에 카카오로 로그인한 상태를 만든다 — 그래야 안내 문구가 뜬다.
  Future<Widget> wrapWithLastProvider() async {
    final storage = InMemoryStorage();
    await storage.setLastLoginProvider(OAuthProvider.kakao.name);
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
      overrides: [localStorageProvider.overrideWithValue(storage)],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) => MaterialApp.router(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          routerConfig: router,
        ),
      ),
    );
  }

  group('지난번 로그인 안내는 그림 위에서도 읽힌다 (이슈 #337)', () {
    // 안드로이드는 얼굴을 그리므로(#297) 이 문구가 **부리와 정확히 겹친다** —
    // 부리 y614~638, 문구 y623~633. 회색 글자가 주황 부리에 묻혀 `이걸로` 가
    // 읽히지 않았다. 글자 뒤에 옅은 알약을 깔아 어느 그림 위에서도 읽히게 한다.
    testWidgets('문구 뒤에 배경이 깔린다', (tester) async {
      await tester.pumpWidget(await wrapWithLastProvider());
      await tester.pumpAndSettle();

      final hint = find.text('지난번에 이걸로 로그인했어요');
      expect(hint, findsOneWidget);

      final box = tester.widget<Container>(
        find
            .ancestor(of: hint, matching: find.byType(Container))
            .first,
      );
      final decoration = box.decoration as BoxDecoration?;
      expect(
        decoration?.color,
        isNotNull,
        reason: '배경이 없으면 그림 위에서 글자가 묻힌다',
      );
      expect(
        decoration?.color?.a,
        lessThan(1.0),
        reason: '반투명이어야 덧댄 것처럼 보이지 않는다',
      );
    });

    testWidgets('알약이 글자만큼만 넓다 — 버튼 폭으로 늘어나지 않는다', (tester) async {
      await tester.pumpWidget(await wrapWithLastProvider());
      await tester.pumpAndSettle();

      final pill = tester.getSize(
        find
            .ancestor(
              of: find.text('지난번에 이걸로 로그인했어요'),
              matching: find.byType(Container),
            )
            .first,
      );
      final button = tester.getSize(find.text('카카오로 로그인'));
      expect(pill.width, lessThan(button.width * 3));
    });
  });

  group('병아리 얼굴은 애플 버튼 유무를 따른다 (이슈 #297)', () {
    // 시안(`238:1808`)은 병아리가 **뒤를 돌아본** 모습이라 얼굴이 없고 새싹도
    // 반대쪽으로 갔다. 그 시안은 버튼이 셋인 iOS 기준이다.
    //
    // **안드로이드는 애플 버튼이 없어 버튼이 둘뿐이고, 그만큼 자리가 남아
    // 얼굴을 살린다.** 시안 프레임이 아직 없는 규칙이라 시험으로 못 박는다.
    tearDown(() => LoginScreen.debugPretendIos = null);

    testWidgets('애플 버튼이 있으면 얼굴을 빼서 부리가 버튼 사이로 안 나온다', (tester) async {
      LoginScreen.debugPretendIos = true;
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(svgWithAsset(AppAssets.splashCharLeft), findsNothing);
      expect(svgWithAsset(AppAssets.splashCharRight), findsNothing);
      expect(svgWithAsset(AppAssets.splashCenter), findsNothing);
    });

    testWidgets('애플 버튼이 없으면(안드로이드) 얼굴을 살린다', (tester) async {
      LoginScreen.debugPretendIos = false;
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(svgWithAsset(AppAssets.splashCharLeft), findsOneWidget);
      expect(svgWithAsset(AppAssets.splashCharRight), findsOneWidget);
      expect(svgWithAsset(AppAssets.splashCenter), findsOneWidget);
    });
  });

  testWidgets('버튼이 화면 밖으로 밀려나지 않는다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 그림 위에 겹쳐 얹는 구조라 버튼 묶음이 아래로 새면 마지막 버튼이 잘린다.
    // 애플은 iOS 전용이라 테스트 환경(호스트 OS)에서 마지막은 네이버다.
    final lastButton = tester.getRect(find.text('네이버로 로그인'));
    expect(lastButton.bottom, lessThan(tester.view.physicalSize.height));
  });
}
