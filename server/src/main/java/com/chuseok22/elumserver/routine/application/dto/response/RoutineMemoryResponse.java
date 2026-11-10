package com.chuseok22.elumserver.routine.application.dto.response;

import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleSource;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleStatus;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleType;
import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

@Schema(description = "AI 메모리: 이 보호자가 이 이룸이에게 쓰는 카드 만들기 규칙 (보호자 한 사람의 것)")
public record RoutineMemoryResponse(

  @Schema(description = "이 계정이 AI 메모리를 쓸 수 있는가 (Pro). false 면 나머지는 비어 있다 (Free 는 미리 보기 판)")
  boolean available,

  @Schema(description = "켜짐 여부. 끄면 찾지도 넣지도 않는다 (규칙은 남음). 아직 정한 적 없으면 true")
  boolean enabled,

  @Schema(description = "같은 수정이 서로 다른 일과 몇 개에서 관찰되면 자동 적용되나 (설정 값, 2~10)", example = "3")
  int autoApplyCount,

  @Schema(description = "규칙. ACTIVE, WATCHING, OFF 순 > 그 안에서 최근 것 먼저")
  List<RuleResponse> rules,

  @Schema(description = "수정 기록 (일과마다 한 줄, 최근 20개)")
  List<EditResponse> edits
) {

  public static RoutineMemoryResponse unavailable(int autoApplyCount) {
    return new RoutineMemoryResponse(false, false, autoApplyCount, List.of(), List.of());
  }

  @Schema(description = "규칙 하나")
  public record RuleResponse(
    String id,
    @Schema(description = "WORD 낱말 바꾸기 · SPLIT 카드 나누기 · MERGE 카드 합치기 · ADD 카드 더하기 · REMOVE 카드 빼기 · MANUAL 직접 적음")
    RoutineMemoryRuleType type,
    @Schema(description = "ACTIVE 적용 중 · WATCHING 관찰 중(적용 안 함) · OFF 보호자가 끔")
    RoutineMemoryRuleStatus status,
    @Schema(description = "AI 가 고친 카드에서 찾음 / MANUAL 보호자가 직접 적음")
    RoutineMemoryRuleSource source,
    @Schema(description = "한 줄 요약", example = "착용해요 대신 입어요") String summary,
    @Schema(description = "바꾸기 전 낱말. 없으면 null", nullable = true) String before,
    @Schema(description = "바꾼 뒤 낱말. 없으면 null", nullable = true) String after,
    @Schema(description = "서로 다른 일과에서 관찰된 수") int evidenceCount,
    @Schema(description = "근거 일과 (최근 5개)") List<EvidenceResponse> evidences,
    @Schema(description = "마지막으로 바뀐 시각") OffsetDateTime updatedAt
  ) {

  }

  @Schema(description = "근거 일과 하나. 일과가 지워져도 제목 사본이 남는다")
  public record EvidenceResponse(String routineTitle, LocalDate observedAt) {

  }

  @Schema(description = "일과 하나의 수정 기록")
  public record EditResponse(
    String routineTitle, LocalDate editedAt, int cardCountBefore, int cardCountAfter, int changedTextCount
  ) {

  }
}
