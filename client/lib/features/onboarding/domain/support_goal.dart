import '../../../core/l10n/current_l10n.dart';

/// 보호자가 선택하는 "도움 목표".
///
/// 이룸은 진단명·장애 유형을 수집하지 않는다. 개인화는 오직 이 목표로만 한다.
/// (docs/README.md 원칙 1번 — "최소한의 정보로 개인화")
///
/// ⚠️ [apiValue]는 서버 enum과 반드시 일치해야 한다.
/// 출처: server/src/main/java/com/chuseok22/elumserver/member/infrastructure/entity/SupportGoal.java
/// 서버가 바뀌면 이 파일을 먼저 맞춘다. docs의 명세 초안이 아니라 서버 코드가 기준이다.
///
/// [label]은 Figma `온보딩_목표` 프레임 문구를 따른다 (서버 label과 어미가 다르다).
enum SupportGoal {
  stepByStep('STEP_BY_STEP'),
  prepareItems('PREPARE_ITEMS'),
  prepareNew('PREPARE_NEW'),
  independent('INDEPENDENT');

  const SupportGoal(this.apiValue);

  /// 화면에 표시되는 문구 (Figma 기준). 호출 시점의 언어로 읽는다.
  String get label => switch (this) {
    SupportGoal.stepByStep => appL10n.goalStepByStep,
    SupportGoal.prepareItems => appL10n.goalPrepareItems,
    SupportGoal.prepareNew => appL10n.goalPrepareNew,
    SupportGoal.independent => appL10n.goalIndependent,
  };

  /// 서버 전송용 값 (서버 enum name과 동일)
  final String apiValue;

  /// 서버 응답 파싱. 모르는 값이 와도 죽지 않는다.
  static SupportGoal? fromApiValue(String value) {
    for (final goal in SupportGoal.values) {
      if (goal.apiValue == value) return goal;
    }
    return null;
  }
}
