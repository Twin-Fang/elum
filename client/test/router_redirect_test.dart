import 'package:elum/core/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

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
    test('보호자 홈', () {
      expect(
        destination(Routes.guardian, hasSession: false, onboardingCompleted: true),
        Routes.login,
      );
    });

    test('약관 동의도 계정이 있어야 한다 — 동의를 기록할 곳이 없다', () {
      expect(
        destination(Routes.consent, hasSession: false, onboardingCompleted: false),
        Routes.login,
      );
    });

    test('아이 정보 입력도 마찬가지다', () {
      expect(
        destination(Routes.onboardingName, hasSession: false, onboardingCompleted: false),
        Routes.login,
      );
    });
  });

  group('가입 절차 안에서는 단계 이동을 막지 않는다', () {
    test('약관 동의 화면이 이름 화면으로 튕기지 않는다', () {
      // 로그인 직후에는 온보딩이 당연히 미완료다. 그 이유로 동의 화면을
      // 건너뛰면 약관을 받지 못한 채 서비스가 열린다.
      expect(
        destination(Routes.consent, hasSession: true, onboardingCompleted: false),
        Routes.consent,
      );
    });

    test('이름 다음 단계로 넘어갈 수 있다', () {
      expect(
        destination(Routes.onboardingGoals, hasSession: true, onboardingCompleted: false),
        Routes.onboardingGoals,
      );
    });

    test('캐릭터·PIN 단계도 그대로 간다', () {
      for (final step in [Routes.onboardingCharacter, Routes.onboardingPin]) {
        expect(
          destination(step, hasSession: true, onboardingCompleted: false),
          step,
        );
      }
    });
  });

  group('온보딩을 마치지 않았으면 보호자·아이 화면은 막는다', () {
    test('보호자 홈 → 이름 화면', () {
      expect(
        destination(Routes.guardian, hasSession: true, onboardingCompleted: false),
        Routes.onboardingName,
      );
    });

    test('아이 화면 → 이름 화면', () {
      expect(
        destination(Routes.child, hasSession: true, onboardingCompleted: false),
        Routes.onboardingName,
      );
    });

    test('마쳤으면 그대로 들어간다', () {
      expect(
        destination(Routes.guardian, hasSession: true, onboardingCompleted: true),
        Routes.guardian,
      );
    });
  });

  test('시작 화면은 세션과 무관하게 열린다', () {
    expect(
      destination(Routes.splash, hasSession: false, onboardingCompleted: false),
      Routes.splash,
    );
  });
}
