package com.chuseok22.elumserver.admin.application.list;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.feedback.application.service.FeedbackService;
import com.chuseok22.elumserver.feedback.core.FeedbackStatus;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

/** 공지·의견 목록 선언: 허용 정렬만 통과, 그 밖은 기본 정렬, 필터 보정, 검색 패턴 이스케이프, 페이지 보정 */
class AdminNoticeFeedbackListTest {

  private static AdminListQuery noticeQuery(String q, String sort, String page) {
    return AdminListQuery.of(q, Map.of(), sort, page, AdminNoticeList.DEFINITION);
  }

  private static AdminListQuery feedbackQuery(String q, String status, String sort, String page) {
    Map<String, String> filters = new HashMap<>();
    filters.put("status", status);
    return AdminListQuery.of(q, filters, sort, page, AdminFeedbackList.DEFINITION);
  }

  @Test
  @DisplayName("공지 정렬은 허용 열만 통과한다. 허용 밖 열·방향은 최근 수정순으로 돌아간다")
  void noticeSort_allowedKeysOnly() {
    assertThat(AdminNoticeList.pageableOf(noticeQuery(null, null, null)).getSort().toString())
      .startsWith("updatedAt: DESC");
    assertThat(AdminNoticeList.pageableOf(noticeQuery(null, "title,asc", null)).getSort().toString())
      .startsWith("title: ASC");
    assertThat(AdminNoticeList.pageableOf(noticeQuery(null, "priority,desc", null)).getSort().toString())
      .startsWith("priority: DESC");
    assertThat(AdminNoticeList.pageableOf(noticeQuery(null, "startsAt,asc", null)).getSort().toString())
      .startsWith("startsAt: ASC");
    for (String forbidden : List.of("body,asc", "imageKey,desc", "title,sideways", "id,asc", "createdBy", ";drop table")) {
      assertThat(AdminNoticeList.pageableOf(noticeQuery(null, forbidden, null)).getSort().toString())
        .as(forbidden).startsWith("updatedAt: DESC");
    }
  }

  @Test
  @DisplayName("공지 목록은 공통 쪽 크기를 쓰고 URL 1부터의 페이지를 0부터로 바꾼다. 동률은 id 로 고정한다")
  void noticePageable_sizeAndIndex() {
    Pageable pageable = AdminNoticeList.pageableOf(noticeQuery(null, null, "3"));

    assertThat(pageable.getPageSize()).isEqualTo(AdminListDefaults.PAGE_SIZE);
    assertThat(pageable.getPageNumber()).isEqualTo(2);
    assertThat(pageable.getSort().getOrderFor("id")).isNotNull();
    assertThat(AdminNoticeList.pageableOf(noticeQuery(null, null, "-5")).getPageNumber()).isZero();
    assertThat(AdminNoticeList.pageableOf(noticeQuery(null, null, "abc")).getPageNumber()).isZero();
  }

  @Test
  @DisplayName("검색어의 LIKE 특수문자(% _ \\)는 이스케이프되고 빈 검색어는 null 이다")
  void keywordEscaped() {
    assertThat(noticeQuery("100%_a\\b", null, null).likePattern()).isEqualTo("%100\\%\\_a\\\\b%");
    assertThat(noticeQuery("   ", null, null).likePattern()).isNull();
  }

  @Test
  @DisplayName("의견 정렬은 허용 열만 통과한다. 상태 변경 시각은 null 이 뒤로 가고, 허용 밖은 최신순이다")
  void feedbackSort_allowedKeysOnly() {
    assertThat(AdminFeedbackList.sortOf(feedbackQuery(null, null, null, null)).toString()).startsWith("createdAt: DESC");
    assertThat(AdminFeedbackList.sortOf(feedbackQuery(null, null, "status,asc", null)).toString())
      .startsWith("status: ASC");
    Sort byChangedAt = AdminFeedbackList.sortOf(feedbackQuery(null, null, "statusChangedAt,desc", null));
    assertThat(byChangedAt.getOrderFor("statusChangedAt").getNullHandling()).isEqualTo(Sort.NullHandling.NULLS_LAST);
    for (String forbidden : List.of("message,asc", "appLog,desc", "memberId", "member,asc", "createdAt,up")) {
      assertThat(AdminFeedbackList.sortOf(feedbackQuery(null, null, forbidden, null)).toString())
        .as(forbidden).startsWith("createdAt: DESC");
    }
  }

  @Test
  @DisplayName("의견 상태 필터는 정의된 상태만 통과하고 그 밖은 필터 없음이 된다")
  void feedbackStatusFilter() {
    assertThat(AdminFeedbackList.statusFilterOf(feedbackQuery(null, "IN_PROGRESS", null, null)))
      .isEqualTo(FeedbackStatus.IN_PROGRESS);
    assertThat(AdminFeedbackList.statusFilterOf(feedbackQuery(null, "ARCHIVED", null, null))).isNull();
    assertThat(AdminFeedbackList.statusFilterOf(feedbackQuery(null, "", null, null))).isNull();
    assertThat(AdminFeedbackList.statusFilterOf(feedbackQuery(null, null, null, null))).isNull();
    assertThat(AdminFeedbackList.DEFINITION.filters().get(0).options()).hasSize(FeedbackStatus.values().length);
  }

  @Test
  @DisplayName("의견 서비스의 쪽 크기는 관리자 공통 쪽 크기와 같다 (feedback 이 admin 을 못 읽어 값을 따로 둔다)")
  void feedbackPageSizeMatchesAdminDefault() {
    assertThat(FeedbackService.ADMIN_PAGE_SIZE).isEqualTo(AdminListDefaults.PAGE_SIZE);
  }

  @Test
  @DisplayName("범위 밖 페이지는 마지막 페이지로 맞춰 한 번 더 조회한다. 범위 안이거나 0건이면 한 번만 조회한다")
  void pageCorrection() {
    List<Integer> requestedPages = new java.util.ArrayList<>();
    Page<String> corrected = AdminListPaging.fetchWithPageCorrection(noticeQuery(null, null, "9"), condition -> {
      requestedPages.add(condition.page());
      // 41건 = 3쪽. 범위 밖 쪽은 비어 돌아온다
      List<String> content = condition.page() <= 3 ? List.of("x") : List.of();
      return new PageImpl<>(content, PageRequest.of(condition.pageIndex(), 20), 41);
    });
    assertThat(requestedPages).containsExactly(9, 3);
    assertThat(corrected.getNumber()).isEqualTo(2);

    requestedPages.clear();
    AdminListPaging.fetchWithPageCorrection(noticeQuery(null, null, "2"), condition -> {
      requestedPages.add(condition.page());
      return new PageImpl<>(List.of("x"), PageRequest.of(condition.pageIndex(), 20), 41);
    });
    assertThat(requestedPages).containsExactly(2);

    requestedPages.clear();
    AdminListPaging.fetchWithPageCorrection(noticeQuery(null, null, "5"), condition -> {
      requestedPages.add(condition.page());
      return new PageImpl<String>(List.of(), PageRequest.of(condition.pageIndex(), 20), 0);
    });
    assertThat(requestedPages).containsExactly(5);
  }
}
