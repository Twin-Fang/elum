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
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class RoutineQuotaGuardTest {

  private static final String MEMBER_ID = "m1";

  /// 2026-09-23(수) 15:00 한국 시각. 요일을 고정해야 "이번 주지만 오늘은 아닌" 기록을
  /// 어느 요일에 돌려도 만들 수 있다 — 월요일에 돌리면 그런 날이 없다.
  private static final Clock WEDNESDAY_AFTERNOON =
    Clock.fixed(Instant.parse("2026-09-23T06:00:00Z"), ZoneId.of("Asia/Seoul"));
  private static final LocalDateTime TODAY = LocalDateTime.of(2026, 9, 23, 10, 0);
  private static final LocalDateTime THIS_MONDAY = LocalDateTime.of(2026, 9, 21, 10, 0);
  private static final LocalDateTime LAST_SUNDAY_NIGHT = LocalDateTime.of(2026, 9, 20, 23, 59);

  @Mock
  private EntitlementService entitlementService;

  @Mock
  private AiCallLogRepository aiCallLogRepository;

  @Mock
  private RoutineRepository routineRepository;

  private RoutineQuotaGuard guard;

  /// 성공한 호출 기록 한 줄. 가짜 기록 표가 유형과 시각으로 거른다.
  private record Call(AiCallType type, LocalDateTime at) {
  }

  private final List<Call> callLog = new ArrayList<>();

  @BeforeEach
  void setUp() {
    guard = new RoutineQuotaGuard(
      entitlementService, aiCallLogRepository, routineRepository, WEDNESDAY_AFTERNOON
    );
    // 기록 표를 흉내 낸다. 가드가 넘긴 유형 목록에 들고 넘긴 시각 이후인 행만 센다 —
    // 실제 쿼리(call_type in (...) and created_at >= :from)와 같은 규칙이다.
    // 예전 목은 GEMINI_TEXT_CREATE 하나로 고정돼 있어서 가드가 무엇을 넘기든 같은 숫자를
    // 돌려줬고 제공자가 바뀐 경우를 잡지 못했다 (#367).
    lenient().when(aiCallLogRepository
        .countByMemberIdAndCallTypeInAndSuccessIsTrueAndCreatedAtGreaterThanEqual(
          eq(MEMBER_ID), anyCollection(), any(LocalDateTime.class)))
      .thenAnswer(invocation -> {
        Collection<AiCallType> counted = invocation.getArgument(1);
        LocalDateTime from = invocation.getArgument(2);
        return callLog.stream()
          .filter(call -> counted.contains(call.type()) && !call.at().isBefore(from))
          .count();
      });
    lenient().when(entitlementService.planOf(MEMBER_ID)).thenReturn(PlanType.FREE);
  }

  private void logged(int times, AiCallType type, LocalDateTime at) {
    for (int i = 0; i < times; i++) {
      callLog.add(new Call(type, at));
    }
  }

  /// 한도를 실제 판정 규칙(-1 은 무제한, 아니면 사용량 < 한도)대로 흉내 낸다.
  private void limits(int perDay, int perWeek) {
    limit(Entitlement.ROUTINE_CREATE_PER_DAY, perDay);
    limit(Entitlement.ROUTINE_CREATE_PER_WEEK, perWeek);
    limit(Entitlement.ROUTINE_MAX_COUNT, Entitlement.UNLIMITED);
  }

  private void limit(Entitlement entitlement, int value) {
    lenient().when(entitlementService.isWithinLimit(eq(PlanType.FREE), eq(entitlement), anyLong()))
      .thenAnswer(invocation ->
        value == Entitlement.UNLIMITED || (long) invocation.getArgument(2) < value);
  }

  private static void assertRejectedWith(Runnable call, ErrorCode expected) {
    assertThatThrownBy(call::run)
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode()).isEqualTo(expected));
  }

  // --- 주간 한도 ---

  @Test
  @DisplayName("한도 안이면 통과한다")
  void withinLimits_passes() {
    logged(2, AiCallType.GEMINI_TEXT_CREATE, TODAY);
    limits(3, 5);

    assertThatCode(() -> guard.guard(MEMBER_ID)).doesNotThrowAnyException();
  }

  @Test
  @DisplayName("이번 주 생성 한도를 넘으면 거부한다")
  void weeklyLimitExceeded_throws() {
    logged(5, AiCallType.GEMINI_TEXT_CREATE, THIS_MONDAY);
    limits(Entitlement.UNLIMITED, 5);

    assertRejectedWith(() -> guard.guard(MEMBER_ID), ErrorCode.ROUTINE_CREATE_LIMIT_EXCEEDED);
  }

  @Test
  @DisplayName("지난주 기록은 이번 주 사용량에 들지 않는다")
  void lastWeek_doesNotCountTowardWeekly() {
    logged(5, AiCallType.GEMINI_TEXT_CREATE, LAST_SUNDAY_NIGHT);
    limits(Entitlement.UNLIMITED, 5);

    assertThatCode(() -> guard.guard(MEMBER_ID)).doesNotThrowAnyException();
  }

  @Test
  @DisplayName("텍스트 제공자를 OpenAI 로 바꿔 만든 일과도 이번 주 사용량에 든다 (#367)")
  void openAiCreatedRoutines_countTowardWeeklyLimit() {
    logged(3, AiCallType.OPENAI_TEXT_CREATE, THIS_MONDAY);
    limits(Entitlement.UNLIMITED, 3);

    assertRejectedWith(() -> guard.guard(MEMBER_ID), ErrorCode.ROUTINE_CREATE_LIMIT_EXCEEDED);
  }

  @Test
  @DisplayName("주 중간에 제공자를 바꿔도 두 제공자 몫을 합쳐 센다 (#367)")
  void providerSwitchedMidWeek_sumsBothProviders() {
    logged(2, AiCallType.GEMINI_TEXT_CREATE, THIS_MONDAY);
    logged(1, AiCallType.OPENAI_TEXT_CREATE, THIS_MONDAY);
    limits(Entitlement.UNLIMITED, 3);

    assertRejectedWith(() -> guard.guard(MEMBER_ID), ErrorCode.ROUTINE_CREATE_LIMIT_EXCEEDED);
  }

  @Test
  @DisplayName("추가 질문·그림·민감정보 검사 호출은 일과 생성 횟수로 세지 않는다")
  void nonCreateCalls_doNotCount() {
    // 일과 1개를 만들면 질문·그림·검사 호출이 함께 쌓인다. 이것까지 세면 일과 하나에
    // 한도가 여러 칸 깎인다.
    logged(1, AiCallType.OPENAI_TEXT_CREATE, TODAY);
    for (AiCallType other : List.of(
      AiCallType.GEMINI_TEXT_QUESTION, AiCallType.OPENAI_TEXT_QUESTION,
      AiCallType.GEMINI_IMAGE, AiCallType.OPENAI_IMAGE, AiCallType.FLUX_IMAGE,
      AiCallType.LOCAL_LLM_DLP
    )) {
      logged(1, other, TODAY);
    }
    limits(2, 2);

    assertThatCode(() -> guard.guard(MEMBER_ID)).doesNotThrowAnyException();
  }

  // --- 하루 한도 (#368) ---

  @Test
  @DisplayName("오늘 생성 한도를 넘으면 하루 한도 코드로 거부한다")
  void dailyLimitExceeded_throws() {
    logged(3, AiCallType.GEMINI_TEXT_CREATE, TODAY);
    limits(3, Entitlement.UNLIMITED);

    assertRejectedWith(
      () -> guard.guard(MEMBER_ID), ErrorCode.ROUTINE_CREATE_DAILY_LIMIT_EXCEEDED);
  }

  @Test
  @DisplayName("이번 주 앞선 날의 기록은 오늘 사용량에 들지 않는다 — 하루 경계는 오늘 0시다")
  void earlierDaysThisWeek_doNotCountTowardDaily() {
    logged(5, AiCallType.GEMINI_TEXT_CREATE, THIS_MONDAY);
    limits(3, Entitlement.UNLIMITED);

    assertThatCode(() -> guard.guard(MEMBER_ID)).doesNotThrowAnyException();
  }

  @Test
  @DisplayName("하루 한도도 제공자를 가리지 않고 센다")
  void dailyLimit_countsEveryProvider() {
    logged(2, AiCallType.GEMINI_TEXT_CREATE, TODAY);
    logged(1, AiCallType.OPENAI_TEXT_CREATE, TODAY);
    limits(3, Entitlement.UNLIMITED);

    assertRejectedWith(
      () -> guard.guard(MEMBER_ID), ErrorCode.ROUTINE_CREATE_DAILY_LIMIT_EXCEEDED);
  }

  @Test
  @DisplayName("주간과 하루가 함께 찼으면 주간으로 알린다 — '내일 다시' 라고 하면 내일도 막힌다")
  void bothExhausted_reportsWeekly() {
    logged(3, AiCallType.GEMINI_TEXT_CREATE, TODAY);
    limits(3, 3);

    assertRejectedWith(() -> guard.guard(MEMBER_ID), ErrorCode.ROUTINE_CREATE_LIMIT_EXCEEDED);
  }

  // --- 보유 개수 · 실패 ---

  @Test
  @DisplayName("보유 개수 한도를 넘으면 거부한다")
  void ownedLimitExceeded_throws() {
    limits(Entitlement.UNLIMITED, Entitlement.UNLIMITED);
    when(routineRepository.countByProfileMemberId(MEMBER_ID)).thenReturn(3L);
    when(entitlementService.isWithinLimit(
      PlanType.FREE, Entitlement.ROUTINE_MAX_COUNT, 3L)).thenReturn(false);

    assertRejectedWith(() -> guard.guard(MEMBER_ID), ErrorCode.ROUTINE_COUNT_LIMIT_EXCEEDED);
  }

  @Test
  @DisplayName("사용량 집계가 실패해도 사용자를 막지 않는다 — 우리 DB 문제로 앱을 못 쓰면 안 된다")
  void usageQueryFails_passes() {
    lenient().when(aiCallLogRepository
        .countByMemberIdAndCallTypeInAndSuccessIsTrueAndCreatedAtGreaterThanEqual(
          anyString(), anyCollection(), any(LocalDateTime.class)))
      .thenThrow(new RuntimeException("DB 장애"));
    lenient().when(routineRepository.countByProfileMemberId(anyString()))
      .thenThrow(new RuntimeException("DB 장애"));
    // 한도가 0 이어도 — 집계를 못 했으면 막을 근거가 없다.
    limits(0, 0);

    assertThatCode(() -> guard.guard(MEMBER_ID)).doesNotThrowAnyException();
  }

  // --- 경계 ---

  @Test
  @DisplayName("주 시작은 이번 주 월요일 0시, 하루 시작은 오늘 0시다")
  void periodStarts() {
    assertThat(guard.weekStart()).isEqualTo(LocalDateTime.of(2026, 9, 21, 0, 0));
    assertThat(guard.dayStart()).isEqualTo(LocalDateTime.of(2026, 9, 23, 0, 0));
  }
}
