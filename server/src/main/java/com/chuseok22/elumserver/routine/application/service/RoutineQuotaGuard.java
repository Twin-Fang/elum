package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.time.Clock;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.TemporalAdjusters;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

/**
 * 요금제 한도를 일과 생성 길목에서 확인한다. {@code RoutineRequestCooldownGuard} 옆에 선다.
 *
 * <p>쿨다운이 "짧은 시간에 몰아치는 것"을 막는다면 여기는 "오늘·이번 주에 얼마나 썼는가"를
 * 본다. 하루 한도는 하루에 터지는 비용을, 주간 한도는 한 주 총량을 묶는다 (#368).
 * 둘 다 -1 이면 꺼진다.
 *
 * <p><b>집계가 실패하면 통과시킨다.</b> 우리 DB 문제로 사용자가 앱을 못 쓰면 안 된다.
 * 한도를 못 세서 조금 더 쓰이는 쪽이, 멀쩡한 사용자가 막히는 쪽보다 낫다.
 */
@Slf4j
@Component
public class RoutineQuotaGuard {

  private final EntitlementService entitlementService;
  private final AiCallLogRepository aiCallLogRepository;
  private final RoutineRepository routineRepository;
  /// 하루·주 경계를 정하는 시계. 테스트가 요일을 고정할 수 있게 밖에서 받는다.
  private final Clock clock;

  // 생성자가 둘이라 스프링이 쓸 것을 명시한다. 빠뜨리면 서버가 뜨지 않는다.
  @Autowired
  public RoutineQuotaGuard(
    EntitlementService entitlementService, AiCallLogRepository aiCallLogRepository,
    RoutineRepository routineRepository
  ) {
    this(entitlementService, aiCallLogRepository, routineRepository, Clock.systemDefaultZone());
  }

  RoutineQuotaGuard(
    EntitlementService entitlementService, AiCallLogRepository aiCallLogRepository,
    RoutineRepository routineRepository, Clock clock
  ) {
    this.entitlementService = entitlementService;
    this.aiCallLogRepository = aiCallLogRepository;
    this.routineRepository = routineRepository;
    this.clock = clock;
  }

  public void guard(String memberId) {
    // 플랜을 한 번만 읽어 모든 검사가 함께 쓴다. 검사마다 구독을 다시 조회하면
    // 일과 생성 한 번에 쿼리가 검사 수만큼 늘어난다.
    PlanType plan = entitlementService.planOf(memberId);
    // 주간을 먼저 본다. 주간이 다 찼는데 하루 한도로 거절하면 "내일 다시" 라고 안내하게
    // 되는데, 내일도 막힌다.
    guardCreateCount(memberId, plan, Entitlement.ROUTINE_CREATE_PER_WEEK, weekStart(),
      ErrorCode.ROUTINE_CREATE_LIMIT_EXCEEDED);
    guardCreateCount(memberId, plan, Entitlement.ROUTINE_CREATE_PER_DAY, dayStart(),
      ErrorCode.ROUTINE_CREATE_DAILY_LIMIT_EXCEEDED);
    guardOwnedCount(memberId, plan);
  }

  /**
   * {@code from} 이후 몇 개나 만들었는가. 하루·주간 한도가 기간만 바꿔 함께 쓴다.
   *
   * <p>일과 표가 아니라 AI 호출 기록을 센다. <b>일과를 지우면 행이 사라져 우회되기
   * 때문</b>이다 — 만들고 지우고 다시 만들면 보유 개수는 그대로인데 비용은 그때마다
   * 나간다. 호출 기록은 지워지지 않으므로 실제로 쓴 것을 센다.
   *
   * <p><b>제공자를 가리지 않고 센다.</b> 텍스트 제공자는 관리자 화면에서 바뀐다. 한 제공자
   * 유형만 세면 바꾸는 순간 사용량이 0 이 되어 한도가 풀린다 (#367).
   */
  private void guardCreateCount(
    String memberId, PlanType plan, Entitlement limit, LocalDateTime from, ErrorCode onExceeded
  ) {
    long used;
    try {
      used = aiCallLogRepository
        .countByMemberIdAndCallTypeInAndSuccessIsTrueAndCreatedAtGreaterThanEqual(
          memberId, AiCallType.routineCreateTypes(), from);
    } catch (Exception e) {
      log.warn("일과 생성 사용량 집계 실패 — 한도를 보지 않고 통과시킨다: memberId={}, limit={}",
        memberId, limit, e);
      return;
    }
    if (!entitlementService.isWithinLimit(plan, limit, used)) {
      log.info("일과 생성 한도 초과: memberId={}, limit={}, used={}", memberId, limit, used);
      throw new CustomException(onExceeded);
    }
  }

  private void guardOwnedCount(String memberId, PlanType plan) {
    long owned;
    try {
      owned = routineRepository.countByProfileMemberId(memberId);
    } catch (Exception e) {
      log.warn("보유 일과 집계 실패 — 한도를 보지 않고 통과시킨다: memberId={}", memberId, e);
      return;
    }
    if (!entitlementService.isWithinLimit(plan, Entitlement.ROUTINE_MAX_COUNT, owned)) {
      log.info("보유 일과 개수 한도 초과: memberId={}, owned={}", memberId, owned);
      throw new CustomException(ErrorCode.ROUTINE_COUNT_LIMIT_EXCEEDED);
    }
  }

  /**
   * 이번 주 월요일 0시.
   *
   * <p>타임존을 고정하지 않고 시스템 기본을 쓴다. 비교 대상인 {@code createdAt}이
   * {@code @CreatedDate}로 같은 기준에서 찍히기 때문이다 — 여기만 다른 타임존을 쓰면
   * 주 경계가 어긋난다.
   */
  LocalDateTime weekStart() {
    return LocalDate.now(clock)
      .with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
      .atStartOfDay();
  }

  /// 오늘 0시. 주 경계와 같은 시계를 쓴다 — 운영은 컨테이너 TZ=Asia/Seoul 이라 한국 시각 0시다.
  LocalDateTime dayStart() {
    return LocalDate.now(clock).atStartOfDay();
  }
}
