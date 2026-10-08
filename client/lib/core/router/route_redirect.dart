import '../../features/child/presentation/mode_switch_screen.dart';
import 'routes.dart';

/// go_router 설정.
///
/// **redirect 규칙**: 토큰이 없으면 보호자·아동 화면에 들어갈 수 없다.
/// 토큰이 인증의 유일한 증거이므로 온보딩 완료 플래그만으로는 부족하다 —
/// 회원삭제로 토큰이 날아간 상태를 잡지 못한다.
///
/// 보호 화면에 토큰 없이 접근하면 **시작 화면**으로 되돌린다.

/// 보호자 휴대폰에서만 열리는 다중 보호자 화면의 경로.
const _guardianOnlyPaths = [
  Routes.guardianPeople,
  Routes.guardianProfileSwitch,
  Routes.inviteEnter,
];

/// 경로 가드. **순수 함수로 떼어 두었다** — 라우터를 위젯 트리에 올리지 않고도
/// 검증할 수 있어야 하기 때문이다.
///
/// 가입 절차(약관 동의 → 이룸이 정보)를 "온보딩 미완료면 이름 화면으로" 규칙에 함께 넣으면,
/// 절차를 밟는 도중에는 온보딩이 항상 미완료라 **어느 단계로 가든 이름 화면으로 되돌려진다.**
///
/// @return 이동시킬 경로. null이면 그대로 둔다.
String? resolveRedirect(
  String path, {
  required bool hasSession,
  required bool onboardingCompleted,
  required bool skipOnboarding,

  /// 이룸이(당사자) 휴대폰인가. 여기에는 로그인할 계정이 없다.
  bool isElumiDevice = false,

  /// 약관 동의 뒤 역할을 골랐는가.
  bool hasRole = true,

  /// 모드 전환 화면의 `to` 쿼리. 경로(`/mode-switch`)만으로는 어느 쪽으로 가는지 알 수 없다.
  String? modeSwitchTo,

  /// 방금 인증한 보호자가 이 휴대폰 잠금을 아직 만들지 않았는가.
  bool requiresGuardianPinSetup = false,
}) {
  // 잠금을 만들기 전에는 보호자 화면이 열리지 않는다 — 암호 만들기만 통과시킨다.
  if (requiresGuardianPinSetup &&
      hasSession &&
      !isElumiDevice &&
      path.startsWith(Routes.guardian) &&
      path != Routes.guardianPinChange) {
    return '${Routes.guardianPinChange}?from=login';
  }

  // 이룸이 휴대폰은 보호자 화면에 들어갈 수 없다 .
  //
  // 가장 먼저 본다 — 아래 규칙은 "세션이 있으면 열어 준다"라, 이룸이 휴대폰이 계정의 토큰을 들고
  // 있다는 이유로 보호자 홈이 열린다. 동물(톱니) 버튼을 숨기는 것과 별개로 여기서 최종으로 막는다.
  // 세션이 없으면 로그인이 아니라 연결 화면이다.
  if (isElumiDevice && _isGuardianOnly(path, modeSwitchTo)) {
    return hasSession ? Routes.child : Routes.linkEnter;
  }

  // 이룸이 휴대폰에서는 다중 보호자 기능(함께하는 사람·초대·이룸이 바꾸기)이 열리지 않는다.
  // 설정에 줄이 없어 화면으로 들어갈 길은 없지만, 딥링크나 구경로로 열려도 막는다 —
  // 이룸이 휴대폰 토큰은 서버도 403 으로 막으므로 열어 봐야 실패 화면만 본다.
  if (isElumiDevice && _guardianOnlyPaths.any(path.startsWith)) {
    // 세션이 없으면 이룸이 홈도 막히므로 한 번에 연결 화면으로
    return hasSession ? Routes.child : Routes.linkEnter;
  }

  // 가입 절차도 로그인이 있어야 한다. 계정이 없으면 동의를 기록할 곳도,
  // 아이 정보를 저장할 곳도 없다.
  final isSignUpFlow =
      path.startsWith(Routes.consent) ||
      path.startsWith(Routes.roleSelect) ||
      path.startsWith('/onboarding');
  final needsSession =
      isSignUpFlow ||
      path.startsWith(Routes.guardian) ||
      path.startsWith(Routes.child);
  if (!needsSession) return null;

  // 세션이 없으면 아무것도 조회할 수 없다. 다시 시작할 자리로 보낸다.
  //
  // 이룸이 휴대폰은 **로그인이 아니라 연결**로 붙는다. 로그인 화면으로 보내면
  // 소셜 버튼 세 개만 보이고 이룸이는 누를 것이 없다.
  if (!hasSession) return isElumiDevice ? Routes.linkEnter : Routes.login;

  // 가입 절차 안에서는 단계 이동을 막지 않는다.
  if (isSignUpFlow) return null;

  // devFlag: 온보딩 건너뛰기 (시연용)
  if (skipOnboarding) return null;

  // 역할을 고르지 않았으면 보호자·이룸이 어느 쪽 화면도 열지 않는다.
  // 딥링크나 구세션으로 곧장 홈에 들어오면 이룸이 휴대폰이 보호자 온보딩에
  // 빨려 들어간다.
  //
  // 두 경우는 예외다 — 연결에 성공한 휴대폰(역할 확정)과, **역할이 생기기 전에
  // 온보딩을 마친 기존 보호자**. 이미 답한 것을 다시 묻지 않는다.
  if (!hasRole && !isElumiDevice && !onboardingCompleted) {
    return Routes.roleSelect;
  }

  // 이룸이 휴대폰에는 온보딩이 없다(정보는 보호자 계정에 있다). 연결 직후 정보 조회가 실패해 `온보딩 완료`가
  // 비어 있어도 보호자 온보딩으로 보내면 안 된다.
  if (isElumiDevice) return null;

  // 보호자·아이 화면은 온보딩을 마쳐야 들어갈 수 있다.
  return onboardingCompleted ? null : Routes.onboardingName;
}

/// 보호자 휴대폰에서만 열리는 경로인가. 이룸이 휴대폰이 들어오면 막는다.

bool _isGuardianOnly(String path, String? modeSwitchTo) {
  if (path == Routes.guardian || path.startsWith('${Routes.guardian}/')) {
    return true;
  }
  // 모드 전환은 양방향이라 경로만으로는 모른다. 보호자 쪽으로 여는 것만 막는다.
  return path == Routes.modeSwitch &&
      ModeSwitchTarget.fromName(modeSwitchTo) == ModeSwitchTarget.guardian;
}
