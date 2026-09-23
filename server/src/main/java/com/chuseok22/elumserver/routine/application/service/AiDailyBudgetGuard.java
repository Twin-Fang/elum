package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

/**
 * 서비스 전체가 오늘 AI 에 쓴 추정 비용이 상한에 닿았는지 본다 (#368).
 *
 * <p>계정별 한도는 계정을 여러 개 만드는 악용을 못 막고, 회원 없이 남는 호출(관리자 프롬프트
 * 시험 등)은 아예 세지 못한다. 여기는 누가 썼든 오늘 전체 합계를 본다 — 우리 코드 안의
 * 마지막 장치다.
 *
 * <p><b>집계가 실패하면 통과시킨다.</b> 계정 한도({@link RoutineQuotaGuard})와 같은 방침이다.
 * 막는 쪽을 고르면 DB 문제 하나로 모든 보호자가 일과를 못 만든다(서비스 원칙 6). 통과시키는
 * 동안 비용 상한은 꺼지지만 쿨다운·계정 한도·제공자 쪽 예산은 남는다. 대신 warn 로그를 남겨
 * 알아챌 수 있게 한다.
 *
 * <p>비용은 호출 기록의 추정치라 실제 청구와 다를 수 있다. 이미 진행 중인 생성은 끊지 않으므로
 * 동시에 들어온 요청만큼 상한을 조금 넘길 수 있다.
 */
@Slf4j
@Component
public class AiDailyBudgetGuard {

  /// 상한을 두지 않는다는 뜻. 기본값이다.
  static final double OFF = -1;

  private final AiCallLogRepository aiCallLogRepository;
  private final SystemConfigService systemConfigService;
  /// 하루 경계를 정하는 시계. 테스트가 자정 근처를 고정할 수 있게 밖에서 받는다.
  private final Clock clock;

  // 생성자가 둘이라 스프링이 쓸 것을 명시한다. 빠뜨리면 서버가 뜨지 않는다.
  @Autowired
  public AiDailyBudgetGuard(
    AiCallLogRepository aiCallLogRepository, SystemConfigService systemConfigService
  ) {
    this(aiCallLogRepository, systemConfigService, Clock.systemDefaultZone());
  }

  AiDailyBudgetGuard(
    AiCallLogRepository aiCallLogRepository, SystemConfigService systemConfigService, Clock clock
  ) {
    this.aiCallLogRepository = aiCallLogRepository;
    this.systemConfigService = systemConfigService;
    this.clock = clock;
  }

  /** 새 일과를 만들기 전에 부른다. 상한에 닿았으면 AI 를 부르기 전에 거절한다. */
  public void guard() {
    if (isReached()) {
      throw new CustomException(ErrorCode.AI_DAILY_BUDGET_EXCEEDED);
    }
  }

  /** 오늘 쓴 추정 비용이 상한에 닿았는가. 꺼져 있거나 집계를 못 하면 false. */
  public boolean isReached() {
    double budget = systemConfigService.getDouble(ConfigKey.AI_DAILY_BUDGET_USD);
    if (budget == OFF) {
      return false;
    }
    // -1 말고 음수나 숫자가 아닌 값은 뜻이 없다. 잘못 넣은 값 하나로 모든 생성이 멈추지
    // 않도록 끈 것으로 본다 — 계정 한도의 이상한 음수와 같은 처리다.
    if (Double.isNaN(budget) || budget < 0) {
      log.warn("알 수 없는 AI 하루 비용 상한 — 끈 것으로 본다: value={}", budget);
      return false;
    }
    double spent;
    try {
      // 관리자 모니터링이 쓰는 기간 합계 쿼리를 그대로 쓴다. 이미 운영에서 도는 쿼리라
      // 새 JPQL 을 더하지 않는다 — 오타가 있으면 서버가 뜨지 않는데 그걸 잡을 테스트가 없다.
      // created_at 인덱스(idx_ai_call_log_created)를 탄다.
      spent = aiCallLogRepository.statsSince(todayStart()).getTotalCostUsd();
    } catch (Exception e) {
      log.warn("오늘 AI 비용 집계 실패 — 상한을 보지 않고 통과시킨다", e);
      return false;
    }
    if (spent >= budget) {
      log.warn("AI 하루 비용 상한 도달 — 새 AI 생성을 멈춘다: spentUsd={}, budgetUsd={}", spent, budget);
      return true;
    }
    return false;
  }

  /// 오늘 0시. 계정 한도와 같은 시스템 시계다 — 운영은 컨테이너 TZ=Asia/Seoul 이라 한국 시각
  /// 0시이고, 비교 대상인 created_at 도 같은 시계로 찍힌다.
  LocalDateTime todayStart() {
    return LocalDate.now(clock).atStartOfDay();
  }
}
