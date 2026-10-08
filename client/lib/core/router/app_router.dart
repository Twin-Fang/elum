import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_context.dart';
import '../config/app_config.dart';
import '../../features/guardian/presentation/card_review_screen.dart';
import '../../features/guardian/presentation/guardian_home_screen.dart';
import '../../features/guardian/presentation/draft_routines_screen.dart';
import '../../features/guardian/presentation/guardian_settings_screen.dart';
import '../../features/guardian/presentation/image_style_settings_screen.dart';
import '../../features/guardian/presentation/pin_change_screen.dart';
import '../../features/link/presentation/link_code_screen.dart';
import '../../features/profile/domain/invite_link.dart';
import '../../features/profile/presentation/guardians_screen.dart';
import '../../features/profile/presentation/invite_code_screen.dart';
import '../../features/profile/presentation/invite_enter_screen.dart';
import '../../features/profile/presentation/profile_switch_screen.dart';
import '../../features/link/presentation/link_enter_screen.dart';
import '../../features/link/presentation/link_status_screen.dart';
import '../../features/child/presentation/child_home_screen.dart';
import '../../features/child/presentation/child_routine_detail_screen.dart';
import '../../features/child/presentation/child_stars_screen.dart';
import '../../features/link/presentation/elumi_settings_screen.dart';
import '../../features/child/presentation/mode_switch_screen.dart';
import '../../features/child/presentation/reward_screen.dart';
import '../../features/child/presentation/routine_done_screen.dart';
import '../../shared/models/routine.dart';
import '../../features/guardian/domain/routine_stage.dart';
import '../../features/guardian/presentation/routine_loading_screen.dart';
import '../../features/guardian/presentation/question_screen.dart';
import '../../features/guardian/presentation/reward_setup_screen.dart';
import '../../features/guardian/presentation/routine_input_screen.dart';
import '../../features/guardian/presentation/widgets/aurora_background.dart';
import '../../features/guardian/presentation/widgets/routine_flow_backdrop.dart';
import '../../features/onboarding/presentation/card_completion_screen.dart';
import '../../features/onboarding/presentation/character_screen.dart';
import '../../features/onboarding/presentation/image_style_screen.dart';
import '../../features/onboarding/presentation/goals_screen.dart';
import '../../features/onboarding/presentation/name_screen.dart';
import '../../features/onboarding/presentation/pin_screen.dart';
import '../../features/auth/presentation/consent_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/role_select_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/notice/presentation/guardian_notice_launcher.dart';
import 'app_transitions.dart';

/// 앱 라우트 경로 상수. 문자열을 화면마다 반복해 적지 않는다.
abstract final class Routes {
  static const splash = '/';

  /// 온보딩 맨 앞. 계정이 먼저 생기고 그 안에 당사자 프로필을 만든다.
  static const login = '/login';

  /// 약관 동의. 로그인 직후, 아이 정보를 받기 전에 선다.
  /// 동의 없이는 서비스를 쓸 수 없다.
  static const consent = '/consent';

  /// 약관 동의 뒤 보호자·이룸이가 갈라지는 지점 (이슈 #212 · 명세 §4-3)
  static const roleSelect = '/role';

  static const onboardingName = '/onboarding/name';
  static const onboardingGoals = '/onboarding/goals';
  static const onboardingCharacter = '/onboarding/character';

  /// 카드 그림 방식 (#458). 캐릭터 다음, 비밀암호 앞. 건너뛸 수 있다.
  static const onboardingImageStyle = '/onboarding/image-style';
  static const onboardingPin = '/onboarding/pin';
  static const cardCompletion = '/onboarding/card-completion';

  static const guardian = '/guardian';

  /// 보호자 설정. 계정 정리(로그아웃·회원탈퇴)가 여기 있다 (#181).
  static const guardianSettings = '/guardian/settings';

  /// 임시저장 — 만들다 만 일과 (#349).
  static const guardianDrafts = '/guardian/settings/drafts';

  /// 비밀암호 변경 (#437). 시안이 없어 온보딩 비밀번호 화면 모양을 쓴다 (#438).
  static const guardianPinChange = '/guardian/settings/pin';

  /// 그림 방식 선택 (#458). 시안이 없어 임시 화면이다.
  static const guardianImageStyle = '/guardian/settings/image-style';

  /// 함께하는 사람 (다중 보호자 #362). 시안이 없어 임시 화면이다.
  static const guardianPeople = '/guardian/settings/people';

  /// 초대 코드 만들기 (#362). 시안이 없어 임시 화면이다.
  static const guardianInvite = '/guardian/settings/people/invite';

  /// 이룸이 바꾸기 (#362). 연결된 이룸이가 둘 이상일 때만 설정에 보인다. 임시 화면이다.
  static const guardianProfileSwitch = '/guardian/settings/profile';

  /// 초대 코드 넣기 (#362). **온보딩 아래에 둔 이유** — 새로 가입한 보호자는 이룸이 등록
  /// (온보딩)을 건너뛰고 들어오므로 온보딩을 마치기 전에도 열려야 한다. 이미 쓰는 보호자는
  /// 설정에서 들어온다. 임시 화면이다.
  static const inviteEnter = '/onboarding/invite';

  /// 이룸이 휴대폰 연결 상태·끊기 (#363 · 명세 §8-5). 연결된 뒤에만 설정에서 들어온다.
  static const guardianLinkStatus = '/guardian/settings/link-status';
  static const routineInput = '/guardian/routine/input';

  /// DLP 마스킹 + 추가 질문 준비 로딩 (Figma 262:4569).
  /// 경로 이름은 DLP 시절 것을 유지한다 — 마스킹이 이 단계에서 일어나므로
  /// 의미가 어긋나지 않는다.
  static const routineMasking = '/guardian/routine/masking';
  static const routineQuestion = '/guardian/routine/question';

  /// 행동카드 생성 로딩 (Figma 262:4703).
  /// [routineMasking]과 화면은 같고 문구·진행률·다음 목적지가 다르다.
  /// 보상 정하기 — 일과 입력 **바로 다음**이다 (Figma 섹션 `1049:4654` · #380 결정 1).
  ///
  /// 처음(#239)에는 AI 질문 다음이었다. 시안이 입력 → 보상 → 로딩 → 추가질문으로
  /// 놓아 옮겼다. 카드를 만든 뒤로 미루면 "이미 다 끝났는데 왜 또"가 되는 것은
  /// 그대로라 카드 생성 **전**이다. 건너뛸 수 있다.
  static const routineReward = '/guardian/routine/reward';
  static const routineGenerating = '/guardian/routine/generating';
  static const routineReview = '/guardian/routine/review';

  /// 연결 암호 만들기 (보호자). 온보딩 직후와 설정에서 들어온다 (이슈 #205).
  static const linkCode = '/guardian/link';

  /// 연결 암호 넣기 (이룸이 휴대폰). **로그인 전에 서는 화면이다.**
  static const linkEnter = '/link/enter';

  static const child = '/child';

  /// 일과 상세 — 카드 페이저 (Figma 309:3548). `extra`로 Routine을 넘긴다.
  static const childRoutineDetail = '/child/routine';

  /// 이룸이 휴대폰 설정 — 보호자 설정과 같은 페이지 모양 (#488)
  static const childSettings = '/child/settings';

  /// 누적 별 (Figma 364:8219)
  static const childStars = '/child/stars';

  /// 아이 보상 (Figma 309:4055 등 3종 랜덤)
  static const childReward = '/child/reward';

  /// 일과를 다 끝냈을 때 한 번 뜨는 화면 (이슈 #490). 보상은 `extra`로 온다.
  static const childRoutineDone = '/child/routine-done';

  /// 모드 전환 PIN. `?to=child|guardian`으로 방향을 준다.
  static const modeSwitch = '/mode-switch';
}

/// go_router 설정.
///
/// **redirect 규칙**: 토큰이 없으면 보호자·아동 화면에 들어갈 수 없다.
/// 토큰이 인증의 유일한 증거이므로 온보딩 완료 플래그만으로는 부족하다 —
/// 회원삭제로 토큰이 날아간 상태를 잡지 못한다. (이슈 #19)
///
/// 보호 화면에 토큰 없이 접근하면 **시작 화면**으로 되돌린다.

/// 보호자 휴대폰에서만 열리는 다중 보호자 화면의 경로 (#362).
const _guardianOnlyPaths = [
  Routes.guardianPeople,
  Routes.guardianProfileSwitch,
  Routes.inviteEnter,
];

/// 경로 가드. **순수 함수로 떼어 두었다** — 라우터를 위젯 트리에 올리지 않고도
/// 검증할 수 있어야 하기 때문이다.
///
/// 실제로 이 판단을 `createRouter` 안에 두었을 때, 가입 절차(약관 동의 → 아이 정보)를
/// "온보딩 미완료면 이름 화면으로" 규칙에 함께 넣는 사고가 났다. 절차를 밟는 도중에는
/// 온보딩이 항상 미완료라 **어느 단계로 가든 이름 화면으로 되돌려졌다.**
/// 동의 화면이 통째로 건너뛰어졌고 이름 입력 후 다음으로도 넘어가지 못했다.
///
/// @return 이동시킬 경로. null이면 그대로 둔다.
@visibleForTesting
String? resolveRedirect(
  String path, {
  required bool hasSession,
  required bool onboardingCompleted,
  required bool skipOnboarding,

  /// 이룸이(당사자) 휴대폰인가. 여기에는 로그인할 계정이 없다 (이슈 #206).
  bool isElumiDevice = false,

  /// 약관 동의 뒤 역할을 골랐는가 (이슈 #212).
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

  // 이룸이 휴대폰은 보호자 화면에 들어갈 수 없다 (#363 · #355 A 경로).
  //
  // 가장 먼저 본다 — 아래 규칙은 "세션이 있으면 열어 준다"라, 이룸이 휴대폰이 계정의 토큰을 들고
  // 있다는 이유로 보호자 홈이 열렸다. 동물(톱니) 버튼을 숨기는 것과 별개로 여기서 최종으로 막는다.
  // 세션이 없으면 로그인이 아니라 연결 화면이다 (이슈 #206).
  if (isElumiDevice && _isGuardianOnly(path, modeSwitchTo)) {
    return hasSession ? Routes.child : Routes.linkEnter;
  }

  // 이룸이 휴대폰에서는 다중 보호자 기능(함께하는 사람·초대·이룸이 바꾸기)이 열리지 않는다 (#362).
  // 설정에 줄이 없어 화면으로 들어갈 길은 없지만, 딥링크나 옛 경로로 열려도 막는다 —
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

  // 역할을 고르지 않았으면 보호자·이룸이 어느 쪽 화면도 열지 않는다 (이슈 #212).
  // 딥링크나 옛 세션으로 곧장 홈에 들어오면 이룸이 휴대폰이 보호자 온보딩에
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

/// 연결 암호 넣기 화면 아래에 깔아 둘 화면 — **뒤로가기의 도착지**다 (이슈 #212 · #542).
///
/// 세션이 있으면 역할 선택(잘못 고른 사람이 돌아간다), 없으면 로그인이다. 역할 선택은 세션이 있어야
/// 열리는 화면이라, 세션 없이 깔면 가드가 연결 화면으로 바꿔 스택이 `[연결, 연결]`이 된다 — 뒤로가기가
/// 같은 화면만 다시 보여 주고 빠져나갈 길이 없었다 (#542).
String linkEnterBackTarget({required bool hasSession}) =>
    hasSession ? Routes.roleSelect : Routes.login;

/// 연결 암호 넣기 화면으로 보낸다 — 앱을 켰을 때·세션이 끝난 뒤 공통 도착지다 (#206 흐름).
///
/// go 로 바로 띄우면 스택이 비어 뒤로 갈 수 없으므로 [linkEnterBackTarget] 을 깔고 그 위에 얹는다.
void goToLinkEnter(GoRouter router, {required bool hasSession}) {
  router.go(linkEnterBackTarget(hasSession: hasSession));
  router.push(Routes.linkEnter);
}

/// 일과 만들기 흐름에서 [path] 화면이 까는 배경 색 (#380).
///
/// 흐름 배경은 라우터가 **맨 위 화면의 위치**로 정한다. 화면이 스스로 알리게
/// 하면 한 프레임 늦어 넘어가는 첫 프레임에 앞 색이 남는다. 색 자체는 화면이
/// 선언한 값을 그대로 가져온다 — 두 곳에 따로 적으면 어긋난다.
AuroraTone routineFlowToneOf(String path) => switch (path) {
  Routes.routineInput => RoutineInputScreen.aurora,
  Routes.routineReward => RewardSetupScreen.aurora,
  Routes.routineMasking => RoutineLoadingScreen.auroraOf(
    RoutineLoadingKind.prepare,
  ),
  Routes.routineQuestion => QuestionScreen.aurora,
  Routes.routineGenerating => RoutineLoadingScreen.auroraOf(
    RoutineLoadingKind.generate,
  ),
  Routes.routineReview => CardReviewScreen.aurora,
  _ => RoutineInputScreen.aurora,
};

/// 초대 링크가 열렸을 때 라우터가 **어디에 머물 것인가** (#365).
///
/// 링크는 화면 경로가 아니다. 주소(`elum://invite?...`)를 그대로 라우트로 풀면 일치하는 화면이
/// 없어 오류 화면이 뜨고, 앱이 막 켜졌다면 로그인·온보딩 상태도 모르는 채 입력 화면을 열게 된다.
/// 그래서 링크는 [InviteInbox](우편함)에 맡기고 라우터는 **자리를 바꾸지 않는다.**
///
/// - 앱이 켜져 있었다면([currentLocation]) 보던 화면 그대로 — 하던 일을 잃지 않는다.
/// - 막 켜졌다면(null) 시작 화면 — 시작 화면이 로그인·역할·온보딩 상태를 보고 갈 곳을 정한다.
///
/// 입력 화면은 우편함을 지켜보던 쪽(`ElumApp`)이 알맞은 자리에서 연다.
@visibleForTesting
String resolveInviteLinkLocation({String? currentLocation}) =>
    (currentLocation == null || currentLocation.isEmpty)
    ? Routes.splash
    : currentLocation;

/// 온보딩 단계 사이의 진행은 각 화면 CTA가 막으므로 여기서 관여하지 않는다.
///
/// 콜백을 넘기지 않으면 가드가 비활성화된다(테스트용).
///
/// [onInviteLink] — 초대 링크(`InviteLink`)가 열렸을 때 불린다 (#365). 이룸이 휴대폰에서 열린 링크는
/// 부르지 않고 무시한다 (이룸이 휴대폰은 초대를 받을 수 없다). 코드는 로그에 남기지 않는다.
GoRouter createRouter({
  bool Function()? isOnboardingCompleted,
  bool Function()? hasToken,
  bool Function()? isElumiDevice,
  bool Function()? hasRole,
  bool Function()? requiresGuardianPinSetup,
  void Function(InviteLink link)? onInviteLink,
}) {
  // 리다이렉트가 라우터 자신의 현재 위치를 알아야 한다 — 만들어진 뒤에 채운다.
  late final GoRouter router;
  router = GoRouter(
    initialLocation: Routes.splash,
    redirect: (context, state) {
      // 초대 링크는 다른 가드보다 먼저 본다. 주소가 우리 라우트가 아니라 아래 규칙이 그대로 두면
      // 오류 화면이 된다.
      final link = InviteLink.parse(state.uri);
      if (link != null) {
        if (!(isElumiDevice?.call() ?? false)) onInviteLink?.call(link);
        // 막 켜졌다면 아직 위치가 없어 빈 문자열이다
        return resolveInviteLinkLocation(
          currentLocation: router.routerDelegate.currentConfiguration.uri.toString(),
        );
      }
      return resolveRedirect(
        state.matchedLocation,
        hasSession: hasToken?.call() ?? true,
        onboardingCompleted: isOnboardingCompleted?.call() ?? true,
        skipOnboarding: AppConfig.skipOnboarding,
        isElumiDevice: isElumiDevice?.call() ?? false,
        hasRole: hasRole?.call() ?? true,
        modeSwitchTo: state.uri.queryParameters['to'],
        requiresGuardianPinSetup: requiresGuardianPinSetup?.call() ?? false,
      );
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // --- 로그인 ---
      // **fade를 쓴다. 슬라이드를 쓰면 글자가 두 번 보인다** (이슈 #207).
      //
      // 시작 화면과 로그인 화면은 같은 그림([SplashScene])을 그린다. 수평
      // 슬라이드는 나가는 화면과 들어오는 화면을 가로로 어긋나게 겹치므로,
      // 그림이 같으면 `차근차근 함께해요`·로고·병아리가 통째로 이중으로 찍힌다.
      // fade는 같은 그림끼리 겹쳐도 차이가 보이지 않아, 버튼만 떠오르는 것처럼
      // 읽힌다 — `시작하기`를 없애 두 화면을 하나로 만든 의도와 맞는다.
      GoRoute(
        path: Routes.login,
        pageBuilder: (context, state) => fadePage(state, const LoginScreen()),
      ),

      GoRoute(
        path: Routes.consent,
        pageBuilder: (context, state) =>
            slidePage(state, const ConsentScreen()),
      ),
      GoRoute(
        path: Routes.roleSelect,
        pageBuilder: (context, state) =>
            slidePage(state, const RoleSelectScreen()),
      ),

      // --- 온보딩 ---
      // 단계 진행은 수평 슬라이드 — 즉시 교체는 motion.md 금지 사항이다.
      GoRoute(
        path: Routes.onboardingName,
        pageBuilder: (context, state) => slidePage(state, const NameScreen()),
      ),
      GoRoute(
        path: Routes.onboardingGoals,
        pageBuilder: (context, state) => slidePage(state, const GoalsScreen()),
      ),
      GoRoute(
        path: Routes.onboardingCharacter,
        pageBuilder: (context, state) =>
            slidePage(state, const CharacterScreen()),
      ),
      // 초대 코드 넣기 — 새로 가입한 보호자가 이룸이 등록 대신 들어온다 (#362 · E6).
      GoRoute(
        path: Routes.inviteEnter,
        pageBuilder: (context, state) =>
            slidePage(state, const InviteEnterScreen()),
      ),
      GoRoute(
        path: Routes.onboardingImageStyle,
        pageBuilder: (context, state) =>
            slidePage(state, const ImageStyleScreen()),
      ),
      GoRoute(
        path: Routes.onboardingPin,
        pageBuilder: (context, state) => slidePage(state, const PinScreen()),
      ),
      GoRoute(
        path: Routes.cardCompletion,
        builder: (context, state) => const CardCompletionScreen(),
      ),

      // --- 보호자 모드 ---
      // 온보딩 완료 → 홈은 맥락 전환이라 fade (motion.md "시작 화면 → 홈" 준용).
      // 다른 경로에서 홈으로 올 때도 fade가 걸리는데, 즉시 교체보다 나으므로 허용.
      GoRoute(
        path: Routes.guardian,
        // 공지 팝업은 **이 자리에서만** 뜬다 (이슈 #371). 이룸이 화면·일과 만들기에는
        // 감싸지 않는다 — 이룸이 화면은 한 화면에 행동 하나다 (#281 과 같은 판단).
        pageBuilder: (context, state) => fadePage(
          state,
          const GuardianNoticeLauncher(child: GuardianHomeScreen()),
        ),
      ),
      GoRoute(
        path: Routes.linkCode,
        pageBuilder: (context, state) => slidePage(
          state,
          LinkCodeScreen(
            // 온보딩에서 들어왔을 때만 `나중에 할게요`를 보여준다.
            fromOnboarding: state.uri.queryParameters['from'] == 'onboarding',
          ),
        ),
      ),
      GoRoute(
        path: Routes.linkEnter,
        pageBuilder: (context, state) =>
            slidePage(state, const LinkEnterScreen()),
      ),
      GoRoute(
        path: Routes.guardianSettings,
        pageBuilder: (context, state) =>
            slidePage(state, const GuardianSettingsScreen()),
      ),
      GoRoute(
        path: Routes.guardianDrafts,
        builder: (context, state) => const DraftRoutinesScreen(),
      ),
      GoRoute(
        path: Routes.guardianImageStyle,
        pageBuilder: (context, state) =>
            slidePage(state, const ImageStyleSettingsScreen()),
      ),
      // 다중 보호자 (#362) — 시안이 없는 임시 화면들이다.
      GoRoute(
        path: Routes.guardianPeople,
        pageBuilder: (context, state) =>
            slidePage(state, const GuardiansScreen()),
      ),
      GoRoute(
        path: Routes.guardianInvite,
        pageBuilder: (context, state) =>
            slidePage(state, const InviteCodeScreen()),
      ),
      GoRoute(
        path: Routes.guardianProfileSwitch,
        pageBuilder: (context, state) =>
            slidePage(state, const ProfileSwitchScreen()),
      ),
      GoRoute(
        path: Routes.guardianLinkStatus,
        pageBuilder: (context, state) =>
            slidePage(state, const LinkStatusScreen()),
      ),
      GoRoute(
        path: Routes.guardianPinChange,
        pageBuilder: (context, state) => slidePage(
          state,
          // 암호가 없는 휴대폰이 보호자 화면에 들어올 때 거치는 길이다 (#355)
          PinChangeScreen(
            createOnly:
                state.uri.queryParameters['from'] == 'login',
          ),
        ),
      ),
      // --- 일과 만들기 흐름 ---
      // 흐름 전체가 **배경 하나**를 함께 쓴다 (#380). 화면이 바뀌면 글자만 넘어가고
      // 배경은 그 자리에서 다음 화면 색으로 번진다. 화면마다 배경을 그리면 색이
      // 다른 화면(보상 — 분홍)이 경계선째 밀려 들어온다.
      //
      // 흐름 바깥에서 들어올 때는 흐름 전체가 한 장으로 미끄러져 들어온다.
      // **iOS 뒤로 밀기가 흐름을 통째로 닫지 않게** 전환 페이지로 둔다 — 플랫폼
      // 기본 페이지면 안쪽 화면의 나가기 확인(#242 · #387)을 건너뛴다.
      ShellRoute(
        pageBuilder: (context, state, child) => slidePage(
          state,
          RoutineFlowBackdrop(
            tone: routineFlowToneOf(state.uri.path),
            child: child,
          ),
        ),
        routes: [
          GoRoute(
            path: Routes.routineInput,
            pageBuilder: (context, state) =>
                flowPage(state, const RoutineInputScreen()),
          ),
          GoRoute(
            path: Routes.routineMasking,
            pageBuilder: (context, state) => flowPage(
              state,
              const RoutineLoadingScreen(kind: RoutineLoadingKind.prepare),
            ),
          ),
          GoRoute(
            path: Routes.routineQuestion,
            pageBuilder: (context, state) =>
                flowPage(state, const QuestionScreen()),
          ),
          GoRoute(
            path: Routes.routineReward,
            // `extra: true`면 카드 검토에서 고치러 온 것이다 (이슈 #239).
            pageBuilder: (context, state) => flowPage(
              state,
              RewardSetupScreen(fromReview: state.extra == true),
            ),
          ),
          GoRoute(
            path: Routes.routineGenerating,
            pageBuilder: (context, state) => flowPage(
              state,
              const RoutineLoadingScreen(kind: RoutineLoadingKind.generate),
            ),
          ),
          GoRoute(
            path: Routes.routineReview,
            pageBuilder: (context, state) =>
                flowPage(state, const CardReviewScreen()),
          ),
        ],
      ),

      // --- 아동 모드 ---
      GoRoute(
        path: Routes.child,
        builder: (context, state) => const ChildHomeScreen(),
      ),
      GoRoute(
        path: Routes.childRoutineDetail,
        builder: (context, state) {
          // extra 없이 들어오면(딥링크 등) 보여줄 일과가 없다 — 홈으로 돌린다.
          final routine = state.extra;
          if (routine is! Routine) return const ChildHomeScreen();
          return ChildRoutineDetailScreen(routine: routine);
        },
      ),
      // 어두운 밤하늘 배경이라 옆에서 밀려드는 슬라이드가 부자연스럽다.
      // fade로 쓱 나타나게 한다 (이슈 #107).
      GoRoute(
        path: Routes.childSettings,
        pageBuilder: (context, state) =>
            slidePage(state, const ElumiSettingsScreen()),
      ),
      GoRoute(
        path: Routes.childStars,
        pageBuilder: (context, state) =>
            fadePage(state, const ChildStarsScreen()),
      ),
      GoRoute(
        path: Routes.childReward,
        // 보상은 `extra`로 온다 (이슈 #239). 개발자 도구로 직접 들어오면 null이라
        // 별 연출만 돈다 — 그 자체가 보상 없이 끝낸 모습이라 맞다.
        pageBuilder: (context, state) => fadePage(
          state,
          RewardScreen(
            reward: state.extra is ({String emoji, String text})
                ? state.extra! as ({String emoji, String text})
                : null,
          ),
        ),
      ),
      GoRoute(
        path: Routes.childRoutineDone,
        // 보상은 `extra`로 온다. 없으면(개발자 도구로 직접 들어온 경우 포함) 칩 없이 그린다.
        pageBuilder: (context, state) => fadePage(
          state,
          RoutineDoneScreen(
            reward: state.extra is ({String emoji, String text})
                ? state.extra! as ({String emoji, String text})
                : null,
          ),
        ),
      ),
      GoRoute(
        path: Routes.modeSwitch,
        builder: (context, state) => ModeSwitchScreen(
          target: ModeSwitchTarget.fromName(state.uri.queryParameters['to']),
        ),
      ),
    ],
    // 잘못된 경로로 들어와도 앱이 죽지 않는다 — 발표 중 치명적이다
    errorBuilder: (context, state) =>
        _Placeholder(context.l10n.commonScreenNotFound),
  );
  return router;
}

/// 아직 구현하지 않은 화면. 라우트 구조를 먼저 고정해두기 위한 자리표시자다.
class _Placeholder extends StatelessWidget {
  const _Placeholder(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(label, style: Theme.of(context).textTheme.headlineMedium),
      ),
    );
  }
}
