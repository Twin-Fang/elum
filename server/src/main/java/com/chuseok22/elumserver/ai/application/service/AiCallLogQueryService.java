package com.chuseok22.elumserver.ai.application.service;

import com.chuseok22.elumserver.ai.infrastructure.entity.AiCallLog;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import java.time.LocalDateTime;
import java.util.List;
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
}
