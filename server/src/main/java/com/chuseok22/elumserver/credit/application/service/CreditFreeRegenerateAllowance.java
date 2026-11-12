package com.chuseok22.elumserver.credit.application.service;

import com.chuseok22.elumserver.credit.core.CreditAction;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.credit.core.CreditJobStatus;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditJob;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditJobRepository;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.systemconfig.application.service.UsageLimitSettings;
import java.time.LocalDateTime;
import java.util.List;
import lombok.extern.slf4j.Slf4j;

/**
 * 무료 다시 그리기 몫 (#1075): 오늘 남은 횟수, 시작 단가(무료면 다시 그리기만 0), 무료 작업 판정
 * 권한(IMAGE_REGENERATE_FREE) + 하루 한도(IMAGE_REGENERATE_FREE_DAILY_CAP). CreditReservationService 가 만들어 씀
 */
@Slf4j
class CreditFreeRegenerateAllowance {

  /// 무료 다시 그리기 사용 줄의 사유 (보호자 내역에는 안 보임, 관리자 원장용)
  static final String FREE_REGENERATE_REASON = "무료 다시 그리기 (요금제 권한)";
  /// 무료 다시 그리기 하루 횟수에 드는 작업 상태 (반환·만료는 그림을 못 받았으니 제외)
  private static final List<CreditJobStatus> FREE_REGENERATE_COUNTED_STATUSES =
    List.of(CreditJobStatus.RESERVED, CreditJobStatus.SETTLED);

  private final EntitlementService entitlementService;
  private final AiCreditJobRepository jobRepository;
  private final UsageLimitSettings usageLimitSettings;

  CreditFreeRegenerateAllowance(
    EntitlementService entitlementService, AiCreditJobRepository jobRepository, UsageLimitSettings usageLimitSettings
  ) {
    this.entitlementService = entitlementService;
    this.jobRepository = jobRepository;
    this.usageLimitSettings = usageLimitSettings;
  }

  /**
   * 시작 때 단가 JSON: 정책 단가 그대로, 무료 다시 그리기 대상이면 IMAGE_REGENERATE 만 0
   */
  String costSnapshotFor(AiCreditAccount account, CreditJobKind kind, AiCreditPolicy policy, LocalDateTime now) {
    if (kind != CreditJobKind.IMAGE_REGENERATE || !isFreeRegenerateAvailable(account, now)) {
      return policy.getActionCostsJson();
    }
    return policy.actionCostsJsonWithFree(CreditAction.IMAGE_REGENERATE);
  }

  /**
   * 무료 다시 그리기 가능 여부: 오늘 남은 무료 횟수 > 0
   * 계정 행 잠금 안에서 세므로 동시 요청이 한도를 넘지 않음
   */
  private boolean isFreeRegenerateAvailable(AiCreditAccount account, LocalDateTime now) {
    boolean isAvailable = freeRegeneratesLeftToday(account, now) > 0;
    if (!isAvailable && hasFreeRegenerateEntitlement(account)) {
      log.info("[credit free regenerate] daily cap reached, normal cost applies: accountId={}", account.getId());
    }
    return isAvailable;
  }

  /**
   * 오늘 남은 무료 다시 그리기 횟수: 권한(IMAGE_REGENERATE_FREE) 없음·한도 0 이면 0, 아니면 한도 − 오늘 쓴 무료 횟수
   * 반환·만료된 작업은 세지 않음. 크레딧 요약(앱 확인 시트)과 예약이 같은 계산을 씀
   */
  int freeRegeneratesLeftToday(AiCreditAccount account, LocalDateTime now) {
    if (!hasFreeRegenerateEntitlement(account)) {
      return 0;
    }
    int dailyCap = dailyCap();
    if (dailyCap <= 0) {
      return 0;
    }
    long usedToday = jobRepository.countByAccountIdAndKindAndReservedAndStatusInAndStartedAtGreaterThanEqual(
      account.getId(), CreditJobKind.IMAGE_REGENERATE, 0, FREE_REGENERATE_COUNTED_STATUSES,
      now.toLocalDate().atStartOfDay());
    return (int) Math.max(0, dailyCap - usedToday);
  }

  /// 무료 다시 그리기 하루 한도 설정값 (음수는 0)
  int dailyCap() {
    return Math.max(0, usageLimitSettings.imageRegenerateFreeDailyCap());
  }

  private boolean hasFreeRegenerateEntitlement(AiCreditAccount account) {
    String memberId = account.getMemberId();
    return memberId != null && entitlementService.isAllowed(memberId, Entitlement.IMAGE_REGENERATE_FREE);
  }

  /// 시작 때 다시 그리기 단가가 0 이고 그림을 실제로 그린 다시 그리기 작업인가
  static boolean isFreeRegenerateJob(AiCreditJob job, int imageCount) {
    return job.getKind() == CreditJobKind.IMAGE_REGENERATE && imageCount > 0
      && AiCreditPolicy.costFrom(job.getCostSnapshot(), CreditAction.IMAGE_REGENERATE) == 0;
  }
}
