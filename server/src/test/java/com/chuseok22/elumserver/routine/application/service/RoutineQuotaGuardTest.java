package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.time.DayOfWeek;
import java.time.LocalDateTime;
import java.time.LocalTime;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class RoutineQuotaGuardTest {

  private static final String MEMBER_ID = "m1";

  @Mock
  private EntitlementService entitlementService;

  @Mock
  private AiCallLogRepository aiCallLogRepository;

  @Mock
  private RoutineRepository routineRepository;

  @InjectMocks
  private RoutineQuotaGuard guard;

  private void weeklyUsed(long count) {
    lenient().when(aiCallLogRepository
        .countByMemberIdAndCallTypeAndSuccessIsTrueAndCreatedAtGreaterThanEqual(
          eq(MEMBER_ID), eq(AiCallType.GEMINI_TEXT_CREATE), any(LocalDateTime.class)))
      .thenReturn(count);
  }

  private void owned(long count) {
    lenient().when(routineRepository.countByProfileMemberId(MEMBER_ID)).thenReturn(count);
  }

  @Test
  @DisplayName("한도 안이면 통과한다")
  void withinLimits_passes() {
    weeklyUsed(2);
    owned(1);
    when(entitlementService.isWithinLimit(anyString(), any(), anyLong())).thenReturn(true);

    assertThatCode(() -> guard.guard(MEMBER_ID)).doesNotThrowAnyException();
  }

  @Test
  @DisplayName("이번 주 생성 한도를 넘으면 거부한다")
  void weeklyLimitExceeded_throws() {
    weeklyUsed(5);
    when(entitlementService.isWithinLimit(
      MEMBER_ID, Entitlement.ROUTINE_CREATE_PER_WEEK, 5L)).thenReturn(false);

    assertThatThrownBy(() -> guard.guard(MEMBER_ID))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_CREATE_LIMIT_EXCEEDED));
  }

  @Test
  @DisplayName("보유 개수 한도를 넘으면 거부한다")
  void ownedLimitExceeded_throws() {
    weeklyUsed(0);
    owned(3);
    when(entitlementService.isWithinLimit(
      MEMBER_ID, Entitlement.ROUTINE_CREATE_PER_WEEK, 0L)).thenReturn(true);
    when(entitlementService.isWithinLimit(
      MEMBER_ID, Entitlement.ROUTINE_MAX_COUNT, 3L)).thenReturn(false);

    assertThatThrownBy(() -> guard.guard(MEMBER_ID))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_COUNT_LIMIT_EXCEEDED));
  }

  @Test
  @DisplayName("사용량 집계가 실패해도 사용자를 막지 않는다 — 우리 DB 문제로 앱을 못 쓰면 안 된다")
  void usageQueryFails_passes() {
    lenient().when(aiCallLogRepository
        .countByMemberIdAndCallTypeAndSuccessIsTrueAndCreatedAtGreaterThanEqual(
          anyString(), any(), any(LocalDateTime.class)))
      .thenThrow(new RuntimeException("DB 장애"));
    lenient().when(routineRepository.countByProfileMemberId(anyString()))
      .thenThrow(new RuntimeException("DB 장애"));

    assertThatCode(() -> guard.guard(MEMBER_ID)).doesNotThrowAnyException();
  }

  @Test
  @DisplayName("주 시작은 월요일 0시다")
  void weekStart_isMonday() {
    LocalDateTime start = RoutineQuotaGuard.weekStart();

    assertThat(start.getDayOfWeek()).isEqualTo(DayOfWeek.MONDAY);
    assertThat(start.toLocalTime()).isEqualTo(LocalTime.MIDNIGHT);
    assertThat(start).isBeforeOrEqualTo(LocalDateTime.now());
  }
}
