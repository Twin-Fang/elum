package com.chuseok22.elumserver.routine.application.dto.response;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.fasterxml.jackson.annotation.JsonIgnore;
import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDateTime;
import java.util.List;

@Schema(description = "일과 응답")
public record RoutineResponse(

  @Schema(description = "일과 ID")
  String id,

  @Schema(description = "AI가 생성한 제목", example = "병원에 다녀와요")
  String title,

  @Schema(description = "일과 원문(마스킹 전)", example = "내일 오후 3시에 병원 가기")
  String rawInputText,

  @Schema(description = "민감정보를 카테고리 태그로 치환한 텍스트(Gemini에 실제 전달된 값). 자동화 테스트가 없는 프로젝트 특성상, 마스킹이 실제로 적용됐는지 API 응답만으로 수동 검증할 수 있도록 노출한다.", example = "<이름>이랑 내일 오후 3시에 병원 가기")
  String sanitizedInputText,

  @Schema(description = "일과 수행 날짜/시각")
  LocalDateTime scheduledAt,

  @Schema(description = "상태", example = "PENDING_REVIEW")
  String status,

  @Schema(description = "최신 피드백(없으면 null)")
  String revisionFeedback,

  @Schema(description = "모든 단계를 완료한 시각(KST), 미완료 시 null")
  LocalDateTime completedAt,

  @Schema(description = "완료한 단계 수", example = "1")
  Integer completedStepCount,

  @Schema(description = "전체 단계 수", example = "2")
  Integer totalStepCount,

  @Schema(description = "진행률(%), 단계가 없으면 0", example = "50")
  Integer progressPercent,

  @Schema(description = "보호자가 정한 보상(강화물). 설정하지 않았으면 null — 아동 화면에서 보상 UI를 띄우지 않는다", example = "젤리 먹기")
  String rewardText,

  @Schema(description = "보상 프리셋 키. 직접 입력이면 CUSTOM 또는 null", example = "SNACK")
  String rewardPresetKey,

  @Schema(description = "단계 목록")
  List<RoutineStepResponse> steps,

  @Schema(description = "이번 AI 일과 생성에 쓴 크레딧 (#407). 일과 생성 응답에만 있고, 크레딧이 꺼져 있거나 다른 API 면 null",
    nullable = true)
  CreditUsage credit,

  @Schema(description = "카드 추가에서 그림을 만들지 않은 까닭 (#407). 그림을 요청했는데 크레딧이 모자라면 "
    + "AI_CREDIT_INSUFFICIENT — 카드는 저장했다. 그 밖에는 null", example = "AI_CREDIT_INSUFFICIENT", nullable = true)
  String imageSkippedReason,

  /// 일과를 만든 보호자 ID. 응답에는 싣지 않는다 — forCaller 가 원문을 가릴지 판단하는 데만 쓴다.
  @JsonIgnore
  @Schema(hidden = true)
  String createdBy
) {

  /**
   * 생성 한 번의 크레딧 사용 (#407). 카드 확인 화면 머리의 "AI 그림 N장 · M크레딧 사용 · K 남음" 한 줄.
   *
   * @param charged      실제 차감량. 잔액이 모자랐으면 청구보다 작다(모자란 몫은 빚으로 남기지 않는다)
   * @param balanceAfter 정산 뒤 사용 가능량
   */
  @Schema(description = "AI 일과 생성 한 번의 크레딧 사용")
  public record CreditUsage(
    @Schema(description = "만든 카드 수", example = "5") int cardCount,
    @Schema(description = "붙은 AI 그림 수", example = "5") int imageCount,
    @Schema(description = "실제 차감한 크레딧", example = "6") int charged,
    @Schema(description = "정산 뒤 사용 가능한 크레딧", example = "94") int balanceAfter
  ) {

  }

  /// 크레딧을 붙인 응답. 나머지 필드는 그대로다.
  public RoutineResponse withCredit(CreditUsage usage) {
    return new RoutineResponse(id, title, rawInputText, sanitizedInputText, scheduledAt, status, revisionFeedback,
      completedAt, completedStepCount, totalStepCount, progressPercent, rewardText, rewardPresetKey, steps,
      usage, imageSkippedReason, createdBy);
  }

  /// 그림을 건너뛴 까닭을 붙인 응답.
  public RoutineResponse withImageSkippedReason(String reason) {
    return new RoutineResponse(id, title, rawInputText, sanitizedInputText, scheduledAt, status, revisionFeedback,
      completedAt, completedStepCount, totalStepCount, progressPercent, rewardText, rewardPresetKey, steps,
      credit, reason, createdBy);
  }

  /// 보호자가 쓴 말(원문·마스킹본·재생성 피드백)을 뺀 응답 (#357). 이룸이 휴대폰은 화면에 쓰지 않는 값이라
  /// 보낼 이유가 없다. 보내지 않으면 휴대폰 캐시·네트워크 로그에도 남을 수 없다.
  public RoutineResponse withoutSourceText() {
    return new RoutineResponse(id, title, null, null, scheduledAt, status, null,
      completedAt, completedStepCount, totalStepCount, progressPercent, rewardText, rewardPresetKey, steps,
      credit, imageSkippedReason, createdBy);
  }

  /// 보호자 원문을 가려야 하는 호출자인가.
  /// - 이룸이 휴대폰: 화면에 쓰지 않는다 (#357).
  /// - 같은 이룸이에 합류한 다른 보호자: 남이 쓴 원문·피드백을 볼 이유가 없다 (서비스 원칙 5). 제목·카드·상태는 그대로 본다.
  /// - 만든 사람이 비어 있는 옛 일과(V25 이전·롤백 중 생성)는 가리지 않는다. 그 시절엔 대표 보호자 한 명뿐이었고
  ///   부팅 때 created_by 가 채워지는 일시 상태라, 가리면 오히려 만든 본인의 원문이 사라질 수 있다.
  ///   (호출자가 이 이룸이의 보호자인지는 서비스 단계의 접근 판단이 이미 확인했다)
  private boolean hidesSourceTextFrom(Caller caller) {
    if (caller.isElumi()) {
      return true;
    }
    return createdBy != null && !createdBy.equals(caller.memberId());
  }

  /// 호출자에 따라 보호자 원문을 뺀다. 일과를 만든 보호자 본인에게만 그대로 돌려준다.
  public RoutineResponse forCaller(Caller caller) {
    return hidesSourceTextFrom(caller) ? withoutSourceText() : this;
  }

  public static RoutineResponse from(Routine routine) {
    List<RoutineStepResponse> stepResponses = routine.getSteps().stream()
      .map(RoutineStepResponse::from)
      .toList();
    int totalStepCount = stepResponses.size();
    int completedStepCount = (int) stepResponses.stream()
      .filter(RoutineStepResponse::completed)
      .count();
    int progressPercent = totalStepCount == 0 ? 0 : (completedStepCount * 100) / totalStepCount;
    return new RoutineResponse(
      routine.getId(),
      routine.getTitle(),
      routine.getRawInputText(),
      routine.getSanitizedInputText(),
      routine.getScheduledAt(),
      routine.getStatus().name(),
      routine.getRevisionFeedback(),
      routine.getCompletedAt(),
      completedStepCount,
      totalStepCount,
      progressPercent,
      routine.getRewardText(),
      routine.getRewardPresetKey(),
      stepResponses,
      null,
      null,
      routine.getCreatedBy()
    );
  }
}
