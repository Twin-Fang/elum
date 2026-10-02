import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/router/app_destination.dart';
import 'package:flutter_test/flutter_test.dart';

/// 보호자 휴대폰이 이룸이 화면에 있던 채 꺼지면 다시 켰을 때도 이룸이 화면이다 (#532).
///
/// 보호자 홈을 열면 이룸이가 암호 없이 보호자 화면을 보게 된다.
void main() {
  String dest({
    bool hasSession = true,
    bool onboardingCompleted = true,
    bool isElumiDevice = false,
    String? selectedRole = 'guardian',
    bool resume = false,
  }) => resolveDestination(
    hasSession: hasSession,
    onboardingCompleted: onboardingCompleted,
    isElumiDevice: isElumiDevice,
    selectedRole: selectedRole,
    resumeOnElumiScreen: resume,
  );

  test('이룸이 화면에 있었으면 이룸이 화면으로 연다', () {
    expect(dest(resume: true), Routes.child);
  });

  test('보호자 화면에 있었으면 보호자 홈으로 연다', () {
    expect(dest(), Routes.guardian);
  });

  test('역할이 생기기 전에 가입한 보호자도 이룸이 화면을 되찾는다', () {
    expect(dest(selectedRole: null, resume: true), Routes.child);
  });

  test('세션이 없으면 기억한 화면보다 로그인이 먼저다', () {
    expect(dest(hasSession: false, resume: true), Routes.login);
  });

  test('온보딩을 마치지 않았으면 이룸이 화면을 열지 않는다', () {
    expect(
      dest(onboardingCompleted: false, resume: true),
      Routes.onboardingName,
    );
  });
}
