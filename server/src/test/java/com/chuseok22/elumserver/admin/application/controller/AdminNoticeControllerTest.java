package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.dto.request.NoticeEditForm;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.notice.application.dto.request.NoticeInput;
import com.chuseok22.elumserver.notice.application.service.NoticeService;
import com.chuseok22.elumserver.notice.core.NoticePlatform;
import com.chuseok22.elumserver.notice.core.NoticeStatus;
import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import java.security.Principal;
import java.time.LocalDateTime;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.ui.ExtendedModelMap;
import org.springframework.web.servlet.mvc.support.RedirectAttributesModelMap;

/**
 * 관리자 공지 화면의 저장 흐름 (이슈 #370).
 *
 * <p>검증에 걸리면 <b>리다이렉트하지 않고 입력값 그대로 다시 그린다</b>(N16 "올리던 폼 내용은
 * 남는다"). 상태 코드는 400 으로 둔다 — 200 이면 모니터링이 성공으로 센다. 메시지에는
 * 추적용 E-NTC 코드를 붙인다.
 */
class AdminNoticeControllerTest {

  private final NoticeService noticeService = mock(NoticeService.class);
  private final AdminNoticeController controller = new AdminNoticeController(noticeService);
  private final Principal admin = () -> "kimchi";

  private ExtendedModelMap model;
  private MockHttpServletResponse response;
  private RedirectAttributesModelMap redirect;

  @BeforeEach
  void setUp() {
    model = new ExtendedModelMap();
    response = new MockHttpServletResponse();
    redirect = new RedirectAttributesModelMap();
    when(noticeService.now()).thenReturn(LocalDateTime.of(2026, 9, 23, 12, 0));
    when(noticeService.hideDays()).thenReturn(7);
    when(noticeService.liveInSlideOrder()).thenReturn(List.of());
  }

  private NoticeEditForm form(String title) {
    return new NoticeEditForm(title, "본문", "", "", "ALL", "0", "2026-09-23T09:00", "", true, false, false);
  }

  private AppNotice stored(String id) {
    AppNotice notice = new AppNotice();
    notice.setId(id);
    notice.setTitle("**하루 3개**까지");
    notice.setBody("본문");
    notice.setPlatform(NoticePlatform.ALL);
    notice.setStartsAt(LocalDateTime.of(2026, 9, 23, 9, 0));
    notice.setEnabled(true);
    return notice;
  }

  @Test
  @DisplayName("새로 만들다 검증에 걸리면 입력값 그대로 다시 그리고 400 과 E-NTC 코드를 보인다")
  void create_rejected_rerendersWithCode() {
    NoticeEditForm form = form("**짝 없음");
    when(noticeService.create(any(NoticeInput.class), any(), eq("kimchi")))
      .thenThrow(new CustomException(ErrorCode.NOTICE_TITLE_EMPHASIS_UNPAIRED));

    String view = controller.create(form, null, admin, model, response, redirect);

    assertThat(view).isEqualTo("admin/notice-edit");
    assertThat(response.getStatus()).isEqualTo(400);
    assertThat(model.get("form")).isSameAs(form);
    assertThat((String) model.get("errorMessage")).contains("E-NTC-003").contains("**");
  }

  @Test
  @DisplayName("이미지 때문에 걸리면 파일을 다시 골라 달라고 말한다 — 브라우저가 고른 파일을 비운다 (N16)")
  void create_imageRejected_asksToPickAgain() {
    MockMultipartFile big = new MockMultipartFile("image", "big.png", "image/png", new byte[10]);
    when(noticeService.create(any(NoticeInput.class), any(), any()))
      .thenThrow(new CustomException(ErrorCode.NOTICE_IMAGE_TOO_LARGE));

    controller.create(form("공지"), big, admin, model, response, redirect);

    assertThat(response.getStatus()).isEqualTo(400);
    assertThat((String) model.get("errorMessage")).contains("E-NTC-013").contains("다시 골라");
  }

  @Test
  @DisplayName("이미지 저장이 서버 사정으로 실패하면 500 으로 둔다 — 관리자가 고칠 입력이 아니다")
  void create_saveFailed_is500() {
    when(noticeService.create(any(NoticeInput.class), any(), any()))
      .thenThrow(new CustomException(ErrorCode.NOTICE_IMAGE_SAVE_FAILED));

    controller.create(form("공지"), null, admin, model, response, redirect);

    assertThat(response.getStatus()).isEqualTo(500);
    assertThat((String) model.get("errorMessage")).contains("E-NTC-014");
  }

  @Test
  @DisplayName("저장하면 목록으로 돌아가며 강조 표기를 걷어낸 제목으로 알린다")
  void create_ok_redirects() {
    when(noticeService.create(any(NoticeInput.class), any(), eq("kimchi"))).thenReturn(stored("n1"));

    String view = controller.create(form("**하루 3개**까지"), null, admin, model, response, redirect);

    assertThat(view).isEqualTo("redirect:/admin/notices");
    assertThat((String) redirect.getFlashAttributes().get("message")).contains("하루 3개까지").doesNotContain("**");
  }

  @Test
  @DisplayName("고치다 걸리면 그 공지 편집 화면을 입력값 그대로 다시 그린다")
  void update_rejected_rerenders() {
    AppNotice notice = stored("n1");
    when(noticeService.get("n1")).thenReturn(notice);
    when(noticeService.statusOf(notice)).thenReturn(NoticeStatus.LIVE);
    when(noticeService.update(eq("n1"), any(NoticeInput.class), anyBoolean(), any(), anyBoolean(), any()))
      .thenThrow(new CustomException(ErrorCode.NOTICE_PERIOD_INVALID));
    NoticeEditForm form = form("공지");

    String view = controller.update("n1", form, null, admin, model, response, redirect);

    assertThat(view).isEqualTo("admin/notice-edit");
    assertThat(response.getStatus()).isEqualTo(400);
    assertThat(model.get("notice")).isSameAs(notice);
    assertThat(model.get("form")).isSameAs(form);
    assertThat((String) model.get("errorMessage")).contains("E-NTC-009");
  }

  @Test
  @DisplayName("\"다시 보이게\"와 \"이미지 지우기\" 체크를 그대로 넘긴다")
  void update_passesFlags() {
    when(noticeService.update(eq("n1"), any(NoticeInput.class), eq(true), any(), eq(true), eq("kimchi")))
      .thenReturn(stored("n1"));
    NoticeEditForm form = new NoticeEditForm("공지", "본문", "", "", "ALL", "0", "2026-09-23T09:00", "",
      true, true, true);

    assertThat(controller.update("n1", form, null, admin, model, response, redirect))
      .isEqualTo("redirect:/admin/notices");
    verify(noticeService).update(eq("n1"), any(NoticeInput.class), eq(true), any(), eq(true), eq("kimchi"));
  }

  @Test
  @DisplayName("켜고 끄면 목록으로 돌아가 무엇을 했는지 알린다")
  void toggle() {
    when(noticeService.setEnabled("n1", false, "kimchi")).thenReturn(stored("n1"));

    assertThat(controller.setEnabled("n1", false, admin, redirect)).isEqualTo("redirect:/admin/notices");
    assertThat((String) redirect.getFlashAttributes().get("message")).contains("껐어요");
  }

  @Test
  @DisplayName("지우면 목록으로 돌아간다")
  void delete() {
    when(noticeService.get("n1")).thenReturn(stored("n1"));

    assertThat(controller.delete("n1", redirect)).isEqualTo("redirect:/admin/notices");
    verify(noticeService).delete("n1");
    assertThat((String) redirect.getFlashAttributes().get("message")).contains("지웠어요");
  }

  @Test
  @DisplayName("새로 만들기 폼은 꺼진 채 지금 시각으로 시작한다 — 확인하고 켜게 한다")
  void newForm_defaults() {
    assertThat(controller.newForm(model)).isEqualTo("admin/notice-edit");

    NoticeEditForm form = (NoticeEditForm) model.get("form");
    assertThat(form.startsAt()).isEqualTo("2026-09-23T12:00");
    assertThat(form.isEnabled()).isFalse();
    assertThat(form.platform()).isEqualTo("ALL");
    assertThat(model.get("hideDays")).isEqualTo(7);
    assertThat((String) model.get("previewJson")).contains("\"hideDays\":7");
  }
}
