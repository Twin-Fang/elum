package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import java.time.LocalDateTime;

public record AdminRoutineResponse(
  String id,
  String title,
  String memberNickname,
  String memberUsername,
  RoutineStatus status,
  LocalDateTime scheduledAt,
  LocalDateTime completedAt,
  /** 일과의 콘텐츠 언어 코드. 운영자가 어느 언어로 만들어진 일과인지 본다. */
  String language
) {

  /** 보호자 칸은 일과를 만든 사람의 계정 이름이다 (옛 대표 보호자 컬럼은 V32 에서 지웠다). */
  public static AdminRoutineResponse from(Routine routine, String creatorUsername) {
    return new AdminRoutineResponse(
      routine.getId(),
      routine.getTitle(),
      routine.getProfile().getNickname(),
      creatorUsername,
      routine.getStatus(),
      routine.getScheduledAt(),
      routine.getCompletedAt(),
      // 마이그레이션 전 행은 null 일 수 있어 ko 로 떨어뜨린다
      routine.getLanguage() == null ? AppLocale.KO.code() : routine.getLanguage().code()
    );
  }
}
