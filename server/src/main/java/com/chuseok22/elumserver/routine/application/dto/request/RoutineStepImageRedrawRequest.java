package com.chuseok22.elumserver.routine.application.dto.request;

import com.chuseok22.elumserver.routine.core.ImageRedrawHint;
import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

/**
 * 고쳐서 다시 그리기·AI 그림 그리기 요청: 고치고 싶은 점(짧은 글) + 칩. 둘 다 비면 같은 조건으로 다시 그림
 */
@Schema(description = "카드 그림 다시 그리기 요청 (본문 생략 가능)")
public record RoutineStepImageRedrawRequest(

  @Schema(description = "고치고 싶은 점 (60자 이하, 넘으면 400 INVALID_INPUT_VALUE). 그림 지시문에 보호자 요청으로 덧붙임",
    example = "우산을 파란색으로", nullable = true)
  String requestText,

  @Schema(description = "자주 쓰는 요청 칩. SIMPLER(더 단순하게) · NO_BACKGROUND(배경 빼기) · NO_PEOPLE(사람 빼기) · BRIGHTER(더 밝게)",
    example = "[\"SIMPLER\", \"BRIGHTER\"]", nullable = true)
  List<ImageRedrawHint> hints
) {

  /// 본문 없이 온 요청 (같은 조건으로 다시 그림)
  public static final RoutineStepImageRedrawRequest EMPTY = new RoutineStepImageRedrawRequest(null, null);
}
