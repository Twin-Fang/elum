package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.service.AdminSettingsHistoryService.HistoryPageResult;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigHistoryCondition;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigHistoryService;
import com.chuseok22.elumserver.systemconfig.infrastructure.entity.SystemConfigHistory;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * 설정 변경 이력 화면: 조건 변환, 20건 고정 해제(페이지), 범위 밖 페이지 보정
 */
@ExtendWith(MockitoExtension.class)
class AdminSettingsHistoryServiceTest {

  @Mock private SystemConfigHistoryService historyService;

  private AdminSettingsHistoryService service;

  @BeforeEach
  void setUp() {
    service = new AdminSettingsHistoryService(historyService, new AdminDateFormatter());
  }

  private static AdminListQuery queryOf(Map<String, String> filters, String q, String sort, String page) {
    return AdminListQuery.of(q, filters, sort, page, AdminSettingsHistoryService.DEFINITION);
  }

  private static Page<SystemConfigHistory> pageOf(int total, int pageIndex, SystemConfigHistory... items) {
    return new PageImpl<>(List.of(items), PageRequest.of(pageIndex, 20), total);
  }

  @Test
  @DisplayName("키·변경자·기간 조건이 검색 조건으로 바뀌고 종료일은 그날 끝까지 포함한다")
  void filters_becomeCondition_withInclusiveEndDate() {
    when(historyService.search(any(), any())).thenReturn(pageOf(0, 0));

    service.search(queryOf(Map.of("key", "FREE_ADS_REMOVED", "changedBy", "admin",
      "from", "2026-10-01", "to", "2026-10-18"), "100%", null, null));

    ArgumentCaptor<SystemConfigHistoryCondition> condition = ArgumentCaptor.forClass(SystemConfigHistoryCondition.class);
    verify(historyService).search(condition.capture(), any());
    assertThat(condition.getValue().configKey()).isEqualTo("FREE_ADS_REMOVED");
    assertThat(condition.getValue().changedBy()).isEqualTo("admin");
    assertThat(condition.getValue().from()).isEqualTo(LocalDateTime.of(2026, 10, 1, 0, 0));
    assertThat(condition.getValue().toExclusive()).isEqualTo(LocalDateTime.of(2026, 10, 19, 0, 0));
    assertThat(condition.getValue().likePattern()).isEqualTo("%100\\%%");
  }

  @Test
  @DisplayName("읽을 수 없는 날짜는 조건 없음으로 보고 오류 없이 조회한다")
  void brokenDate_isIgnored() {
    when(historyService.search(any(), any())).thenReturn(pageOf(0, 0));

    service.search(queryOf(Map.of("from", "어제", "to", "2026-13-40"), null, null, null));

    ArgumentCaptor<SystemConfigHistoryCondition> condition = ArgumentCaptor.forClass(SystemConfigHistoryCondition.class);
    verify(historyService).search(condition.capture(), any());
    assertThat(condition.getValue().from()).isNull();
    assertThat(condition.getValue().toExclusive()).isNull();
  }

  @Test
  @DisplayName("한 쪽은 20건이고 정렬은 허용된 열만, 잘못된 정렬은 최신순으로 돌아간다")
  void pageSize_isTwenty_andInvalidSortFallsBack() {
    when(historyService.search(any(), any())).thenReturn(pageOf(100, 1));

    service.search(queryOf(Map.of(), null, "password,asc", "2"));

    ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
    verify(historyService).search(any(), pageable.capture());
    assertThat(pageable.getValue().getPageSize()).isEqualTo(20);
    assertThat(pageable.getValue().getPageNumber()).isEqualTo(1);
    assertThat(pageable.getValue().getSort().getOrderFor("createdAt").isDescending()).isTrue();
  }

  @Test
  @DisplayName("범위 밖 페이지는 마지막 페이지로 보정해 다시 읽는다")
  void pageBeyondLast_isClamped() {
    when(historyService.search(any(), any())).thenReturn(pageOf(45, 8)).thenReturn(pageOf(45, 2));

    HistoryPageResult result = service.search(queryOf(Map.of(), null, null, "9999"));

    assertThat(result.query().page()).isEqualTo(3);
    verify(historyService, times(2)).search(any(), any());
  }

  @Test
  @DisplayName("행은 이전 → 새 값을 보여 주고 값이 없으면 (없음), 비밀값 가림 표시는 그대로 둔다")
  void row_showsChange() {
    SystemConfigHistory history = new SystemConfigHistory();
    history.setConfigKey("OPENAI_API_KEY");
    history.setOldValue("");
    history.setNewValue("••••");
    history.setChangedBy("admin");
    ReflectionTestUtils.setField(history, "createdAt", LocalDateTime.of(2026, 10, 18, 9, 5));
    when(historyService.search(any(), any())).thenReturn(pageOf(1, 0, history));

    HistoryPageResult result = service.search(queryOf(Map.of(), null, null, null));

    Map<String, String> cells = result.rows().get(0).cells();
    assertThat(cells.get("change")).isEqualTo("(없음) → ••••");
    assertThat(cells.get("createdAt")).isEqualTo("2026-10-18 09:05");
    assertThat(cells.get("reason")).isEqualTo("-");
  }
}
