package com.chuseok22.elumserver.credit.application.dto.response;

import com.chuseok22.elumserver.credit.core.CreditHistoryKind;
import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.List;

/**
 * 보호자 설정의 크레딧 사용 내역 한 쪽. 최근 것이 먼저다.
 */
@Schema(description = "크레딧 사용 내역 한 쪽")
public record CreditHistoryResponse(
  @Schema(description = "이 쪽의 내역. 최근 것이 먼저")
  List<Entry> entries,
  @Schema(description = "다음 쪽이 있는가", example = "true")
  boolean hasNext,
  @Schema(description = "이 쪽 번호(0부터)", example = "0")
  int page
) {

  @Schema(description = "내역 한 줄")
  public record Entry(
    @Schema(description = "줄 식별자(목록 키)", example = "c0a8…:image")
    String id,
    @Schema(description = "종류. 앱이 이 값으로 문구를 정한다", example = "CARD_IMAGES")
    CreditHistoryKind kind,
    @Schema(description = "사용 줄의 일과 제목. 일과가 지워졌거나 사용 줄이 아니면 null", example = "스스로 옷을 입어요", nullable = true)
    String routineTitle,
    @Schema(description = "카드 그림 수(그림 줄만). 그 밖은 null", example = "4", nullable = true)
    Integer cardCount,
    @Schema(description = "크레딧 증감. 사용은 음수, 지급은 양수", example = "-4")
    int delta,
    @Schema(description = "일어난 시각 — 시간대 없는 서버 시각(한국 시각)", example = "2026-10-01T11:23:00")
    LocalDateTime occurredAt,
    @Schema(description = "같은 시각에 시간대 오프셋을 붙인 값. 앱은 이 값을 기기 시간대로 바꿔 보여준다",
      example = "2026-10-01T11:23:00+09:00")
    OffsetDateTime occurredAtOffset
  ) {

  }

  /// 내역이 없는 쪽 (계정이 아직 없을 때 포함).
  public static CreditHistoryResponse empty(int page) {
    return new CreditHistoryResponse(List.of(), false, page);
  }
}
