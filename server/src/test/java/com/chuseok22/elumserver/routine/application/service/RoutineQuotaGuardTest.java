package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
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
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.time.DayOfWeek;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.Arrays;
import java.util.Collection;
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

  /// 이번 주 이 회원의 성공한 호출 기록을 흉내 낸다.
  ///
  /// 가드가 넘긴 유형 목록에 든 행만 센다 — 실제 쿼리(`call_type in (...)`)와 같은 규칙이다.
  /// 예전 목은 `GEMINI_TEXT_CREATE` 하나로 고정돼 있어서, 가드가 무엇을 넘기든 같은 숫자를
  /// 돌려줬고 제공자가 바뀐 경우를 잡지 못했다 (#367).
  private void weeklyLog(AiCallType... successfulCalls) {
    lenient().when(aiCallLogRepository
        .countByMemberIdAndCallTypeInAndSuccessIsTrueAndCreatedAtGreaterThanEqual(
          eq(MEMBER_ID), anyCollection(), any(LocalDateTime.class)))
      .thenAnswer(invocation -> {
        Collection<AiCallType> counted = invocation.getArgument(1);
        return Arrays.stream(successfulCalls).filter(counted::contains).count();
      });
  }

  /// 같은 유형 호출을 n번 한 기록.
  private static AiCallType[] times(int n, AiCallType type) {
    AiCallType[] calls = new AiCallType[n];
    Arrays.fill(calls, type);
    return calls;
  }

  /// 주간 한도를 실제 판정 규칙(사용량 < 한도)대로 흉내 낸다.
  private void weeklyLimit(int limit) {
    lenient().when(entitlementService.isWithinLimit(
        eq(PlanType.FREE), eq(Entitlement.ROUTINE_CREATE_PER_WEEK), anyLong()))
      .thenAnswer(invocation -> (long) invocation.getArgument(2) < limit);
  }

  private void owned(long count) {
    lenient().when(routineRepository.countByProfileMemberId(MEMBER_ID)).thenReturn(count);
  }

  /// 보유 개수 한도는 이 파일의 관심사가 아닐 때 열어 둔다.
  private void ownedLimitOpen() {
    lenient().when(entitlementService.isWithinLimit(
      eq(PlanType.FREE), eq(Entitlement.ROUTINE_MAX_COUNT), anyLong())).thenReturn(true);
  }

  /// 가드는 플랜을 한 번만 읽어 두 검사에 나눠 쓴다. 그 한 번을 여기서 고정한다.
  private void plan(PlanType plan) {
    lenient().when(entitlementService.planOf(MEMBER_ID)).thenReturn(plan);
  }

  private static void assertRejectedWith(Runnable call, ErrorCode expected) {
    assertThatThrownBy(call::run)
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode()).isEqualTo(expected));
  }

  @Test
  @DisplayName("한도 안이면 통과한다")
  void withinLimits_passes() {
    plan(PlanType.FREE);
    weeklyLog(times(2, AiCallType.GEMINI_TEXT_CREATE));
    owned(1);
    when(entitlementService.isWithinLimit(any(PlanType.class), any(), anyLong())).thenReturn(true);

    assertThatCode(() -> guard.guard(MEMBER_ID)).doesNotThrowAnyException();
  }

  @Test
  @DisplayName("이번 주 생성 한도를 넘으면 거부한다")
  void weeklyLimitExceeded_throws() {
    plan(PlanType.FREE);
    weeklyLog(times(5, AiCallType.GEMINI_TEXT_CREATE));
    weeklyLimit(5);

    assertRejectedWith(() -> guard.guard(MEMBER_ID), ErrorCode.ROUTINE_CREATE_LIMIT_EXCEEDED);
  }

  @Test
  @DisplayName("텍스트 제공자를 OpenAI 로 바꿔 만든 일과도 이번 주 사용량에 든다 (#367)")
  void openAiCreatedRoutines_countTowardWeeklyLimit() {
    plan(PlanType.FREE);
    weeklyLog(times(3, AiCallType.OPENAI_TEXT_CREATE));
    weeklyLimit(3);
    ownedLimitOpen();

    assertRejectedWith(() -> guard.guard(MEMBER_ID), ErrorCode.ROUTINE_CREATE_LIMIT_EXCEEDED);
  }

  @Test
  @DisplayName("주 중간에 제공자를 바꿔도 두 제공자 몫을 합쳐 센다 (#367)")
  void providerSwitchedMidWeek_sumsBothProviders() {
    plan(PlanType.FREE);
    weeklyLog(
      AiCallType.GEMINI_TEXT_CREATE, AiCallType.OPENAI_TEXT_CREATE, AiCallType.GEMINI_TEXT_CREATE
    );
    weeklyLimit(3);
    ownedLimitOpen();

    assertRejectedWith(() -> guard.guard(MEMBER_ID), ErrorCode.ROUTINE_CREATE_LIMIT_EXCEEDED);
  }

  @Test
  @DisplayName("추가 질문·그림·민감정보 검사 호출은 일과 생성 횟수로 세지 않는다")
  void nonCreateCalls_doNotCount() {
    plan(PlanType.FREE);
    // 일과 1개를 만들면 질문·그림·검사 호출이 함께 쌓인다. 이것까지 세면 일과 하나에
    // 한도가 여러 칸 깎인다.
    weeklyLog(
      AiCallType.OPENAI_TEXT_CREATE,
      AiCallType.GEMINI_TEXT_QUESTION, AiCallType.OPENAI_TEXT_QUESTION,
      AiCallType.GEMINI_IMAGE, AiCallType.OPENAI_IMAGE, AiCallType.FLUX_IMAGE,
      AiCallType.LOCAL_LLM_DLP
    );
    weeklyLimit(2);
    ownedLimitOpen();

    assertThatCode(() -> guard.guard(MEMBER_ID)).doesNotThrowAnyException();
  }

  @Test
  @DisplayName("보유 개수 한도를 넘으면 거부한다")
  void ownedLimitExceeded_throws() {
    plan(PlanType.FREE);
    weeklyLog();
    owned(3);
    weeklyLimit(5);
    when(entitlementService.isWithinLimit(
      PlanType.FREE, Entitlement.ROUTINE_MAX_COUNT, 3L)).thenReturn(false);

    assertRejectedWith(() -> guard.guard(MEMBER_ID), ErrorCode.ROUTINE_COUNT_LIMIT_EXCEEDED);
  }

  @Test
  @DisplayName("사용량 집계가 실패해도 사용자를 막지 않는다 — 우리 DB 문제로 앱을 못 쓰면 안 된다")
  void usageQueryFails_passes() {
    plan(PlanType.FREE);
    lenient().when(aiCallLogRepository
        .countByMemberIdAndCallTypeInAndSuccessIsTrueAndCreatedAtGreaterThanEqual(
          anyString(), anyCollection(), any(LocalDateTime.class)))
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
