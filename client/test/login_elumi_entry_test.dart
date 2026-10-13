import 'package:elum/core/router/app_destination.dart';
import 'package:elum/core/router/routes.dart';
import 'package:flutter_test/flutter_test.dart';

/// 로그인 화면의 `이룸이 휴대폰이에요` 입구로 연결한 휴대폰이 제 홈을 찾는다.
/// 가드 통과는 router_invariants_test 의 전수 검사가 덮는다.
void main() {
  test('로그인 없이 연결에 성공한 휴대폰(표식 켜짐 · 역할 없음 · 온보딩 없음)은 이룸이 홈으로 간다', () {
    expect(
      resolveDestination(
        hasSession: true,
        onboardingCompleted: false,
        isElumiDevice: true,
        selectedRole: null,
      ),
      Routes.child,
    );
  });

  test('연결이 끊긴 이룸이 휴대폰은 앱을 다시 켜도 로그인이 아니라 연결 암호 화면이다', () {
    expect(
      resolveDestination(
        hasSession: false,
        onboardingCompleted: false,
        isElumiDevice: true,
        selectedRole: null,
      ),
      Routes.linkEnter,
    );
  });
}
