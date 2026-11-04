package com.chuseok22.elumserver.routine.application.dto.response;

import com.chuseok22.elumserver.routine.core.RoutineScheduleWeekdays;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineSchedule;
import io.swagger.v3.oas.annotations.media.Schema;
import java.time.DayOfWeek;
import java.time.format.DateTimeFormatter;
import java.util.List;

@Schema(description = "일과 하나의 반복 요일·시각 (#782, #1080)")
public record RoutineScheduleResponse(

  @Schema(description = "일과관리 원본 일과 ID")
  String routineId,

  @Schema(description = "반복 요일, 월요일부터", example = "[\"MONDAY\", \"FRIDAY\"]")
  List<String> weekdays,

  @Schema(description = "시각 (한국 시각, HH:mm)", example = "08:00")
  String time,

  @Schema(description = "그 시각에 이룸이 기기에 알림을 보내는가", example = "true")
  boolean notifyEnabled,

  @Schema(description = "멈춤: 저장한 보호자의 요금제가 이 기능을 쓰지 못함 (Pro 끝남). 지우지 않고 그대로 두며 "
    + "오늘 일과 만들기·알림이 멈춘다", example = "false")
  boolean paused
) {

  /// 화면·요청이 쓰는 시각 형식 (HH:mm)
  public static final DateTimeFormatter TIME_FORMAT = DateTimeFormatter.ofPattern("HH:mm");

  /// 예약 + 멈춤 여부 > 응답
  public static RoutineScheduleResponse of(RoutineSchedule schedule, boolean paused) {
    List<String> weekdays = RoutineScheduleWeekdays.fromMask(schedule.getWeekdaysMask()).stream()
      .map(DayOfWeek::name)
      .toList();
    return new RoutineScheduleResponse(schedule.getRoutineId(), weekdays, schedule.getTimeOfDay().format(TIME_FORMAT),
      schedule.isNotifyEnabled(), paused);
  }
}
