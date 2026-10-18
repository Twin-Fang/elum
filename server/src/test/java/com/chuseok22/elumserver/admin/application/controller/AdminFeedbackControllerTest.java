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

import com.chuseok22.elumserver.admin.application.list.AdminFeedbackList;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.feedback.application.service.FeedbackService;
import com.chuseok22.elumserver.feedback.core.FeedbackStatus;
import com.chuseok22.elumserver.feedback.infrastructure.entity.Feedback;
import java.util.List;
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
  private final AdminFeedbackController controller = new AdminFeedbackController(feedbackService);
  private final RedirectAttributesModelMap redirect = new RedirectAttributesModelMap();

  private static final Sort NEWEST_FIRST = Sort.by(Sort.Order.desc("createdAt"), Sort.Order.asc("id"));

  @Test
  @DisplayName("목록은 페이지·정의·조건을 모델에 담아 목록 화면을 그린다. 0건이어도 같다")
  void list_rendersPage() {
    when(feedbackService.search(null, null, NEWEST_FIRST, 0)).thenReturn(new PageImpl<Feedback>(List.of()));
    ExtendedModelMap model = new ExtendedModelMap();

    String view = controller.list(null, null, null, "1", model); // URL 페이지는 1부터, 서비스는 0부터

    assertThat(view).isEqualTo("admin/feedback");
    assertThat(model.get("feedbacks")).isNotNull();
    assertThat(model.get("definition")).isSameAs(AdminFeedbackList.DEFINITION);
    assertThat(model.get("pagerBaseUrl")).isEqualTo("/admin/feedback?sort=createdAt,desc");
  }

  @Test
  @DisplayName("검색어·상태 필터·정렬을 서비스 조건으로 옮기고, 검색어의 LIKE 특수문자는 이스케이프한다")
  void list_translatesConditions() {
    when(feedbackService.search(eq("%50\\%%"), eq(FeedbackStatus.IN_PROGRESS), any(Sort.class), eq(1)))
      .thenReturn(new PageImpl<Feedback>(List.of(), PageRequest.of(1, 20), 25));
    ExtendedModelMap model = new ExtendedModelMap();

    controller.list("50%", "IN_PROGRESS", "status,asc", "2", model);

    ArgumentCaptor<Sort> sort = ArgumentCaptor.forClass(Sort.class);
    verify(feedbackService).search(eq("%50\\%%"), eq(FeedbackStatus.IN_PROGRESS), sort.capture(), eq(1));
    assertThat(sort.getValue().toString()).startsWith("status: ASC");
    assertThat((String) model.get("pagerBaseUrl")).isEqualTo("/admin/feedback?q=50%25&status=IN_PROGRESS&sort=status,asc");
  }

  @Test
  @DisplayName("허용 밖 상태 필터·정렬은 무시하고 기본 조건으로 조회한다")
  void list_invalidConditionsFallBack() {
    when(feedbackService.search(null, null, NEWEST_FIRST, 0)).thenReturn(new PageImpl<Feedback>(List.of()));

    controller.list(null, "ARCHIVED", "message,asc;drop", "abc", new ExtendedModelMap());

    verify(feedbackService).search(null, null, NEWEST_FIRST, 0);
  }

  @Test
  @DisplayName("범위 밖 페이지는 마지막 페이지로 맞춰 다시 조회한다")
  void list_pageBeyondLast_refetchesLastPage() {
    when(feedbackService.search(null, null, NEWEST_FIRST, 8))
      .thenReturn(new PageImpl<Feedback>(List.of(), PageRequest.of(8, 20), 41));
    when(feedbackService.search(null, null, NEWEST_FIRST, 2))
      .thenReturn(new PageImpl<Feedback>(List.of(new Feedback()), PageRequest.of(2, 20), 41));
    ExtendedModelMap model = new ExtendedModelMap();

    controller.list(null, null, null, "9", model);

    assertThat(((Page<?>) model.get("feedbacks")).getNumber()).isEqualTo(2);
  }

  @Test
  @DisplayName("처리 상태를 바꾸면 변경자와 함께 서비스에 넘기고, 검색·필터·정렬·페이지를 유지한 목록으로 돌아간다")
  void changeStatus_returnsToSameList() {
    String view = controller.changeStatus("f1", "DONE", "list", "느림", "NEW", "status,asc", "3",
      () -> "kimchi", redirect);

    verify(feedbackService).changeStatus("f1", FeedbackStatus.DONE, "kimchi");
    assertThat(view).isEqualTo("redirect:/admin/feedback?q=%EB%8A%90%EB%A6%BC&status=NEW&sort=status,asc&page=3");
    assertThat((String) redirect.getFlashAttributes().get("message")).contains("처리 완료");
  }

  @Test
  @DisplayName("상세에서 바꾸면 상세로 돌아간다")
  void changeStatus_fromDetail_returnsToDetail() {
    String view = controller.changeStatus("f1", "IN_PROGRESS", "detail", null, null, null, null,
      () -> "kimchi", redirect);

    verify(feedbackService).changeStatus("f1", FeedbackStatus.IN_PROGRESS, "kimchi");
    assertThat(view).isEqualTo("redirect:/admin/feedback/f1");
  }

  @Test
  @DisplayName("돌아갈 곳 값이 조작돼도 정의로 보정되어 다른 주소로 나가지 않는다")
  void changeStatus_tamperedReturnValues() {
    String view = controller.changeStatus("f1", "DONE", "list", null, "//evil.example", "https://evil.example", "x",
      () -> "kimchi", redirect);

    assertThat(view).isEqualTo("redirect:/admin/feedback?sort=createdAt,desc");
  }

  @Test
  @DisplayName("알 수 없는 상태 값은 바꾸지 않고 안내만 남긴다")
  void changeStatus_unknownStatus() {
    String view = controller.changeStatus("f1", "ARCHIVED", "list", null, null, null, null, () -> "kimchi", redirect);

    verify(feedbackService, never()).changeStatus(any(), any(), any());
    assertThat(view).startsWith("redirect:/admin/feedback");
    assertThat(redirect.getFlashAttributes()).containsKey("errorMessage");
  }

  @Test
  @DisplayName("없는 의견의 상태를 바꾸면 FEEDBACK_NOT_FOUND 가 그대로 올라간다(오류 화면이 받는다)")
  void changeStatus_notFound_propagates() {
    doThrow(new CustomException(ErrorCode.FEEDBACK_NOT_FOUND)).when(feedbackService)
      .changeStatus("nope", FeedbackStatus.DONE, "kimchi");

    assertThatThrownBy(() -> controller.changeStatus("nope", "DONE", "list", null, null, null, null,
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
