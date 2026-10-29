package com.chuseok22.elumserver.credit.application.service;

import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditJob;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditJobRepository;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 크레딧 작업 읽기: 다른 도메인 관리자 화면이 일과별 작업을 볼 때 쓴다 (읽기 전용, 잠금·정산 없음)
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CreditJobQueryService {

  /// 일과 하나에서 읽는 작업 최대 수 (저장소 메서드 이름의 Top50 과 같은 값)
  public static final int MAX_JOBS_PER_ROUTINE = 50;

  private final AiCreditJobRepository jobRepository;

  /// 일과 id > 그 일과로 만든 작업 최근 50건, 최신순. 일과 id 가 없으면 빈 목록
  public List<AiCreditJob> findRecentJobsOfRoutine(String routineId) {
    if (routineId == null || routineId.isBlank()) {
      return List.of();
    }
    return jobRepository.findTop50ByRoutineIdOrderByStartedAtDesc(routineId);
  }
}
