package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.feedback.application.service.FeedbackService;
import com.chuseok22.elumserver.feedback.infrastructure.entity.Feedback;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.ui.ExtendedModelMap;
import org.springframework.web.servlet.mvc.support.RedirectAttributesModelMap;

class AdminFeedbackControllerTest {

  private final FeedbackService feedbackService = mock(FeedbackService.class);
  private final AdminFeedbackController controller = new AdminFeedbackController(feedbackService);

  @Test
  @DisplayName("목록은 페이지를 모델에 담아 목록 화면을 그린다. 0건이어도 같다")
  void list_rendersPage() {
    when(feedbackService.list(0)).thenReturn(new PageImpl<Feedback>(List.of()));
    ExtendedModelMap model = new ExtendedModelMap();

    String view = controller.list(0, model);

    assertThat(view).isEqualTo("admin/feedback");
    assertThat(model.get("feedbacks")).isNotNull();
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
    RedirectAttributesModelMap redirect = new RedirectAttributesModelMap();

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
