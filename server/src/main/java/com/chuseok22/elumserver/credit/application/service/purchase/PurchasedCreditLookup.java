package com.chuseok22.elumserver.credit.application.service.purchase;

import com.chuseok22.elumserver.credit.core.CreditGrantSource;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditGrantRepository;
import com.chuseok22.elumserver.license.application.service.PurchasedCreditChecker;
import java.time.Clock;
import java.time.LocalDateTime;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/// 구매 크레딧 남음 판정: 존재 여부 쿼리 하나 (내 정보 조회마다 불린다). 조회가 실패하면 구매분 없음으로
@Slf4j
@Component
public class PurchasedCreditLookup implements PurchasedCreditChecker {

  private final AiCreditGrantRepository grantRepository;
  private final Clock clock;

  @Autowired
  public PurchasedCreditLookup(AiCreditGrantRepository grantRepository) {
    this(grantRepository, Clock.systemDefaultZone());
  }

  PurchasedCreditLookup(AiCreditGrantRepository grantRepository, Clock clock) {
    this.grantRepository = grantRepository;
    this.clock = clock;
  }

  @Override
  @Transactional(readOnly = true)
  public boolean hasUsablePurchasedCredit(String memberId) {
    if (memberId == null || memberId.isBlank()) {
      return false;
    }
    try {
      return grantRepository.existsUsablePurchasedByMemberId(memberId, CreditGrantSource.PURCHASE, LocalDateTime.now(clock));
    } catch (RuntimeException e) {
      log.warn("[credit purchase] purchased credit lookup failed : {}", e.getClass().getSimpleName());
      return false;
    }
  }
}
