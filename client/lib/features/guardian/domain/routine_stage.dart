/// 로딩 화면 종류.
///
/// Figma에 `보호자_새로운 일과 만들기_로딩` 프레임이 **둘** 있다. 이름이 같아
/// 하나로 착각하기 쉽지만 문구·진행률·배경색이 전부 다르고, 흐름에서 놓이는
/// 자리도 다르다.
///
/// ```
/// 입력 → [prepare] 262:4569 → 추가질문 → [generate] 262:4703 → 카드확인
/// ```
///
/// [prepare]의 마지막 단계가 "추가 질문을 생각하고 있어요"인 것이 근거다.
/// 이 화면 다음에 질문 화면이 온다는 뜻이므로, 카드 생성 로딩일 수 없다.
///
/// ⚠️ **문구는 렌더된 PNG로 확인한다.** JSON 덤프에는 화면에 그려지지 않는
/// 레이어(262:4678 `아이가 이해하기 쉬운 말로 바꿔요` 등)까지 섞여 나온다.
/// 덤프만 보고 고치면 멀쩡한 문구를 틀린 값으로 바꾸게 된다.
enum RoutineLoadingKind {
  /// 262:4569 — 추가 질문 준비
  ///
  /// 첫 줄은 시안(`이룸이를 알아볼 수 있는 정보는 가려요`)과 다르다. AI DLP 를 꺼서(#377)
  /// 입력이 가공 없이 AI 로 가므로 사실이 아닌 개인정보 안내가 됐다. 2026-09-23 사용자 승인으로
  /// 바꿨고 디자이너에게 시안 반영을 요청했다(#383). 뒤 화면 첫 줄 `…읽고 있어요` 와 동사가
  /// 겹치지 않게 `살펴보고` 로 골랐다.
  prepare(
    title: '루미가 내용을\n정리하고 있어요',
    lumiSide: LumiSide.left,
    stages: [
      RoutineStage(label: '적어 주신 상황을 살펴보고 있어요', percent: 15, hold: _holdLong),
      RoutineStage(label: '꼭 필요한 내용만 정리해요', percent: 40, hold: _holdShort),
      RoutineStage(label: '추가 질문을 생각하고 있어요', percent: 65, hold: _holdLong),
    ],
  ),

  /// 262:4703 — 행동카드 생성
  generate(
    title: '루미가 행동카드를\n만들고 있어요',
    lumiSide: LumiSide.right,
    stages: [
      RoutineStage(label: '오늘의 일과를 읽고 있어요', percent: 70, hold: _holdLong),
      RoutineStage(label: '중요한 준비물을 찾고 있어요', percent: 80, hold: _holdShort),
      RoutineStage(label: '순서를 정리하고 있어요', percent: 90, hold: _holdLong),
    ],
  );

  const RoutineLoadingKind({
    required this.title,
    required this.stages,
    required this.lumiSide,
  });

  /// 화면 제목 (Figma 원문 — 줄바꿈 위치까지 그대로)
  final String title;

  /// 체크리스트 3줄
  final List<RoutineStage> stages;

  /// 루미가 나오는 방향 (Figma `Group 26` x좌표)
  final LumiSide lumiSide;
}

/// 루미가 어느 쪽에서 나오는가.
///
/// 두 로딩 프레임이 좌우 대칭이다 — 준비(262:4569)는 x=-48로 왼쪽 밖,
/// 생성(262:4703)은 x=325로 오른쪽 밖에 걸친다. 연출은 같고 방향만 다르므로
/// 화면을 둘로 나누지 않고 이 값으로 갈린다.
enum LumiSide { left, right }

/// 로딩 체크리스트 한 줄.
///
/// ⚠️ **서버가 진행 상황을 알려주지 않는다.** `POST /api/routines`는 완료될
/// 때까지 응답이 없어, 단계 전진은 클라이언트가 예상 시간으로 흉내낸다.
/// 서버에 진행률 API가 생기면 그 값으로 대체한다. (이슈 #33)
///
/// 그래서 **100%를 만들지 않는다.** 실제 완료는 서버 응답이 결정하며, 마지막
/// 단계에 도달해도 응답 전까지는 대기 상태로 둔다. 가짜 100%를 보여주면
/// 다 됐는데 안 넘어간다는 인상을 준다.
/// 스텝별 노출시간.
///
/// 처음에는 4초 / 3초 / 4초였다(디자이너·기획 합의값). 그때는 Gemini라 AI가
/// 느려서 어차피 기다려야 했고, 연출이 그 시간을 덮어 주는 쪽이었다. 이미지·문장
/// 모델을 OpenAI로 옮겨 응답이 빨라지자(#261) 관계가 뒤집혀, **연출이 사용자를
/// 붙잡는 쪽**이 됐다 — 화면 하나가 11초, 일과 하나에 22초였다. 절반으로 줄인다.
/// 세 줄을 읽기에는 이만큼이면 된다 (#276).
///
/// 상수로 빼둔 이유 — 두 로딩 화면이 같은 리듬을 써야 한다. 한쪽만 고치면
/// 흐름이 어긋나는데, 화면을 나란히 보지 않으면 눈치채기 어렵다.
///
/// **값이 아니라 쓰임으로 이름 짓는다.** `_hold4`처럼 값을 이름에 박으면
/// 다음에 시간을 바꿀 때 이름까지 틀린 말이 된다.
const _holdLong = Duration(seconds: 2);
const _holdShort = Duration(milliseconds: 1500);

class RoutineStage {
  const RoutineStage({
    required this.label,
    required this.percent,
    required this.hold,
  });

  /// 화면에 보이는 문구 (Figma 원문)
  final String label;

  /// 이 단계에 도달했을 때 보여줄 진행률.
  ///
  /// Figma가 [RoutineLoadingKind.prepare]에서 40%,
  /// [RoutineLoadingKind.generate]에서 90%를 보여준다. 두 화면이 이어지므로
  /// 뒤 화면의 진행률이 앞 화면보다 커야 흐름이 뒤로 가지 않는다.
  final int percent;

  /// 이 단계가 머무는 시간.
  ///
  /// **결과가 아직이면** 이만큼 보여준다. 로딩이 순식간에 스쳐 지나가면
  /// "무엇을 하고 있는지"를 보여주려던 목적이 사라진다 — 특히 개인정보를
  /// 가린다는 사실은 보호자가 봐야 의미가 있다.
  ///
  /// **결과가 이미 왔으면 이 시간을 채우지 않는다** (#276). 다 끝난 일을
  /// 붙잡아 둘 이유가 없다. 대신 한 줄도 못 보고 지나가지 않을 만큼만 머문다.
  ///
  /// 반대로 응답이 **늦으면** 마지막 단계에서 기다린다. 단계를 다 소진했다고
  /// 화면을 넘기지 않는다 — 아직 결과가 없기 때문이다.
  final Duration hold;
}
