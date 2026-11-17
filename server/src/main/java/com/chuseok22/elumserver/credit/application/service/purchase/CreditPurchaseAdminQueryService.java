package com.chuseok22.elumserver.credit.application.service.purchase;

import com.chuseok22.elumserver.credit.core.CreditPurchaseStatus;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPurchase;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditPurchaseRepository;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import jakarta.persistence.criteria.Predicate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 관리자 크레딧 구매 목록 조회: 조건 3개(스토어, 상태, 거래 id·회원 id 일치) > 최근 구매부터 한 쪽
 */
@Service
@RequiredArgsConstructor
public class CreditPurchaseAdminQueryService {

  private final AiCreditPurchaseRepository purchaseRepository;

  @Transactional(readOnly = true)
  public Page<AiCreditPurchase> search(PurchaseFilter filter, Pageable pageable) {
    return purchaseRepository.findAll(specificationOf(filter), pageable);
  }

  /// 기간 안(since 이후) 새로 생긴 구매 건수
  @Transactional(readOnly = true)
  public long countCreatedSince(LocalDateTime since) {
    return purchaseRepository.count((root, query, builder) -> builder.greaterThanOrEqualTo(root.get("createdAt"), since));
  }

  /// 기간 안(since 이후) 환불로 처리된 구매 건수
  @Transactional(readOnly = true)
  public long countRefundedSince(LocalDateTime since) {
    return purchaseRepository.count((root, query, builder) -> builder.and(
      builder.equal(root.get("status"), CreditPurchaseStatus.REFUNDED),
      builder.greaterThanOrEqualTo(root.get("refundedAt"), since)));
  }

  // 빈 조건은 건너뜀 (검색어는 앞뒤 공백 제거 후 완전 일치)
  static Specification<AiCreditPurchase> specificationOf(PurchaseFilter filter) {
    return (root, query, builder) -> {
      List<Predicate> predicates = new ArrayList<>();
      if (filter.store() != null) {
        predicates.add(builder.equal(root.get("store"), filter.store()));
      }
      if (filter.status() != null) {
        predicates.add(builder.equal(root.get("status"), filter.status()));
      }
      if (filter.keyword() != null && !filter.keyword().isBlank()) {
        String keyword = filter.keyword().trim();
        predicates.add(builder.or(
          builder.equal(root.get("transactionId"), keyword), builder.equal(root.get("memberId"), keyword)));
      }
      return builder.and(predicates.toArray(Predicate[]::new));
    };
  }

  /// 목록 조건: null·빈 값이면 그 조건 없음
  public record PurchaseFilter(SubscriptionSource store, CreditPurchaseStatus status, String keyword) {

  }
}
