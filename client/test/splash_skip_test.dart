import 'package:flutter_test/flutter_test.dart';

import 'package:elum/features/onboarding/presentation/splash_screen.dart';

/// 로그인과 온보딩을 모두 마친 사용자는 시작 화면을 거치지 않는다.
/// 나머지 경우는 시작 화면이 그대로 떠야 한다 — 로그인 버튼이 있는 유일한 입구다.
void main() {
  test('세션이 있고 온보딩도 끝났으면 건너뛴다', () {
    expect(
      shouldSkipSplash(hasSession: true, onboardingCompleted: true),
      isTrue,
    );
  });

  test('세션이 없으면 머문다 — 로그인으로 갈 입구가 필요하다', () {
    expect(
      shouldSkipSplash(hasSession: false, onboardingCompleted: true),
      isFalse,
    );
  });

  test('온보딩이 안 끝났으면 머문다', () {
    expect(
      shouldSkipSplash(hasSession: true, onboardingCompleted: false),
      isFalse,
    );
  });

  test('둘 다 없으면 머문다 — 첫 실행', () {
    expect(
      shouldSkipSplash(hasSession: false, onboardingCompleted: false),
      isFalse,
    );
  });
}
