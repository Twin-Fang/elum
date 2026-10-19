import 'package:elum/features/child/presentation/mode_switch_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elum/core/router/routes.dart';
import 'package:elum/core/router/route_redirect.dart';

/// 이룸이 휴대폰은 **보호자 화면 경로로 들어갈 수 없다** (#363 · #355 A 경로).
///
/// 동물(톱니) 버튼을 숨기는 것과 별개로 라우터가 최종으로 막는다 — 딥링크·옛 화면 스택·개발자
/// 도구로 `/guardian` 에 곧장 들어오는 길을 같이 닫는다. 서버가 권한을 최종 판단하는 것과 같은 이유다.
void main() {
  String go(
    String path, {
    bool elumi = true,
    bool hasSession = true,
    String? modeSwitchTo,
  }) =>
      resolveRedirect(
        path,
        hasSession: hasSession,
        onboardingCompleted: true,
        skipOnboarding: false,
        isElumiDevice: elumi,
        modeSwitchTo: modeSwitchTo,
      ) ??
      path;

  group('이룸이 기기 + 세션 있음 → 보호자 경로는 이룸이 홈으로', () {
    for (final path in [
      Routes.guardian,
      Routes.guardianSettings,
      Routes.guardianDrafts,
      Routes.guardianPinChange,
      Routes.guardianImageStyle,
      Routes.guardianFeedback,
      Routes.guardianLinkStatus,
      Routes.routineInput,
      Routes.routineReview,
      Routes.linkCode,
    ]) {
      test(path, () => expect(go(path), Routes.child));
    }

    test('모드 전환을 보호자 쪽으로 열면 막는다 (쿼리는 경로에 안 보여 따로 받는다)', () {
      expect(
        go(Routes.modeSwitch, modeSwitchTo: ModeSwitchTarget.guardian.name),
        Routes.child,
      );
    });
  });

  group('이룸이 기기가 갈 수 있는 곳은 그대로다', () {
    for (final path in [
      Routes.child,
      Routes.childRoutineDetail,
      Routes.childStars,
      Routes.childReward,
      Routes.linkEnter,
      Routes.splash,
    ]) {
      test(path, () => expect(go(path), path));
    }

  });

  group('이룸이 기기 + 세션 없음 → 로그인이다', () {
  });

  group('보호자 기기는 달라지지 않는다', () {
    test('세션이 없으면 로그인으로 보낸다 (이룸이 기기 규칙과 섞이지 않는다)', () {
      expect(
        go(Routes.guardian, elumi: false, hasSession: false),
        Routes.login,
      );
    });
  });

  group('연결 암호 넣기 아래에 깔 화면 (#212 · #542)', () {
  });
}
