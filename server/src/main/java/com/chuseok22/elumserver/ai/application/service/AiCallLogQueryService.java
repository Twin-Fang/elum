package com.chuseok22.elumserver.ai.application.service;

import com.chuseok22.elumserver.ai.application.dto.response.AiCreditJobCallSummary;
import com.chuseok22.elumserver.ai.infrastructure.entity.AiCallLog;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * AI 호출 기록 읽기: 다른 도메인 관리자 화면이 회원별 호출을 볼 때 쓴다 (읽기 전용)
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AiCallLogQueryService {

  private final AiCallLogRepository aiCallLogRepository;

  /// 회원 id + 기준 시각 > 기준 시각 이전(포함) 최근 호출 10건, 최신순. 회원 id 가 없으면 빈 목록
  public List<AiCallLog> findRecentCallsOfMemberUntil(String memberId, LocalDateTime until) {
    if (memberId == null || memberId.isBlank() || until == null) {
      return List.of();
    }
    return aiCallLogRepository.findTop10ByMemberIdAndCreatedAtLessThanEqualOrderByCreatedAtDesc(memberId, until);
  }

  /// 크레딧 작업 id 목록 > 작업 id 별 호출 요약 (쿼리 1회, 호출이 없는 작업은 빠짐). 목록이 비면 빈 맵
  public Map<String, AiCreditJobCallSummary> summarizeCallsByCreditJob(Collection<String> creditJobIds) {
    if (creditJobIds == null || creditJobIds.isEmpty()) {
      return Map.of();
    }
    return aiCallLogRepository.sumCostByCreditJobIds(creditJobIds).stream()
      .map(cost -> new AiCreditJobCallSummary(
        cost.getCreditJobId(), cost.getCallCount(), cost.getSuccessCount(), cost.getTotalCostUsd()))
      .collect(Collectors.toMap(AiCreditJobCallSummary::creditJobId, summary -> summary, (first, second) -> first));
  }
}
