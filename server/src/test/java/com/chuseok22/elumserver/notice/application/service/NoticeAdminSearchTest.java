package com.chuseok22.elumserver.notice.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import com.chuseok22.elumserver.notice.infrastructure.repository.AppNoticeRepository;
import com.chuseok22.elumserver.notice.infrastructure.storage.NoticeImageStorage;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

/** 관리자 공지 목록 검색: 검색어 유무에 따른 쿼리 인자, 정렬·페이지는 호출부 Pageable 그대로 */
class NoticeAdminSearchTest {

  private final AppNoticeRepository repository = mock(AppNoticeRepository.class);
  private final NoticeService service =
    new NoticeService(repository, mock(SystemConfigService.class), mock(NoticeImageStorage.class));

  @Test
  @DisplayName("검색어가 없으면 hasKeyword=false 와 빈 패턴으로 전체를 묻는다")
  void search_withoutKeyword() {
    Pageable pageable = PageRequest.of(0, 20, Sort.by("updatedAt"));
    when(repository.searchForAdmin(anyBoolean(), any(), any())).thenReturn(new PageImpl<>(List.of()));

    service.search(null, pageable);

    verify(repository).searchForAdmin(false, "", pageable);
  }

  @Test
  @DisplayName("검색어가 있으면 이스케이프된 패턴 그대로 넘기고 조회 결과 페이지를 돌려준다")
  void search_withKeyword() {
    Pageable pageable = PageRequest.of(1, 20, Sort.by("title"));
    AppNotice notice = new AppNotice();
    when(repository.searchForAdmin(eq(true), eq("%100\\%%"), eq(pageable)))
      .thenReturn(new PageImpl<>(List.of(notice), pageable, 21));

    var page = service.search("%100\\%%", pageable);

    assertThat(page.getContent()).containsExactly(notice);
    assertThat(page.getTotalElements()).isEqualTo(21);
  }
}
