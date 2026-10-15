import 'package:elum/core/app_status/app_status_repository.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';
import 'package:elum/core/router/routes.dart';

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

  Widget wrap({String? version}) {
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
      overrides: [
        testStorageOverride(),
        if (version != null)
          appVersionProvider.overrideWith((ref) async => version),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  // 로그인하지 못한 사용자는 설정에 갈 수 없다. 제보할 때 빌드를 확인할 곳은
  // 여기뿐이다 (#418).
  testWidgets('애플이 승인한 문구를 쓴다 (이슈 #237)', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 애플은 `Apple로 로그인`·`Apple로 계속하기`·`Apple로 가입` 셋만 허용한다.
    // 셋 중 하나에 카카오·네이버도 맞췄다 — 애플만 다르면 버튼이 어긋난다.
    expect(find.textContaining('로 시작하기'), findsNothing);
    expect(find.text('카카오로 로그인'), findsOneWidget);
    expect(find.text('네이버로 로그인'), findsOneWidget);
  });

  group('배치가 시안대로 갈린다 (이슈 #338)', () {
    tearDown(() => LoginScreen.debugPretendIos = null);

  });

  group('idle 부유 모션 (시작 화면에서 옮겨 옴 — 이슈 #338)', () {
    /// 줄기+구슬 부유 위젯 안의 Transform.translate 세로 offset을 읽는다.

  });

  /// 지난번에 카카오로 로그인한 상태를 만든다 — 그래야 안내 문구가 뜬다.

  group('최근 로그인 표시는 시안값을 따른다 (이슈 #346)', () {
    // 시안 `로그인_iOS`(238:1808) — 알약 91×28 · r20, 배경 #FFFADC 투명도 50%.
    // 버튼 우측에서 16 · 버튼 위로 10 겹친다.
    //
    // 겹쳐 놓는 것이 핵심이다. 이전 구현은 버튼 위에 한 줄을 깔아, 최근 로그인이
    // 있을 때만 버튼 묶음이 통째로 밀렸다 — 누르려던 자리가 움직인다.
  });

  group('병아리 얼굴은 애플 버튼 유무를 따른다 (이슈 #297)', () {
    // 시안(`238:1808`)은 병아리가 **뒤를 돌아본** 모습이라 얼굴이 없고 새싹도
    // 반대쪽으로 갔다. 그 시안은 버튼이 셋인 iOS 기준이다.
    //
    // **안드로이드는 애플 버튼이 없어 버튼이 둘뿐이고, 그만큼 자리가 남아
    // 얼굴을 살린다.** 시안 프레임이 아직 없는 규칙이라 시험으로 못 박는다.
    tearDown(() => LoginScreen.debugPretendIos = null);

  });

}
