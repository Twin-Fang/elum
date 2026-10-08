import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/data/oauth_sdk.dart';
import 'package:elum/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/svg_finder.dart';

/// 로그인 화면을 큰 글꼴로 볼 때 (#342).
///
/// 상단 두 문구가 시안 y 에 **고정**돼 있어, 글자가 커지면 `오늘의 하루,` 아랫부분이
/// `차근차근 함께해요` 윗부분에 물렸다. 로고도 y 고정이라 같은 식으로 겹칠 수 있고,
/// `최근 로그인` 알약(91×28 고정)은 글자가 넘쳐 잘렸다.
///
/// **시안 값은 그대로다.** 글꼴 1.0 에서는 시안 좌표와 한 칸도 다르지 않아야 하고,
/// 글자가 커져 자리가 모자랄 때만 아래 것이 밀려 내려간다.
///
/// 앱은 글꼴 배율을 따로 제한하지 않는다(코드에 clamp 없음). 안드로이드 접근성 최대
/// 2.0, iOS 접근성 크기는 그 이상(약 3.1)까지 올라가므로 3.0 까지 본다.
void main() {
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
    LoginScreen.debugPretendIos = null;
  });

  Future<void> pump(
    WidgetTester tester, {
    required bool ios,
    required double scale,
    Size size = const Size(393, 852),
  }) async {
    final view = tester.view;
    view.devicePixelRatio = 1;
    view.physicalSize = size;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    LoginScreen.debugPretendIos = ios;
    // 지난번 로그인 수단이 있어야 `최근 로그인` 알약이 뜬다.
    final storage = InMemoryStorage();
    await storage.setLastLoginProvider(OAuthProvider.kakao.name);

    final router = GoRouter(
      initialLocation: Routes.login,
      routes: [
        GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageProvider.overrideWithValue(storage)],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) => MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Rect caption(WidgetTester t) => t.getRect(find.text('오늘의 하루,'));
  Rect title(WidgetTester t) => t.getRect(find.text('차근차근 함께해요'));
  Rect logo(WidgetTester t) => t.getRect(svgWithAsset(AppAssets.logo));

  // 시안 y — iOS 238:1808 · AOS 1022:4333
  const design = {
    true: (140.0, 168.0, 214.0),
    false: (103.7, 131.7, 177.7),
  };

  group('글꼴 1.0 은 시안 좌표 그대로다', () {
    for (final ios in [true, false]) {
      testWidgets('${ios ? 'iOS' : '안드로이드'} — 문구 둘과 로고 y', (tester) async {
        await pump(tester, ios: ios, scale: 1);
        final (c, t, l) = design[ios]!;

        expect(caption(tester).top, closeTo(c, 0.5));
        expect(title(tester).top, closeTo(t, 0.5));
        expect(logo(tester).top, closeTo(l, 0.5));
      });
    }
  });

  group('큰 글꼴에서 겹치지 않는다', () {
    for (final ios in [true, false]) {
      for (final size in const [Size(393, 852), Size(320, 640)]) {
        for (final scale in [1.3, 2.0, 3.0]) {
          testWidgets(
            '${ios ? 'iOS' : '안드로이드'} · ${size.width.toInt()} 폭 · 글꼴 $scale',
            (tester) async {
              await pump(tester, ios: ios, scale: scale, size: size);

              final c = caption(tester);
              final t = title(tester);
              final l = logo(tester);
              // 위 문구가 아래 문구를, 아래 문구가 로고를 침범하지 않는다.
              expect(c.bottom, lessThanOrEqualTo(t.top + 0.5), reason: '문구 둘이 겹친다');
              expect(t.bottom, lessThanOrEqualTo(l.top + 0.5), reason: '제목과 로고가 겹친다');
              // 시안 자리보다 위로 올라가지 않는다 — 큰 글꼴에서만 아래로 밀린다.
              // (시안 y 는 852 기준이라 화면 높이만큼 줄여 비교한다)
              final h = size.height / 852;
              expect(t.top, greaterThanOrEqualTo(design[ios]!.$2 * h - 0.5));
              expect(l.top, greaterThanOrEqualTo(design[ios]!.$3 * h - 0.5));
              // 글자가 화면 폭 안에 있다.
              expect(c.left, greaterThanOrEqualTo(0));
              expect(t.right, lessThanOrEqualTo(size.width + 0.5));
            },
          );
        }
      }
    }
  });

  group('최근 로그인 알약', () {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('글꼴 $scale — 글자가 알약 안에 들어오고 한 줄이다', (tester) async {
        await pump(tester, ios: false, scale: scale);

        final text = find.text('최근 로그인');
        final pill = find
            .ancestor(of: text, matching: find.byType(Container))
            .first;
        final pr = tester.getRect(pill);
        final tr = tester.getRect(text);

        // 가장자리에 닿는 것은 허용한다(Rect.contains 는 아래·오른쪽 끝을 뺀다).
        final inside = tr.left >= pr.left - 0.01 &&
            tr.top >= pr.top - 0.01 &&
            tr.right <= pr.right + 0.01 &&
            tr.bottom <= pr.bottom + 0.01;
        expect(inside, isTrue, reason: '글자가 알약 밖으로 넘친다 pill=$pr text=$tr');
        // 한 줄이다 — 12sp 글자 한 줄 높이의 두 배를 넘으면 줄바꿈이다.
        expect(tr.height, lessThan(12 * scale * 1.6));
        if (scale == 1.0) {
          expect(pr.width, closeTo(91, 0.5));
          expect(pr.height, closeTo(28, 0.5));
        }
      });
    }
  });

  group('제공자 버튼 문구가 로고에 붙지 않는다', () {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('글꼴 $scale', (tester) async {
        await pump(tester, ios: true, scale: scale);

        final kakao = tester.getRect(find.text('카카오로 로그인'));
        final icon = tester.getRect(svgWithAsset(AppAssets.loginKakao));
        // 로고(x=64~86) 오른쪽에서 문구가 시작하고 화면 밖으로 나가지 않는다.
        expect(kakao.left, greaterThanOrEqualTo(icon.right));
        expect(kakao.right, lessThanOrEqualTo(393 - 16 + 0.5));
      });
    }
  });
}
