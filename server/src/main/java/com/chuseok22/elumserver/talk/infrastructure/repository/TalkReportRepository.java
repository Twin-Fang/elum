package com.chuseok22.elumserver.talk.infrastructure.repository;

import com.chuseok22.elumserver.talk.core.TalkReportTargetType;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkReport;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface TalkReportRepository extends JpaRepository<TalkReport, String> {

  boolean existsByTargetTypeAndTargetIdAndReporterMemberId(
    TalkReportTargetType targetType, String targetId, String reporterMemberId);

  // 관리자 신고 목록: 처리 상태별 (전체는 findAll(Pageable))
  Page<TalkReport> findByResolvedAtIsNull(Pageable pageable);

  Page<TalkReport> findByResolvedAtIsNotNull(Pageable pageable);

  // 사이드 메뉴 배지: 아직 처리하지 않은 신고 수
  long countByResolvedAtIsNull();

  // 글 상세: 그 글과 댓글에 들어온 신고, 최근 순
  List<TalkReport> findByPostIdOrderByCreatedAtDescIdAsc(String postId);

  // 글 목록: 글별 미처리 신고 수 (행: postId, 건수)
  @Query("select r.postId, count(r) from TalkReport r where r.postId in :postIds and r.resolvedAt is null "
    + "group by r.postId")
  List<Object[]> countUnresolvedByPostIds(@Param("postIds") Collection<String> postIds);

  // 처리: 미처리일 때만 시각을 기록 (바꾼 건수: 이미 처리했으면 0, 처음 시각이 유지됨)
  @Transactional
  @Modifying(flushAutomatically = true)
  @Query("update TalkReport r set r.resolvedAt = :resolvedAt where r.id = :reportId and r.resolvedAt is null")
  int markResolvedIfUnresolved(@Param("reportId") String reportId, @Param("resolvedAt") LocalDateTime resolvedAt);

  // 탈퇴 정리: 그 회원이 한 신고, 그 회원의 글(글·그 글의 댓글 신고 모두)에 대한 신고, 그 회원의 댓글에 대한 신고
  @Transactional
  @Modifying(flushAutomatically = true)
  @Query("delete from TalkReport r where r.reporterMemberId = :memberId "
    + "or r.postId in (select p.id from TalkPost p where p.authorMemberId = :memberId) "
    + "or (r.targetType = com.chuseok22.elumserver.talk.core.TalkReportTargetType.COMMENT and r.targetId in "
    + "(select c.id from TalkComment c where c.authorMemberId = :memberId))")
  int deleteAllInvolving(@Param("memberId") String memberId);
}
