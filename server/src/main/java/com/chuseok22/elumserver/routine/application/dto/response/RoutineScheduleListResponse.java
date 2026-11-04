package com.chuseok22.elumserver.routine.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(description = "주간 계획: 이 이룸이의 반복 일과 전부 + 이룸이 기기 알림 상태 (#782, #1080)")
public record RoutineScheduleListResponse(

  @Schema(description = "반복 일과, 시각 순")
  List<RoutineScheduleResponse> schedules,

  @Schema(description = "요청한 보호자가 요일·시각을 새로 정하거나 바꿀 수 있는가 (요금제 권한 ROUTINE_SCHEDULE)",
    example = "true")
  boolean canSchedule,

  @Schema(description = "이룸이 기기 알림 상태. NO_DEVICE 연결된 기기 없음 · OFF 연결됐지만 알림 꺼짐(등록된 알림 토큰 없음) · ON",
    example = "ON")
  String elumiNotification
) {

}
