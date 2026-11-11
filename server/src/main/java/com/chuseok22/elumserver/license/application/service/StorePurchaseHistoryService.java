package com.chuseok22.elumserver.license.application.service;

import com.chuseok22.elumserver.license.infrastructure.entity.StorePurchaseEvent;
import com.chuseok22.elumserver.license.infrastructure.repository.StorePurchaseEventRepository;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 스토어 거래 이력 조회 (관리자 회원 상세, 읽기 전용). 기록은 StorePurchaseApplier 가 반영과 같은 트랜잭션에서
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class StorePurchaseHistoryService {

  private final StorePurchaseEventRepository storePurchaseEventRepository;

  /// 최신순, limit 이 0 이하면 빈 목록
  public List<StorePurchaseEvent> recentEventsOf(String memberId, int limit) {
    if (memberId == null || limit <= 0) {
      return List.of();
    }
    return storePurchaseEventRepository.findByMemberIdOrderByOccurredAtDesc(memberId, PageRequest.of(0, limit));
  }
}
