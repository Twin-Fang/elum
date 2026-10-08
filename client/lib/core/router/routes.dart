/// 앱 라우트 경로 상수. 문자열을 화면마다 반복해 적지 않는다.
abstract final class Routes {
  static const splash = '/';

  /// 온보딩 맨 앞. 계정이 먼저 생기고 그 안에 당사자 프로필을 만든다.
  static const login = '/login';

  /// 약관 동의. 로그인 직후, 아이 정보를 받기 전에 선다.
  /// 동의 없이는 서비스를 쓸 수 없다.
  static const consent = '/consent';

  /// 약관 동의 뒤 보호자·이룸이가 갈라지는 지점 (명세 §4-3)
  static const roleSelect = '/role';

  static const onboardingName = '/onboarding/name';
  static const onboardingGoals = '/onboarding/goals';
  static const onboardingCharacter = '/onboarding/character';

  /// 카드 그림 방식. 캐릭터 다음, 비밀암호 앞. 건너뛸 수 있다.
  static const onboardingImageStyle = '/onboarding/image-style';
  static const onboardingPin = '/onboarding/pin';
  static const cardCompletion = '/onboarding/card-completion';

  static const guardian = '/guardian';

  /// 보호자 설정. 계정 정리(로그아웃·회원탈퇴)가 여기 있다.
  static const guardianSettings = '/guardian/settings';

  /// 임시저장 — 만들다 만 일과.
  static const guardianDrafts = '/guardian/settings/drafts';

  /// 비밀암호 변경. 시안이 없어 온보딩 비밀번호 화면 모양을 쓴다.
  static const guardianPinChange = '/guardian/settings/pin';

  /// 의견 보내기. 시안이 없어 임시 화면이다.
  static const guardianFeedback = '/guardian/settings/feedback';

  /// 그림 방식 선택. 시안이 없어 임시 화면이다.
  static const guardianImageStyle = '/guardian/settings/image-style';

  /// 함께하는 사람. 시안이 없어 임시 화면이다.
  static const guardianPeople = '/guardian/settings/people';

  /// 초대 코드 만들기. 시안이 없어 임시 화면이다.
  static const guardianInvite = '/guardian/settings/people/invite';

  /// 이룸이 바꾸기. 연결된 이룸이가 둘 이상일 때만 설정에 보인다. 임시 화면이다.
  static const guardianProfileSwitch = '/guardian/settings/profile';

  /// 초대 코드 넣기. **온보딩 아래에 둔 이유** — 새로 가입한 보호자는 이룸이 등록
  /// (온보딩)을 건너뛰고 들어오므로 온보딩을 마치기 전에도 열려야 한다. 이미 쓰는 보호자는
  /// 설정에서 들어온다. 임시 화면이다.
  static const inviteEnter = '/onboarding/invite';

  /// 이룸이 휴대폰 연결 상태·끊기 (명세 §8-5). 연결된 뒤에만 설정에서 들어온다.
  static const guardianLinkStatus = '/guardian/settings/link-status';
  static const routineInput = '/guardian/routine/input';

  /// DLP 마스킹 + 추가 질문 준비 로딩 (Figma 262:4569).
  /// 경로 이름은 DLP 시절 것을 유지한다 — 마스킹이 이 단계에서 일어나므로
  /// 의미가 어긋나지 않는다.
  static const routineMasking = '/guardian/routine/masking';
  static const routineQuestion = '/guardian/routine/question';

  /// 보상 정하기 — 일과 입력 **바로 다음**이다 (Figma 섹션 `1049:4654`).
  ///
  /// 시안 순서가 입력 → 보상 → 로딩 → 추가질문이다. 카드를 만든 뒤로 미루면
  /// "이미 다 끝났는데 왜 또"가 되므로 카드 생성 **전**이다. 건너뛸 수 있다.
  static const routineReward = '/guardian/routine/reward';

  /// 행동카드 생성 로딩 (Figma 262:4703).
  /// [routineMasking]과 화면은 같고 문구·진행률·다음 목적지가 다르다.
  static const routineGenerating = '/guardian/routine/generating';
  static const routineReview = '/guardian/routine/review';

  /// 연결 암호 만들기 (보호자). 온보딩 직후와 설정에서 들어온다.
  static const linkCode = '/guardian/link';

  /// 연결 암호 넣기 (이룸이 휴대폰). **로그인 전에 서는 화면이다.**
  static const linkEnter = '/link/enter';

  static const child = '/child';

  /// 일과 상세 — 카드 페이저 (Figma 309:3548). `extra`로 Routine을 넘긴다.
  static const childRoutineDetail = '/child/routine';

  /// 이룸이 휴대폰 설정 — 보호자 설정과 같은 페이지 모양
  static const childSettings = '/child/settings';

  /// 누적 별 (Figma 364:8219)
  static const childStars = '/child/stars';

  /// 아이 보상 (Figma 309:4055 등 3종 랜덤)
  static const childReward = '/child/reward';

  /// 일과를 다 끝냈을 때 한 번 뜨는 화면. 보상은 `extra`로 온다.
  static const childRoutineDone = '/child/routine-done';

  /// 모드 전환 PIN. `?to=child|guardian`으로 방향을 준다.
  static const modeSwitch = '/mode-switch';
}
