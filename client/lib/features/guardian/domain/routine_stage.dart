/// 카드 생성 진행 단계.
///
/// Figma `보호자_새로운 일과 만들기_로딩`(262:4569 / 262:4703)의 체크리스트 3줄이다.
///
/// ⚠️ **서버가 진행 상황을 알려주지 않는다.** 현재 `POST /api/routines`는 완료될
/// 때까지 응답이 없어, 이 단계는 클라이언트가 예상 시간으로 진행시킨다.
/// 서버에 진행률 API가 생기면 그 값으로 대체한다. (이슈 #33)
///
/// 그래서 **100%를 만들지 않는다.** 실제 완료는 서버 응답이 결정하며,
/// 마지막 단계에 도달해도 응답 전까지는 대기 상태로 둔다. 가짜 100%를 보여주면
/// 다 됐는데 안 넘어간다는 인상을 준다.
enum RoutineStage {
  masking('아이를 알아볼 수 있는 정보는 가려요'),
  summarizing('꼭 필요한 내용만 정리해요'),
  rewriting('아이가 이해하기 쉬운 말로 바꿔요');

  const RoutineStage(this.label);

  /// 화면에 보이는 문구 (Figma 원문)
  final String label;

  /// 이 단계까지 왔을 때 보여줄 진행률.
  ///
  /// Figma가 두 번째 단계에서 `40%`를 보여주므로 그 값을 기준으로 잡았다.
  int get percent => switch (this) {
        RoutineStage.masking => 15,
        RoutineStage.summarizing => 40,
        RoutineStage.rewriting => 75,
      };

  /// 이 단계가 [current] 기준으로 이미 끝났는가
  bool isCompletedAt(RoutineStage current) => index < current.index;
}
