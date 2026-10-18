package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.list.AdminListPaging;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminMonitoringList;
import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.infrastructure.entity.AiCallLog;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository.AiCallStats;
import jakarta.persistence.criteria.Predicate;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AdminMonitoringService {

  // 전체 누적 통계용 하한 — 서비스 개시(2026년) 이전이면 충분하다.
  private static final LocalDateTime ALL_TIME_FROM = LocalDateTime.of(2000, 1, 1, 0, 0);

  private final AiCallLogRepository aiCallLogRepository;

  public AiCallStats getTodayStats() {
    return aiCallLogRepository.statsSince(LocalDate.now().atStartOfDay());
  }

  public AiCallStats getTotalStats() {
    return aiCallLogRepository.statsSince(ALL_TIME_FROM);
  }

  /// 모니터링 목록: 기간[시작 포함, 종료 다음 날 0시 미포함] + 호출 유형·결과·회원 필터 + 허용 열 정렬 + 페이지 보정
  /// 값이 없는 필터는 조건에서 빠진다 (Specification 이라 enum null 바인딩 문제 없음)
  public Page<AiCallLog> search(AdminListQuery query) {
    Specification<AiCallLog> specification = specificationOf(query);
    return AdminListPaging.fetchWithPageCorrection(query,
      corrected -> aiCallLogRepository.findAll(specification, AdminMonitoringList.pageableOf(corrected)));
  }

  private Specification<AiCallLog> specificationOf(AdminListQuery query) {
    AiCallType callType = AdminMonitoringList.callTypeOf(query);
    Boolean success = AdminMonitoringList.successOf(query);
    String memberId = AdminMonitoringList.memberIdOf(query);
    LocalDateTime periodStart = AdminMonitoringList.periodStart(query);
    LocalDateTime periodEnd = AdminMonitoringList.periodEndExclusive(query);
    return (root, criteriaQuery, builder) -> {
      List<Predicate> predicates = new ArrayList<>();
      predicates.add(builder.greaterThanOrEqualTo(root.get("createdAt"), periodStart));
      predicates.add(builder.lessThan(root.get("createdAt"), periodEnd));
      if (callType != null) {
        predicates.add(builder.equal(root.get("callType"), callType));
      }
      if (success != null) {
        predicates.add(builder.equal(root.get("success"), success));
      }
      if (memberId != null) {
        predicates.add(builder.equal(root.get("memberId"), memberId));
      }
      return builder.and(predicates.toArray(new Predicate[0]));
    };
  }
}
