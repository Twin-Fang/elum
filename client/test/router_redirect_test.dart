import 'package:flutter_test/flutter_test.dart';
import 'package:elum/core/router/routes.dart';
import 'package:elum/core/router/route_redirect.dart';

/// 라우터 가드 테스트.
///
/// 이 테스트가 있는 이유 — 가입 절차(약관 동의 → 아이 정보)를 "온보딩 미완료면
/// 이름 화면으로" 규칙에 함께 넣었다가, **절차 도중에는 온보딩이 항상 미완료라
/// 어느 단계로 가든 이름 화면으로 되돌려지는** 사고가 있었다. 동의 화면이 통째로
/// 건너뛰어졌고 이름 입력 후 다음으로도 못 넘어갔다.
///
/// 화면 위젯을 띄우지 않고 `redirect` 결과만 본다. 가드는 경로 판단이 전부다.
void main() {
  /// 가드를 통과한 뒤의 도착지. null이면 요청한 경로 그대로다.
  String destination(
    String target, {
    required bool hasSession,
    required bool onboardingCompleted,
  }) =>
      resolveRedirect(
        target,
        hasSession: hasSession,
        onboardingCompleted: onboardingCompleted,
        skipOnboarding: false,
      ) ??
      target;

  group('세션이 없으면 로그인으로 보낸다', () {
    test('약관 동의도 계정이 있어야 한다 — 동의를 기록할 곳이 없다', () {
      expect(
        destination(Routes.consent, hasSession: false, onboardingCompleted: false),
        Routes.login,
      );
    });

  });

  group('가입 절차 안에서는 단계 이동을 막지 않는다', () {
  });

  group('온보딩을 마치지 않았으면 보호자·아이 화면은 막는다', () {
    test('보호자 홈 → 이름 화면', () {
      expect(
        destination(Routes.guardian, hasSession: true, onboardingCompleted: false),
        Routes.onboardingName,
      );
    });

  });

  group('세션이 없으면 이룸이 휴대폰도 로그인으로 되돌린다', () {
    String? go(String target, {required bool isElumi}) => resolveRedirect(
          target,
          hasSession: false,
          onboardingCompleted: true,
          skipOnboarding: false,
          isElumiDevice: isElumi,
        );

    test('이룸이 휴대폰 — 로그인으로', () {
      expect(go(Routes.child, isElumi: true), Routes.login);
    });

    test('연결 암호 넣기 화면도 로그인 없이는 열리지 않는다', () {
      // 로그인 없이 연결 암호만으로 이룸이 화면에 들어가는 길이 생긴다.
      expect(go(Routes.linkEnter, isElumi: false), Routes.login);
    });
  });

  group('휴대폰 잠금을 만들기 전에는 보호자 화면을 열지 않는다', () {
    String? go(String path, {bool elumi = false, bool pending = true}) =>
        resolveRedirect(
          path,
          hasSession: true,
          onboardingCompleted: true,
          skipOnboarding: false,
          isElumiDevice: elumi,
          requiresGuardianPinSetup: pending,
        );

    test('보호자 홈은 암호 만들기로 보낸다', () {
      expect(go(Routes.guardian), '${Routes.guardianPinChange}?from=login');
    });

  });
}
