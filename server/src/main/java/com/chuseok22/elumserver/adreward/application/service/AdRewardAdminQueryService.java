package com.chuseok22.elumserver.adreward.application.service;

import com.chuseok22.elumserver.adreward.application.dto.response.AdRewardSessionAdminView;
import com.chuseok22.elumserver.adreward.application.dto.response.AdRewardStatusSummary;
import com.chuseok22.elumserver.adreward.core.AdRewardStatus;
import com.chuseok22.elumserver.adreward.infrastructure.entity.AdRewardSession;
import com.chuseok22.elumserver.adreward.infrastructure.repository.AdRewardSessionRepository;
import com.chuseok22.elumserver.adreward.infrastructure.repository.AdRewardSessionRepository.StatusCount;
import jakarta.persistence.criteria.CriteriaBuilder;
import jakarta.persistence.criteria.Predicate;
import jakarta.persistence.criteria.Root;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 광고 보상 세션 관리자 조회: 목록 검색, 한 건, 기간 상태 요약 (읽기 전용)
 * 콜백 없이 지난 PENDING 은 저장 상태를 바꾸지 않고 보이는 상태만 EXPIRED 로 본다
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AdRewardAdminQueryService {

  private final AdRewardSessionRepository sessionRepository;

  /// 세션 목록 한 쪽: 조건 > Specification, 정렬·페이지는 호출부가 정함
  public Page<AdRewardSessionAdminView> search(AdRewardSessionSearch search, Pageable pageable) {
    if (search.memberIds() != null && search.memberIds().isEmpty()) {
      return Page.empty(pageable);
    }
    return sessionRepository.findAll(specificationOf(search), pageable)
      .map(session -> AdRewardSessionAdminView.of(session, search.now()));
  }

  public Optional<AdRewardSessionAdminView> find(String sessionId, LocalDateTime now) {
    return sessionRepository.findById(sessionId).map(session -> AdRewardSessionAdminView.of(session, now));
  }

  /// 기간[from, to) 에 만든 세션 요약: 저장 상태별 건수 > 콜백 없이 지난 PENDING 을 만료로 옮김 > 지급 크레딧 합
  public AdRewardStatusSummary summarize(LocalDateTime from, LocalDateTime to, LocalDateTime now) {
    Map<AdRewardStatus, Long> countByStatus = new EnumMap<>(AdRewardStatus.class);
    for (StatusCount row : sessionRepository.countByStatusCreatedBetween(from, to)) {
      countByStatus.put(row.getStatus(), row.getSessionCount());
    }
    long stalePending = sessionRepository.countStalePendingCreatedBetween(from, to, now);
    long storedPending = countByStatus.getOrDefault(AdRewardStatus.PENDING, 0L);
    return new AdRewardStatusSummary(
      countByStatus.getOrDefault(AdRewardStatus.GRANTED, 0L),
      countByStatus.getOrDefault(AdRewardStatus.REJECTED, 0L),
      Math.max(0, storedPending - stalePending),
      countByStatus.getOrDefault(AdRewardStatus.EXPIRED, 0L) + stalePending,
      sessionRepository.sumGrantedCreditsCreatedBetween(from, to));
  }

  // 조건 4개: 만든 기간(필수), 회원, 보이는 상태, 거절 사유 (값 없는 조건은 빠짐)
  private static Specification<AdRewardSession> specificationOf(AdRewardSessionSearch search) {
    return (root, criteriaQuery, builder) -> {
      List<Predicate> predicates = new ArrayList<>();
      predicates.add(builder.greaterThanOrEqualTo(root.get("createdAt"), search.from()));
      predicates.add(builder.lessThan(root.get("createdAt"), search.to()));
      if (search.memberIds() != null) {
        predicates.add(root.get("memberId").in(search.memberIds()));
      }
      if (search.effectiveStatus() != null) {
        predicates.add(effectiveStatusPredicate(root, builder, search.effectiveStatus(), search.now()));
      }
      if (search.rejectReason() != null) {
        predicates.add(builder.equal(root.get("rejectReason"), search.rejectReason()));
      }
      return builder.and(predicates.toArray(new Predicate[0]));
    };
  }

  // 보이는 상태 > 조건: PENDING 은 아직 유효, EXPIRED 는 저장 EXPIRED 또는 유효 시간 지난 PENDING
  private static Predicate effectiveStatusPredicate(
    Root<AdRewardSession> root, CriteriaBuilder builder, AdRewardStatus status, LocalDateTime now
  ) {
    Predicate isStoredPending = builder.equal(root.get("status"), AdRewardStatus.PENDING);
    return switch (status) {
      case PENDING -> builder.and(isStoredPending, builder.greaterThan(root.get("expiresAt"), now));
      case EXPIRED -> builder.or(
        builder.equal(root.get("status"), AdRewardStatus.EXPIRED),
        builder.and(isStoredPending, builder.lessThanOrEqualTo(root.get("expiresAt"), now)));
      default -> builder.equal(root.get("status"), status);
    };
  }
}
