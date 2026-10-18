package com.chuseok22.elumserver.notice.infrastructure.repository;

import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * 게시 판단(기간·켜짐·플랫폼·순서)은 쿼리가 아니라 서비스의 자바 코드가 한다.
 *
 * <p>공지는 관리자가 손으로 올리는 몇십 건이라 앱 API 는 전부 읽어도 가볍다. 판단을 JPQL 에 두면
 * 이 저장소의 단위 테스트(목)로는 검증할 수 없고, 관리자 목록 배지와 앱 API 가 다른
 * 판단을 쓰게 된다. 쿼리는 관리자 목록의 검색·정렬·페이징만 맡는다.
 */
public interface AppNoticeRepository extends JpaRepository<AppNotice, String> {

  /**
   * 관리자 목록 검색: 제목·본문 검색
   * 검색어는 호출부가 {@code AdminListQuery.likePattern()} 으로 이스케이프해 넘김 (ESCAPE '\\')
   *
   * @param hasKeyword false 면 pattern 을 보지 않음
   */
  @Query(value = """
    select n from AppNotice n
    where (:hasKeyword = false
      or lower(n.title) like lower(:pattern) escape '\\'
      or lower(n.body) like lower(:pattern) escape '\\')
    """, countQuery = """
    select count(n) from AppNotice n
    where (:hasKeyword = false
      or lower(n.title) like lower(:pattern) escape '\\'
      or lower(n.body) like lower(:pattern) escape '\\')
    """)
  Page<AppNotice> searchForAdmin(
    @Param("hasKeyword") boolean hasKeyword, @Param("pattern") String pattern, Pageable pageable);
}
