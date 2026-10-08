import 'package:elum/core/router/app_router.dart';
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

  group('이룸이 휴대폰 + 세션 있음 → 보호자 경로는 이룸이 홈으로', () {
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

  group('이룸이 휴대폰이 갈 수 있는 곳은 그대로다', () {
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

    test('모드 전환을 이룸이 쪽으로 여는 것은 막지 않는다', () {
      expect(
        go(Routes.modeSwitch, modeSwitchTo: ModeSwitchTarget.child.name),
        Routes.modeSwitch,
      );
      expect(
        go(Routes.modeSwitch),
        Routes.modeSwitch,
        reason: 'to 가 없으면 이룸이 쪽으로 본다',
      );
    });
  });

  group('이룸이 휴대폰 + 세션 없음 → 막은 뒤에는 연결 화면이다 (로그인이 아니다)', () {
    test('보호자 홈', () {
      expect(go(Routes.guardian, hasSession: false), Routes.linkEnter);
    });
    test('보호자 설정', () {
      expect(go(Routes.guardianSettings, hasSession: false), Routes.linkEnter);
    });
  });

  group('보호자 휴대폰은 달라지지 않는다', () {
    test('보호자 화면 경로는 그대로 열린다', () {
      for (final path in [
        Routes.guardian,
        Routes.guardianSettings,
        Routes.guardianLinkStatus,
        Routes.linkCode,
      ]) {
        expect(go(path, elumi: false), path);
      }
    });

    test('모드 전환을 보호자 쪽으로 여는 것도 그대로다', () {
      expect(
        go(
          Routes.modeSwitch,
          elumi: false,
          modeSwitchTo: ModeSwitchTarget.guardian.name,
        ),
        Routes.modeSwitch,
      );
    });

    test('세션이 없으면 로그인으로 보낸다 (이룸이 휴대폰 규칙과 섞이지 않는다)', () {
      expect(
        go(Routes.guardian, elumi: false, hasSession: false),
        Routes.login,
      );
    });
  });

  group('연결 암호 넣기 아래에 깔 화면 (#212 · #542)', () {
    test('세션이 있으면 역할 선택 — 잘못 고른 사람이 돌아간다', () {
      expect(linkEnterBackTarget(hasSession: true), Routes.roleSelect);
    });

    test('세션이 없으면 로그인 — 역할 선택은 가드가 연결 화면으로 바꿔 갇힌다', () {
      expect(linkEnterBackTarget(hasSession: false), Routes.login);
      // 깔 화면이 가드에 걸려 다른 곳으로 바뀌면 안 된다
      expect(
        resolveRedirect(
          linkEnterBackTarget(hasSession: false),
          hasSession: false,
          onboardingCompleted: true,
          skipOnboarding: false,
          isElumiDevice: true,
        ),
        isNull,
      );
    });
  });
}
