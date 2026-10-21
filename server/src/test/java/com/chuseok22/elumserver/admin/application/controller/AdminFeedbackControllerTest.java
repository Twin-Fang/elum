package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.dto.response.AdminFeedbackSenderPanel;
import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.list.AdminCsvExporter.ExportLink;
import com.chuseok22.elumserver.admin.application.list.AdminFeedbackList;
import com.chuseok22.elumserver.admin.application.service.AdminFeedbackSenderService;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.feedback.application.service.FeedbackAdminSearch;
import com.chuseok22.elumserver.feedback.application.service.FeedbackService;
import com.chuseok22.elumserver.feedback.core.FeedbackStatus;
import com.chuseok22.elumserver.feedback.infrastructure.entity.Feedback;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.ui.ExtendedModelMap;
import org.springframework.web.servlet.mvc.support.RedirectAttributesModelMap;

class AdminFeedbackControllerTest {

  private final FeedbackService feedbackService = mock(FeedbackService.class);
  private final AdminFeedbackSenderService adminFeedbackSenderService = mock(AdminFeedbackSenderService.class);
  private final AdminFeedbackController controller =
    new AdminFeedbackController(feedbackService, new AdminDateFormatter(), adminFeedbackSenderService);
  private final RedirectAttributesModelMap redirect = new RedirectAttributesModelMap();

  private static final Sort NEWEST_FIRST = Sort.by(Sort.Order.desc("createdAt"), Sort.Order.asc("id"));

  /// 요청 파라미터 맵 (키, 값 번갈아)
  private static Map<String, String> parameters(String... keyValues) {
    Map<String, String> parameters = new LinkedHashMap<>();
    for (int index = 0; index < keyValues.length; index += 2) {
      parameters.put(keyValues[index], keyValues[index + 1]);
    }
    return parameters;
  }

  @Test
  @DisplayName("목록은 페이지·정의·조건·CSV 링크를 모델에 담아 목록 화면을 그린다. 0건이어도 같다")
  void list_rendersPage() {
    when(feedbackService.search(FeedbackAdminSearch.none(), NEWEST_FIRST, 0))
      .thenReturn(new PageImpl<Feedback>(List.of()));
    ExtendedModelMap model = new ExtendedModelMap();

    String view = controller.list(parameters("page", "1"), model); // URL 페이지는 1부터, 서비스는 0부터

    assertThat(view).isEqualTo("admin/feedback");
    assertThat(model.get("feedbacks")).isNotNull();
    assertThat(model.get("definition")).isSameAs(AdminFeedbackList.DEFINITION);
    assertThat(model.get("pagerBaseUrl")).isEqualTo("/admin/feedback?sort=createdAt,desc");
    assertThat(((ExportLink) model.get("csvExport")).url()).isEqualTo("/admin/feedback/export.csv?sort=createdAt,desc");
  }

  @Test
  @DisplayName("검색어·상태·OS·앱 버전·기간을 서비스 조건으로 옮기고, LIKE 특수문자는 이스케이프한다")
  void list_translatesConditions() {
    when(feedbackService.search(any(FeedbackAdminSearch.class), any(Sort.class), eq(1)))
      .thenReturn(new PageImpl<Feedback>(List.of(), PageRequest.of(1, 20), 25));
    ExtendedModelMap model = new ExtendedModelMap();

    controller.list(parameters("q", "50%", "status", "IN_PROGRESS", "os", "ios", "appVersion", "1.0_",
      "from", "2026-10-01", "to", "2026-10-02", "sort", "status,asc", "page", "2"), model);

    ArgumentCaptor<FeedbackAdminSearch> condition = ArgumentCaptor.forClass(FeedbackAdminSearch.class);
    ArgumentCaptor<Sort> sort = ArgumentCaptor.forClass(Sort.class);
    verify(feedbackService).search(condition.capture(), sort.capture(), eq(1));
    assertThat(condition.getValue()).isEqualTo(new FeedbackAdminSearch("%50\\%%", FeedbackStatus.IN_PROGRESS,
      LocalDateTime.of(2026, 10, 1, 0, 0), LocalDateTime.of(2026, 10, 3, 0, 0), "1.0\\_%", "ios%"));
    assertThat(sort.getValue().toString()).startsWith("status: ASC");
    assertThat((String) model.get("pagerBaseUrl")).isEqualTo(
      "/admin/feedback?q=50%25&status=IN_PROGRESS&os=ios&appVersion=1.0_&from=2026-10-01&to=2026-10-02&sort=status,asc");
  }

  @Test
  @DisplayName("허용 밖 상태·OS·날짜·정렬은 무시하고 기본 조건으로 조회한다")
  void list_invalidConditionsFallBack() {
    when(feedbackService.search(FeedbackAdminSearch.none(), NEWEST_FIRST, 0))
      .thenReturn(new PageImpl<Feedback>(List.of()));

    controller.list(parameters("status", "ARCHIVED", "os", "windows", "from", "어제",
      "sort", "message,asc;drop", "page", "abc"), new ExtendedModelMap());

    verify(feedbackService).search(FeedbackAdminSearch.none(), NEWEST_FIRST, 0);
  }

  @Test
  @DisplayName("범위 밖 페이지는 마지막 페이지로 맞춰 다시 조회한다")
  void list_pageBeyondLast_refetchesLastPage() {
    when(feedbackService.search(FeedbackAdminSearch.none(), NEWEST_FIRST, 8))
      .thenReturn(new PageImpl<Feedback>(List.of(), PageRequest.of(8, 20), 41));
    when(feedbackService.search(FeedbackAdminSearch.none(), NEWEST_FIRST, 2))
      .thenReturn(new PageImpl<Feedback>(List.of(new Feedback()), PageRequest.of(2, 20), 41));
    ExtendedModelMap model = new ExtendedModelMap();

    controller.list(parameters("page", "9"), model);

    assertThat(((Page<?>) model.get("feedbacks")).getNumber()).isEqualTo(2);
  }

  @Test
  @DisplayName("처리 상태를 바꾸면 변경자와 함께 서비스에 넘기고, 검색·필터·정렬·페이지를 유지한 목록으로 돌아간다")
  void changeStatus_returnsToSameList() {
    String view = controller.changeStatus("f1", "DONE", "list",
      parameters("status", "DONE", "return.q", "느림", "return.status", "NEW", "return.os", "android",
        "return.sort", "status,asc", "return.page", "3"),
      () -> "kimchi", redirect);

    verify(feedbackService).changeStatus("f1", FeedbackStatus.DONE, "kimchi");
    assertThat(view).isEqualTo(
      "redirect:/admin/feedback?q=%EB%8A%90%EB%A6%BC&status=NEW&os=android&sort=status,asc&page=3");
    assertThat((String) redirect.getFlashAttributes().get("message")).contains("처리 완료");
  }

  @Test
  @DisplayName("상세에서 바꾸면 상세로 돌아간다")
  void changeStatus_fromDetail_returnsToDetail() {
    String view = controller.changeStatus("f1", "IN_PROGRESS", "detail", parameters("status", "IN_PROGRESS"),
      () -> "kimchi", redirect);

    verify(feedbackService).changeStatus("f1", FeedbackStatus.IN_PROGRESS, "kimchi");
    assertThat(view).isEqualTo("redirect:/admin/feedback/f1");
  }

  @Test
  @DisplayName("돌아갈 곳 값이 조작돼도 정의로 보정되어 다른 주소로 나가지 않는다")
  void changeStatus_tamperedReturnValues() {
    String view = controller.changeStatus("f1", "DONE", "list",
      parameters("return.status", "//evil.example", "return.sort", "https://evil.example", "return.page", "x",
        "return.next", "https://evil.example"),
      () -> "kimchi", redirect);

    assertThat(view).isEqualTo("redirect:/admin/feedback?sort=createdAt,desc");
  }

  @Test
  @DisplayName("알 수 없는 상태 값은 바꾸지 않고 안내만 남긴다")
  void changeStatus_unknownStatus() {
    String view = controller.changeStatus("f1", "ARCHIVED", "list", parameters(), () -> "kimchi", redirect);

    verify(feedbackService, never()).changeStatus(any(), any(), any());
    assertThat(view).startsWith("redirect:/admin/feedback");
    assertThat(redirect.getFlashAttributes()).containsKey("errorMessage");
  }

  @Test
  @DisplayName("없는 의견의 상태를 바꾸면 FEEDBACK_NOT_FOUND 가 그대로 올라간다(오류 화면이 받는다)")
  void changeStatus_notFound_propagates() {
    doThrow(new CustomException(ErrorCode.FEEDBACK_NOT_FOUND)).when(feedbackService)
      .changeStatus("nope", FeedbackStatus.DONE, "kimchi");

    assertThatThrownBy(() -> controller.changeStatus("nope", "DONE", "list", parameters(),
      () -> "kimchi", redirect)).isInstanceOf(CustomException.class);
  }

  @Test
  @DisplayName("상세는 의견을 모델에 담는다")
  void detail_rendersFeedback() {
    Feedback feedback = new Feedback();
    feedback.setId("f1");
    when(feedbackService.get("f1")).thenReturn(feedback);
    ExtendedModelMap model = new ExtendedModelMap();

    assertThat(controller.detail("f1", model)).isEqualTo("admin/feedback-detail");
    assertThat(model.get("feedback")).isSameAs(feedback);
  }

  @Test
  @DisplayName("보낸 회원 패널 조회가 터져도 상세는 의견을 그리고 패널만 실패(에러 코드 안내)로 둔다")
  void detail_senderPanelFails_stillRendersFeedback() {
    Feedback feedback = new Feedback();
    feedback.setId("f1");
    feedback.setMemberId("m1");
    when(feedbackService.get("f1")).thenReturn(feedback);
    when(adminFeedbackSenderService.loadSenderPanel(eq("m1"), any())).thenThrow(new IllegalStateException("db down"));
    ExtendedModelMap model = new ExtendedModelMap();

    assertThat(controller.detail("f1", model)).isEqualTo("admin/feedback-detail");
    assertThat(model.get("feedback")).isSameAs(feedback);
    AdminFeedbackSenderPanel panel = (AdminFeedbackSenderPanel) model.get("senderPanel");
    assertThat(panel.isLoadFailed()).isTrue();
    assertThat(panel.memberId()).isEqualTo("m1");
  }

  @Test
  @DisplayName("삭제하면 목록으로 돌아가고 안내 문구를 남긴다")
  void delete_redirects() {
    String view = controller.delete("f1", redirect);

    verify(feedbackService).delete("f1");
    assertThat(view).isEqualTo("redirect:/admin/feedback");
    assertThat(redirect.getFlashAttributes()).containsKey("message");
  }

  @Test
  @DisplayName("없는 의견을 지우면 FEEDBACK_NOT_FOUND 가 그대로 올라간다(오류 화면이 받는다)")
  void delete_notFound_propagates() {
    doThrow(new CustomException(ErrorCode.FEEDBACK_NOT_FOUND)).when(feedbackService).delete("nope");

    assertThatThrownBy(() -> controller.delete("nope", new RedirectAttributesModelMap()))
      .isInstanceOf(CustomException.class);
  }
}
