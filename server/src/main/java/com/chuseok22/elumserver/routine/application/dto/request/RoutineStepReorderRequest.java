package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

/**
 * 일과 안의 행동 단계 순서.
 *
 * <p>{@link RoutineReorderRequest}(일과 순서)와 같은 방식이다 — <b>화면에 보이는
 * 전체를 그대로 받아 통째로 다시 매긴다.</b> 부분 갱신은 두 곳에서 동시에 바꿀 때
 * 뒤엉킨다.
 *
 * @param stepIds 화면에 보이는 차례대로 담은 단계 식별자. 앞에 있을수록 먼저 한다
 */
@Schema(description = "행동 단계 순서 변경 요청")
public record RoutineStepReorderRequest(

  @Schema(description = "화면에 보이는 차례대로 담은 단계 ID 목록")
  List<String> stepIds
) {

}
