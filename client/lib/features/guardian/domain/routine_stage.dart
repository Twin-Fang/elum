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
/// [prepare]가 앞인 근거는 진행률이다 — Figma가 40%(262:4569)와 90%(262:4703)를
/// 보여주므로 40% 쪽이 먼저다. 문구를 근거로 삼지 않는다.
///
/// ⚠️ **문구는 Figma 원문 그대로 쓴다.** 흐름상 그럴듯하다는 이유로 지어내면
/// 화면이 조용히 명세와 어긋난다 (실제로 3번째 단계가 "추가 질문을 생각하고
/// 있어요"로 잘못 들어가 있었다).
enum RoutineLoadingKind {
  /// 262:4569 — DLP 마스킹 + 추가 질문 준비
  prepare(
    title: '루미가 내용을\n정리하고 있어요',
    stages: [
      RoutineStage(label: '아이를 알아볼 수 있는 정보는 가려요', percent: 15, hold: _hold4),
      RoutineStage(label: '꼭 필요한 내용만 정리해요', percent: 40, hold: _hold3),
      RoutineStage(label: '아이가 이해하기 쉬운 말로 바꿔요', percent: 65, hold: _hold4),
    ],
  ),

  /// 262:4703 — 행동카드 생성
  generate(
    title: '루미가 행동카드를\n만들고 있어요',
    stages: [
      RoutineStage(label: '오늘의 일과를 읽고 있어요', percent: 70, hold: _hold4),
      RoutineStage(label: '중요한 준비물을 찾고 있어요', percent: 80, hold: _hold3),
      RoutineStage(label: '순서를 정리하고 있어요', percent: 90, hold: _hold4),
    ],
  );

  const RoutineLoadingKind({required this.title, required this.stages});

  /// 화면 제목 (Figma 원문 — 줄바꿈 위치까지 그대로)
  final String title;

  /// 체크리스트 3줄
  final List<RoutineStage> stages;
}

/// 로딩 체크리스트 한 줄.
///
/// ⚠️ **서버가 진행 상황을 알려주지 않는다.** `POST /api/routines`는 완료될
/// 때까지 응답이 없어, 단계 전진은 클라이언트가 예상 시간으로 흉내낸다.
/// 서버에 진행률 API가 생기면 그 값으로 대체한다. (이슈 #33)
///
/// 그래서 **100%를 만들지 않는다.** 실제 완료는 서버 응답이 결정하며, 마지막
/// 단계에 도달해도 응답 전까지는 대기 상태로 둔다. 가짜 100%를 보여주면
/// 다 됐는데 안 넘어간다는 인상을 준다.
/// 스텝별 최소 노출시간. 디자이너·기획 합의값(4초 / 3초 / 4초)이다.
///
/// 상수로 빼둔 이유 — 두 로딩 화면이 같은 리듬을 써야 한다. 한쪽만 고치면
/// 흐름이 어긋나는데, 화면을 나란히 보지 않으면 눈치채기 어렵다.
const _hold4 = Duration(seconds: 4);
const _hold3 = Duration(seconds: 3);

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

  /// 이 단계를 **반드시 보여줄** 시간.
  ///
  /// 서버 응답이 먼저 와도 이 시간이 지나기 전엔 다음 화면으로 넘기지 않는다.
  /// 로딩이 순식간에 스쳐 지나가면 "무엇을 하고 있는지"를 보여주려던 목적이
  /// 사라진다 — 특히 개인정보를 가린다는 사실은 보호자가 봐야 의미가 있다.
  ///
  /// 반대로 응답이 **늦으면** 마지막 단계에서 기다린다. 단계를 다 소진했다고
  /// 화면을 넘기지 않는다 — 아직 결과가 없기 때문이다.
  final Duration hold;
}
