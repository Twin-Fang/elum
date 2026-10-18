package com.chuseok22.elumserver.feedback.infrastructure.repository;

import com.chuseok22.elumserver.feedback.infrastructure.entity.Feedback;
import java.time.LocalDateTime;
import java.util.Collection;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import com.chuseok22.elumserver.feedback.core.FeedbackStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface FeedbackRepository extends JpaRepository<Feedback, String> {

  /// 회원이 since 이후 보낸 건수. 하루 상한 판정에 쓴다.
  long countByMemberIdAndCreatedAtGreaterThanEqual(String memberId, LocalDateTime since);

  /// 계정을 완전히 지울 때 그 회원의 의견과 앱 상태 기록을 함께 지운다.
  void deleteAllByMemberId(String memberId);

  /**
   * 관리자 목록 검색: 처리 상태 필터, 의견 본문·회원 id 검색
   * 검색어는 호출부가 {@code AdminListQuery.likePattern()} 으로 이스케이프해 넘김 (ESCAPE '\\')
   *
   * @param hasKeyword false 면 pattern 을 보지 않음
   * @param statuses   보여줄 상태 (필터 없으면 전체)
   */
  @Query(value = """
    select f from Feedback f
    where f.status in :statuses
      and (:hasKeyword = false
        or lower(f.message) like lower(:pattern) escape '\\'
        or lower(f.memberId) like lower(:pattern) escape '\\')
    """, countQuery = """
    select count(f) from Feedback f
    where f.status in :statuses
      and (:hasKeyword = false
        or lower(f.message) like lower(:pattern) escape '\\'
        or lower(f.memberId) like lower(:pattern) escape '\\')
    """)
  Page<Feedback> searchForAdmin(
    @Param("hasKeyword") boolean hasKeyword, @Param("pattern") String pattern,
    @Param("statuses") Collection<FeedbackStatus> statuses, Pageable pageable);
}
