package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.infrastructure.entity.AiCallLog;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository.AiCallStats;
import java.time.LocalDate;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AdminMonitoringService {

  private static final int PAGE_SIZE = 50;
  // 전체 누적 통계용 하한 — 서비스 개시(2026년) 이전이면 충분하다.
  private static final LocalDateTime ALL_TIME_FROM = LocalDateTime.of(2000, 1, 1, 0, 0);

  private final AiCallLogRepository aiCallLogRepository;

  public AiCallStats getTodayStats() {
    return aiCallLogRepository.statsSince(LocalDate.now().atStartOfDay());
  }

  public AiCallStats getTotalStats() {
    return aiCallLogRepository.statsSince(ALL_TIME_FROM);
  }

  // callType/success 필터 조합에 따라 파생 쿼리를 선택한다. JPQL의 ":param is null"
  // 방식은 PostgreSQL enum 바인딩에서 타입 추론 문제가 있어 피했다.
  public Page<AiCallLog> getCalls(AiCallType callType, Boolean success, int page) {
    Pageable pageable = PageRequest.of(Math.max(page, 0), PAGE_SIZE, Sort.by(Sort.Direction.DESC, "createdAt"));
    if (callType != null && success != null) {
      return aiCallLogRepository.findByCallTypeAndSuccess(callType, success, pageable);
    }
    if (callType != null) {
      return aiCallLogRepository.findByCallType(callType, pageable);
    }
    if (success != null) {
      return aiCallLogRepository.findBySuccess(success, pageable);
    }
    return aiCallLogRepository.findAll(pageable);
  }
}
