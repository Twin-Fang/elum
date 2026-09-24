package com.chuseok22.elumserver.credit.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 보호자 설정 화면의 이번 주 AI 크레딧 (#407 스펙 §3). 필드 이름은 앱 {@code CreditSummary} 가 그대로 읽는다.
 */
@Schema(description = "내 AI 크레딧 요약")
public record CreditSummaryResponse(
  @Schema(description = "크레딧 정책이 켜져 있는가. false 면 나머지는 0·빈 값이고 앱은 카드를 숨긴다", example = "true")
  boolean enabled,
  @Schema(description = "지금 쓸 수 있는 크레딧 = 유효 적립 남은 양 − 진행 중 예약", example = "72")
  int available,
  @Schema(description = "이번 주 주간 지급량", example = "100")
  int weeklyGrant,
  @Schema(description = "주간이 아닌 유효 적립(관리자 보너스 등)의 남은 양", example = "0")
  int bonus,
  @Schema(description = "이번 주기에 실제로 차감한 양", example = "28")
  int used,
  @Schema(description = "진행 중 작업이 잡아 둔 양", example = "0")
  int reserved,
  @Schema(description = "이번 주기 시작(한국 시각 월요일 0시)", example = "2026-09-21T00:00:00", nullable = true)
  LocalDateTime periodStart,
  @Schema(description = "다음 초기화(다음 월요일 0시)", example = "2026-09-28T00:00:00", nullable = true)
  LocalDateTime nextResetAt,
  @Schema(description = "행동별 단가")
  Costs costs,
  @Schema(description = "일과 하나의 최대 카드 수 — 앱이 직전 안내 기준(글 + 카드 × 그림 단가)을 계산한다", example = "10")
  int maxCardsPerRoutine,
  @Schema(description = "진행 중(예약) 작업")
  List<InProgress> inProgress,
  @Schema(description = "지금 AI 일과를 시작할 수 있는가", example = "true")
  boolean canStartRoutine,
  @Schema(description = "지금 수동 카드 그림을 만들 수 있는가", example = "true")
  boolean canGenerateImage
) {

  @Schema(description = "행동별 단가")
  public record Costs(
    @Schema(description = "일과 글 1건", example = "1") int routineText,
    @Schema(description = "AI 그림 1장", example = "1") int cardImage
  ) {

  }

  @Schema(description = "진행 중 작업")
  public record InProgress(
    @Schema(description = "작업 ID") String jobId,
    @Schema(description = "ROUTINE_CREATE · CARD_IMAGE · IMAGE_REGENERATE", example = "ROUTINE_CREATE") String kind,
    @Schema(description = "시작 시각") LocalDateTime startedAt
  ) {

  }

  /// 정책이 꺼져 있을 때. 앱은 카드를 숨기고 아무것도 막지 않는다.
  public static CreditSummaryResponse disabled(int maxCardsPerRoutine) {
    return new CreditSummaryResponse(false, 0, 0, 0, 0, 0, null, null, new Costs(0, 0),
      maxCardsPerRoutine, List.of(), true, true);
  }
}
