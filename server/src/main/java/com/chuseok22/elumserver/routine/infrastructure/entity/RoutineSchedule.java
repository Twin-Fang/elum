package com.chuseok22.elumserver.routine.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.LocalDate;
import java.time.LocalTime;
import lombok.Getter;
import lombok.Setter;

/**
 * 일과관리 원본 하나의 반복 예약: 요일 + 시각 + 이룸이 기기 알림 (#782, #1080)
 * 외래키 없는 문자열 ID (source_routine_id 와 같은 방식). 인덱스 이름은 V62 와 같음
 */
@Entity
@Getter
@Setter
@Table(
  name = "routine_schedule",
  uniqueConstraints = @UniqueConstraint(name = "uk_routine_schedule_routine_id", columnNames = "routine_id"),
  indexes = {
    @Index(name = "idx_routine_schedule_profile_id", columnList = "profile_id"),
    @Index(name = "idx_routine_schedule_time_of_day", columnList = "time_of_day")
  }
)
public class RoutineSchedule extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  /// 일과관리 원본 ID (보내기로 만든 일과가 아님)
  @Column(name = "routine_id", nullable = false)
  private String routineId;

  @Column(name = "profile_id", nullable = false)
  private String profileId;

  /// 마지막으로 저장한 보호자. 이 사람의 요금제로 실행 여부를 판정 (Pro 끝나면 멈춤, 지우지 않음)
  @Column(name = "owner_member_id", nullable = false)
  private String ownerMemberId;

  /// 요일 비트 합 (RoutineScheduleWeekdays: 월 1 ~ 일 64)
  @Column(name = "weekdays_mask", nullable = false)
  private int weekdaysMask;

  /// 그 요일의 시각 (한국 시각, 분 단위)
  @Column(name = "time_of_day", nullable = false)
  private LocalTime timeOfDay;

  /// 이룸이 기기 알림: true 보냄, false 오늘 일과만 만듦
  @Column(name = "is_notify_enabled", nullable = false, columnDefinition = "boolean not null default true")
  private boolean isNotifyEnabled = true;

  /// 오늘 일과를 마지막으로 만든 날 (같은 날 두 벌 막기)
  @Column(name = "last_materialized_date")
  private LocalDate lastMaterializedDate;

  /// 알림을 마지막으로 보낸 날 (같은 날 두 번 막기)
  @Column(name = "last_notified_date")
  private LocalDate lastNotifiedDate;
}
