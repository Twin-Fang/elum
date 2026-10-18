package com.chuseok22.elumserver.license.application.service;

import com.chuseok22.elumserver.license.infrastructure.entity.SubscriptionHistory;
import com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionHistoryRepository;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 요금제 이력 조회: 회원별 최근 이력, 회원 여러 명의 마지막 변경
 * 기록은 SubscriptionService 가 상태 변경과 같은 트랜잭션에서 하므로 여기에는 쓰기가 없음
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class SubscriptionHistoryService {

  private final SubscriptionHistoryRepository subscriptionHistoryRepository;

  /// 최신순 이력, limit 이 0 이하면 빈 목록
  public List<SubscriptionHistory> recent(String memberId, int limit) {
    if (limit <= 0) {
      return List.of();
    }
    return subscriptionHistoryRepository.findByMemberIdOrderByChangedAtDesc(memberId, PageRequest.of(0, limit));
  }

  /// 회원 id > 가장 최근 변경 한 건 (이력이 없는 회원은 키가 없음)
  public Map<String, SubscriptionHistory> latestByMemberIds(Collection<String> memberIds) {
    if (memberIds.isEmpty()) {
      return Map.of();
    }
    return subscriptionHistoryRepository.findLatestByMemberIds(memberIds).stream()
      .collect(Collectors.toMap(SubscriptionHistory::getMemberId, Function.identity(), (first, later) -> first));
  }
}
