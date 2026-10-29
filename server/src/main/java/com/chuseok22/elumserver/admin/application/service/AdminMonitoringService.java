package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminDashboardSummary.TodayAiStats;
import com.chuseok22.elumserver.admin.application.list.AdminCsvExporter;
import com.chuseok22.elumserver.admin.application.list.AdminCsvExporter.ExportRows;
import com.chuseok22.elumserver.admin.application.list.AdminListPaging;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminMonitoringList;
import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.infrastructure.entity.AiCallLog;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository.AiCallStats;
import com.chuseok22.elumserver.auth.infrastructure.entity.AuthIdentity;
import com.chuseok22.elumserver.member.application.service.MemberService;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import jakarta.persistence.criteria.CriteriaBuilder;
import jakarta.persistence.criteria.CriteriaQuery;
import jakarta.persistence.criteria.Expression;
import jakarta.persistence.criteria.Predicate;
import jakarta.persistence.criteria.Root;
import jakarta.persistence.criteria.Subquery;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Objects;
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
  /// LIKE 이스케이프 문자 (AdminListQuery 패턴과 짝)
  private static final char LIKE_ESCAPE = '\\';

  private final AiCallLogRepository aiCallLogRepository;
  private final MemberService memberService;

  public AiCallStats getTodayStats() {
    return aiCallLogRepository.statsSince(LocalDate.now().atStartOfDay());
  }

  /// 대시보드용: 조회 투영을 값 복사본으로 (캐시에 오래 들고 있어도 안전)
  public TodayAiStats getTodayStatsSummary() {
    AiCallStats stats = getTodayStats();
    return new TodayAiStats(stats.getTotalCount(), stats.getSuccessCount(), stats.getTotalTokens(), stats.getTotalCostUsd());
  }

  public AiCallStats getTotalStats() {
    return aiCallLogRepository.statsSince(ALL_TIME_FROM);
  }

  /// 모니터링 목록: 기간[시작 포함, 종료 다음 날 0시 미포함] + 호출 유형·결과·회원·모델·오류 필터 + 허용 열 정렬 + 페이지 보정
  /// 값이 없는 필터는 조건에서 빠진다 (Specification 이라 enum null 바인딩 문제 없음)
  public Page<AiCallLog> search(AdminListQuery query) {
    Specification<AiCallLog> specification = specificationOf(query);
    return AdminListPaging.fetchWithPageCorrection(query,
      corrected -> aiCallLogRepository.findAll(specification, AdminMonitoringList.pageableOf(corrected)));
  }

  /// 모니터링 CSV: 목록과 같은 조건·정렬로 첫 쪽(상한 크기) 조회 > 상한을 넘으면 건수만
  public ExportRows<AiCallLog> searchForExport(AdminListQuery query) {
    return ExportRows.fromPage(aiCallLogRepository.findAll(specificationOf(query),
      AdminCsvExporter.exportPageable(AdminMonitoringList.sortOf(query))));
  }

  /// 호출 기록 > 회원 id 별 닉네임 (표에 원시 ID 대신 보임, 쿼리 1회, 닉네임 없거나 지운 회원은 빠짐)
  public Map<String, String> memberNicknamesOf(List<AiCallLog> calls) {
    List<String> memberIds = calls.stream().map(AiCallLog::getMemberId).filter(Objects::nonNull).distinct().toList();
    return memberService.nicknamesOf(memberIds);
  }

  private Specification<AiCallLog> specificationOf(AdminListQuery query) {
    AiCallType callType = AdminMonitoringList.callTypeOf(query);
    Boolean success = AdminMonitoringList.successOf(query);
    String memberId = AdminMonitoringList.memberIdOf(query);
    String memberKeyword = AdminMonitoringList.memberKeywordOf(query);
    String memberPattern = AdminMonitoringList.lowerLikePatternOf(query, AdminMonitoringList.FILTER_MEMBER);
    String modelPattern = AdminMonitoringList.lowerLikePatternOf(query, AdminMonitoringList.FILTER_MODEL);
    String errorPattern = AdminMonitoringList.lowerLikePatternOf(query, AdminMonitoringList.FILTER_ERROR_MESSAGE);
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
      if (modelPattern != null) {
        predicates.add(builder.like(builder.lower(root.<String>get("model")), modelPattern, LIKE_ESCAPE));
      }
      if (errorPattern != null) {
        predicates.add(builder.like(builder.lower(root.<String>get("errorMessage")), errorPattern, LIKE_ESCAPE));
      }
      if (memberPattern != null) {
        predicates.add(
          memberMatches(root.<String>get("memberId"), memberKeyword, memberPattern, criteriaQuery, builder));
      }
      return builder.and(predicates.toArray(new Predicate[0]));
    };
  }

  // 회원 검색 3가지 중 하나: 회원 ID 정확히 <-> 아이디·닉네임 일부 <-> 로그인 이메일 일부 (서브쿼리, 회원 수만큼 묻지 않음)
  private static Predicate memberMatches(
    Expression<String> memberIdColumn, String memberKeyword, String memberPattern,
    CriteriaQuery<?> criteriaQuery, CriteriaBuilder builder
  ) {
    Subquery<String> byAccount = criteriaQuery.subquery(String.class);
    Root<Member> member = byAccount.from(Member.class);
    byAccount.select(member.<String>get("id")).where(builder.or(
      builder.like(builder.lower(member.<String>get("username")), memberPattern, LIKE_ESCAPE),
      builder.like(builder.lower(member.<String>get("nickname")), memberPattern, LIKE_ESCAPE)));

    Subquery<String> byEmail = criteriaQuery.subquery(String.class);
    Root<AuthIdentity> identity = byEmail.from(AuthIdentity.class);
    byEmail.select(identity.<String>get("memberId"))
      .where(builder.like(builder.lower(identity.<String>get("email")), memberPattern, LIKE_ESCAPE));

    return builder.or(
      builder.equal(memberIdColumn, memberKeyword.strip()),
      memberIdColumn.in(byAccount),
      memberIdColumn.in(byEmail));
  }
}
