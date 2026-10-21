package com.chuseok22.elumserver.notice.infrastructure.repository;

import com.chuseok22.elumserver.notice.core.NoticePlatform;
import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import java.time.LocalDateTime;
import java.util.Collection;
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
   * 관리자 목록 검색: 제목·본문 검색, 대상 플랫폼, 게시 기간이 [periodFrom, periodToExclusive) 와 겹치는 공지
   * 검색어는 호출부가 {@code AdminListQuery.likePattern()} 으로 이스케이프해 넘김 (ESCAPE '\\')
   * 게시 상태(예약·게시 중·끝남·꺼짐)는 여기서 거르지 않는다 — 서비스가 statusAt 으로 판단
   *
   * @param hasKeyword false 면 pattern 을 보지 않음
   * @param platforms  보여줄 대상 플랫폼 (필터 없으면 전체)
   * @param periodFrom 기간 시작(포함). 필터가 없으면 아주 이른 날 (null 바인딩을 피하려고 늘 값을 넣음)
   */
  @Query(value = """
    select n from AppNotice n
    where (:hasKeyword = false
      or lower(n.title) like lower(:pattern) escape '\\'
      or lower(n.body) like lower(:pattern) escape '\\')
      and n.platform in :platforms
      and n.startsAt < :periodToExclusive
      and (n.endsAt is null or n.endsAt > :periodFrom)
    """, countQuery = """
    select count(n) from AppNotice n
    where (:hasKeyword = false
      or lower(n.title) like lower(:pattern) escape '\\'
      or lower(n.body) like lower(:pattern) escape '\\')
      and n.platform in :platforms
      and n.startsAt < :periodToExclusive
      and (n.endsAt is null or n.endsAt > :periodFrom)
    """)
  Page<AppNotice> searchForAdmin(
    @Param("hasKeyword") boolean hasKeyword, @Param("pattern") String pattern,
    @Param("platforms") Collection<NoticePlatform> platforms,
    @Param("periodFrom") LocalDateTime periodFrom, @Param("periodToExclusive") LocalDateTime periodToExclusive,
    Pageable pageable);
}
