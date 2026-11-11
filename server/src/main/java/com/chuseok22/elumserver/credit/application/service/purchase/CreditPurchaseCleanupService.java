package com.chuseok22.elumserver.credit.application.service.purchase;

import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditPurchaseRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 회원 완전 삭제 때 크레딧 구매 기록 정리: 행은 남기고 회원 식별자만 뗌
 * 구매 행은 크레딧 계정에 묶인 결제 기록이자 같은 거래의 두 번 적립을 막는 열쇠
 */
@Service
@RequiredArgsConstructor
public class CreditPurchaseCleanupService {

  private final AiCreditPurchaseRepository aiCreditPurchaseRepository;

  @Transactional
  public void detachMemberOf(String memberId) {
    aiCreditPurchaseRepository.detachMember(memberId);
  }
}
