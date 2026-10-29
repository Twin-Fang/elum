package com.chuseok22.elumserver.notice.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.notice.core.NoticePlatform;
import com.chuseok22.elumserver.notice.core.NoticeStatus;
import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import com.chuseok22.elumserver.notice.infrastructure.repository.AppNoticeRepository;
import com.chuseok22.elumserver.notice.infrastructure.storage.NoticeImageStorage;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import java.time.LocalDateTime;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

/** 관리자 공지 목록 검색: 조건 > 쿼리 인자, 상태 필터는 앱과 같은 판단(statusAt)으로 거른 뒤 쪽 자르기 */
class NoticeAdminSearchTest {

  private final AppNoticeRepository repository = mock(AppNoticeRepository.class);
  private final NoticeService service =
    new NoticeService(repository, mock(SystemConfigService.class), mock(NoticeImageStorage.class));

  @Test
  @DisplayName("조건이 없으면 hasKeyword=false·빈 패턴·전체 플랫폼·끝값 기간으로 묻고 Pageable 은 그대로 넘긴다")
  void search_withoutConditions() {
    Pageable pageable = PageRequest.of(0, 20, Sort.by("updatedAt"));
    when(repository.searchForAdmin(anyBoolean(), any(), any(), any(), any(), any())).thenReturn(new PageImpl<>(List.of()));

    service.search(NoticeAdminSearch.none(), pageable);

    verify(repository).searchForAdmin(eq(false), eq(""), eq(List.of(NoticePlatform.values())),
      eq(LocalDateTime.of(2000, 1, 1, 0, 0)), eq(LocalDateTime.of(9999, 1, 1, 0, 0)), eq(pageable));
  }

  @Test
  @DisplayName("검색어·플랫폼·기간은 쿼리 인자로 그대로 넘기고 조회 결과 페이지를 돌려준다")
  void search_withQueryConditions() {
    Pageable pageable = PageRequest.of(1, 20, Sort.by("title"));
    AppNotice notice = new AppNotice();
    LocalDateTime from = LocalDateTime.of(2026, 9, 1, 0, 0);
    LocalDateTime to = LocalDateTime.of(2026, 10, 1, 0, 0);
    when(repository.searchForAdmin(eq(true), eq("%100\\%%"), eq(List.of(NoticePlatform.IOS)), eq(from), eq(to),
      eq(pageable))).thenReturn(new PageImpl<>(List.of(notice), pageable, 21));

    Page<AppNotice> page = service.search(
      new NoticeAdminSearch("%100\\%%", null, NoticePlatform.IOS, from, to), pageable);

    assertThat(page.getContent()).containsExactly(notice);
    assertThat(page.getTotalElements()).isEqualTo(21);
  }

  @Test
  @DisplayName("상태 필터는 앱 API 와 같은 판단으로 거르고, 거른 건수로 쪽을 나눈다 (목록엔 게시 중인데 앱엔 안 뜨는 공지가 없게)")
  void search_statusFilter_usesSameJudgementAsApp() {
    LocalDateTime now = service.now();
    AppNotice live = notice("live", true, now.minusDays(1), null);
    AppNotice scheduled = notice("scheduled", true, now.plusDays(1), null);
    AppNotice ended = notice("ended", true, now.minusDays(3), now.minusDays(1));
    AppNotice disabled = notice("disabled", false, now.minusDays(1), null);
    AppNotice liveToo = notice("liveToo", true, now.minusHours(1), now.plusDays(1));
    when(repository.searchForAdmin(anyBoolean(), any(), any(), any(), any(), any()))
      .thenReturn(new PageImpl<>(List.of(live, scheduled, ended, disabled, liveToo)));

    Page<AppNotice> firstPage = service.search(
      new NoticeAdminSearch(null, NoticeStatus.LIVE, null, null, null), PageRequest.of(0, 1));
    Page<AppNotice> beyondLast = service.search(
      new NoticeAdminSearch(null, NoticeStatus.LIVE, null, null, null), PageRequest.of(5, 1));

    assertThat(firstPage.getContent()).containsExactly(live);
    assertThat(firstPage.getTotalElements()).isEqualTo(2);
    assertThat(firstPage.getTotalPages()).isEqualTo(2);
    assertThat(beyondLast.getContent()).isEmpty();
  }

  private static AppNotice notice(String id, boolean enabled, LocalDateTime startsAt, LocalDateTime endsAt) {
    AppNotice notice = new AppNotice();
    notice.setId(id);
    notice.setEnabled(enabled);
    notice.setStartsAt(startsAt);
    notice.setEndsAt(endsAt);
    return notice;
  }
}
