package com.chuseok22.elumserver.credit.application.service;

import com.chuseok22.elumserver.credit.core.CreditAction;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditJob;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;

/**
 * 일과 생성 글 무료 몫 (#1110): 권한(ROUTINE_CREATE_FREE) 판정, 시작 단가(글만 0), 예약 행동, 무료 글 작업 판정
 * 카드 그림은 장수 × 그림 단가 그대로 청구. CreditReservationService 가 만들어 씀
 */
class CreditFreeRoutineTextAllowance {

  /// 일과 생성 글 무료 사용 줄의 사유 (관리자 원장용)
  static final String FREE_ROUTINE_TEXT_REASON = "일과 생성 글 무료 (요금제 권한)";

  private final EntitlementService entitlementService;

  CreditFreeRoutineTextAllowance(EntitlementService entitlementService) {
    this.entitlementService = entitlementService;
  }

  /// 이 작업이 글 무료 대상인가: 일과 생성 + 권한 켜짐 (번역 등 다른 종류는 아님)
  boolean isRoutineTextFree(AiCreditAccount account, CreditJobKind kind) {
    return kind == CreditJobKind.ROUTINE_CREATE && hasFreeRoutineTextEntitlement(account);
  }

  /**
   * 일과 생성을 시작하려면 있어야 하는 사용 가능량 (예약량과 같은 계산): 글 단가, 글 무료 권한이면 그림 한 장 단가
   * 크레딧 요약의 "시작 가능"과 추가 질문 막기가 예약과 같은 기준을 씀
   */
  int routineCreateStartCost(AiCreditAccount account, AiCreditPolicy policy) {
    return policy.costOf(holdActionOf(CreditJobKind.ROUTINE_CREATE, hasFreeRoutineTextEntitlement(account)));
  }

  /**
   * 예약량을 정하는 행동: 보통은 CreditJobCharges.reserveAction, 글 무료면 그림 한 장 단가
   * (글 단가 0 으로 예약하면 잔액 0 에서도 시작해 그림 전부가 초과로 빠져 청구되지 않음)
   */
  static CreditAction holdActionOf(CreditJobKind kind, boolean isRoutineTextFree) {
    return isRoutineTextFree ? CreditAction.CARD_IMAGE : CreditJobCharges.reserveAction(kind);
  }

  /// 시작 때 글 단가가 0 인 일과 생성 작업인가 (글 무료 권한 또는 정책 글 단가 0)
  static boolean isFreeRoutineTextJob(AiCreditJob job) {
    return job.getKind() == CreditJobKind.ROUTINE_CREATE
      && AiCreditPolicy.costFrom(job.getCostSnapshot(), CreditAction.ROUTINE_TEXT) == 0;
  }

  private boolean hasFreeRoutineTextEntitlement(AiCreditAccount account) {
    String memberId = account.getMemberId();
    return memberId != null && entitlementService.isAllowed(memberId, Entitlement.ROUTINE_CREATE_FREE);
  }
}
