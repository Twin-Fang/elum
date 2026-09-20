package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

/**
 * 홈 목록의 일과 순서.
 *
 * @param routineIds 화면에 보이는 차례대로 담은 일과 식별자. 앞에 있을수록 위다
 */
@Schema(description = "일과 순서 변경 요청")
public record RoutineReorderRequest(

  @Schema(description = "화면에 보이는 차례대로 담은 일과 ID 목록")
  List<String> routineIds
) {

}
