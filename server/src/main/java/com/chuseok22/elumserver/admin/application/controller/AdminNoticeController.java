package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.request.NoticeEditForm;
import com.chuseok22.elumserver.admin.application.dto.response.AdminNoticeRow;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.notice.application.service.NoticeService;
import com.chuseok22.elumserver.notice.core.NoticeEmphasis;
import com.chuseok22.elumserver.notice.core.NoticeStatus;
import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import com.chuseok22.elumserver.notice.infrastructure.storage.NoticeImageStorage.ImageContent;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletResponse;
import java.security.Principal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/**
 * 보호자 홈 공지 팝업을 관리자 화면에서 올린다 (이슈 #370). 약관 관리와 같은 모양이다.
 *
 * <p>편집 화면 오른쪽에 휴대폰 틀 미리보기가 있다. 그리는 것은 {@code notice-preview.js} 이고,
 * 이 컨트롤러는 "지금 게시 중인 다른 공지"를 JSON 으로 넘겨 함께 넘겨 보게 한다.
 */
@Slf4j
@Controller
@RequiredArgsConstructor
public class AdminNoticeController {

  private static final String LIST = "redirect:/admin/notices";
  private static final String EDIT_VIEW = "admin/notice-edit";
  private static final DateTimeFormatter ISO_MINUTE = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm");
  private static final ObjectMapper JSON = new ObjectMapper();

  private final NoticeService noticeService;

  @GetMapping("/admin/notices")
  public String list(Model model) {
    LocalDateTime now = noticeService.now();
    List<AdminNoticeRow> rows = noticeService.getAll().stream()
      .map(notice -> new AdminNoticeRow(notice, noticeService.statusOf(notice),
        NoticeStatus.of(true, notice.getStartsAt(), notice.getEndsAt(), now).isLive()))
      .toList();
    model.addAttribute("rows", rows);
    addPreview(model, null);
    return "admin/notices";
  }

  @GetMapping("/admin/notices/new")
  public String newForm(Model model) {
    model.addAttribute("form", NoticeEditForm.blank(noticeService.now()));
    model.addAttribute("notice", null);
    addPreview(model, null);
    return EDIT_VIEW;
  }

  @GetMapping("/admin/notices/{id}")
  public String edit(@PathVariable("id") String id, Model model) {
    AppNotice notice = noticeService.get(id);
    model.addAttribute("form", NoticeEditForm.of(notice));
    addNotice(model, notice);
    addPreview(model, id);
    return EDIT_VIEW;
  }

  /**
   * 새로 만든다. <b>검증에 걸리면 리다이렉트하지 않고 입력값 그대로 다시 그린다</b> — 리다이렉트하면
   * 쓰던 본문이 사라진다. 고른 이미지 파일만은 브라우저가 비우므로 다시 골라 달라고 말한다.
   */
  @PostMapping("/admin/notices")
  public String create(
    @ModelAttribute("form") NoticeEditForm form,
    @RequestParam(value = "image", required = false) MultipartFile image,
    Principal principal,
    Model model,
    HttpServletResponse response,
    RedirectAttributes redirectAttributes
  ) {
    try {
      AppNotice saved = noticeService.create(form.toInput(), image, name(principal));
      redirectAttributes.addFlashAttribute("message", "'" + plainTitle(saved) + "' 공지를 만들었어요."
        + (saved.isEnabled() ? "" : " 꺼 둔 채라 앱에는 아직 나가지 않아요."));
      return LIST;
    } catch (CustomException e) {
      model.addAttribute("form", form);
      model.addAttribute("notice", null);
      return rejected(e, image, model, response, null);
    }
  }

  @PostMapping("/admin/notices/{id}")
  public String update(
    @PathVariable("id") String id,
    @ModelAttribute("form") NoticeEditForm form,
    @RequestParam(value = "image", required = false) MultipartFile image,
    Principal principal,
    Model model,
    HttpServletResponse response,
    RedirectAttributes redirectAttributes
  ) {
    try {
      AppNotice saved = noticeService.update(id, form.toInput(), form.isBumpRevision(), image,
        form.isRemoveImage(), name(principal));
      redirectAttributes.addFlashAttribute("message", "'" + plainTitle(saved) + "' 공지를 저장했어요."
        + (form.isBumpRevision() ? " 숨긴 보호자에게도 다시 보여요." : ""));
      return LIST;
    } catch (CustomException e) {
      model.addAttribute("form", form);
      addNotice(model, noticeService.get(id));
      return rejected(e, image, model, response, id);
    }
  }

  @PostMapping("/admin/notices/{id}/enabled")
  public String setEnabled(
    @PathVariable("id") String id,
    @RequestParam("enabled") boolean enabled,
    Principal principal,
    RedirectAttributes redirectAttributes
  ) {
    AppNotice saved = noticeService.setEnabled(id, enabled, name(principal));
    redirectAttributes.addFlashAttribute("message", "'" + plainTitle(saved) + "' 공지를 "
      + (enabled ? "켰어요. 게시 기간 안이면 앱에 나가요." : "껐어요. 다음에 앱을 켜는 보호자부터 안 보여요."));
    return LIST;
  }

  /** 지운다. 확인 창은 화면이 띄운다(게시 중이면 한 번 더). 이미지 파일도 함께 지운다. */
  @PostMapping("/admin/notices/{id}/delete")
  public String delete(@PathVariable("id") String id, RedirectAttributes redirectAttributes) {
    String title = plainTitle(noticeService.get(id));
    noticeService.delete(id);
    redirectAttributes.addFlashAttribute("message", "'" + title + "' 공지를 지웠어요.");
    return LIST;
  }

  /** 편집 화면 미리보기용. 게시 전 공지의 이미지도 본다(앱용 주소는 게시 중일 때만 준다). */
  @GetMapping("/admin/notices/{id}/image")
  @ResponseBody
  public ResponseEntity<byte[]> image(@PathVariable("id") String id) {
    ImageContent content = noticeService.adminImage(id);
    return ResponseEntity.ok()
      .cacheControl(CacheControl.noStore())
      .contentType(MediaType.parseMediaType(content.contentType()))
      .header("X-Content-Type-Options", "nosniff")
      .body(content.bytes());
  }

  // ── 도움 ────────────────────────────────────────────

  private void addNotice(Model model, AppNotice notice) {
    model.addAttribute("notice", notice);
    model.addAttribute("status", noticeService.statusOf(notice));
  }

  private String rejected(
    CustomException e, MultipartFile image, Model model, HttpServletResponse response, String editingId
  ) {
    boolean imageChosen = image != null && !image.isEmpty();
    model.addAttribute("errorMessage", failureReason(e)
      + (imageChosen ? " 고른 이미지는 저장하지 않았어요. 파일을 다시 골라 주세요." : ""));
    addPreview(model, editingId);
    // 화면은 그대로 그리되 상태 코드는 실패로 둔다. 200 이면 모니터링이 성공으로 센다.
    // 저장 실패처럼 관리자가 고칠 수 없는 것은 500 그대로 둔다.
    response.setStatus(e.getErrorCode().getStatus().value());
    log.info("[공지 관리] 저장 거부 {} — 공지 {}", e.getErrorCode().name(), editingId == null ? "(새 공지)" : editingId);
    return EDIT_VIEW;
  }

  /**
   * 미리보기 자료. 지금 게시 중인 공지 전부(플랫폼 무관)를 앱 슬라이드 순서로 넘긴다 —
   * 화면이 플랫폼으로 걸러 앱과 같은 팝업을 그린다. 편집 중인 공지는 빼고 넘긴다(입력값으로 그린다).
   * 이미지는 관리자 경로로 준다. 앱 경로는 점검 중이면 503 이라 미리보기가 깨진다.
   */
  private void addPreview(Model model, String editingId) {
    int hideDays = noticeService.hideDays();
    List<Map<String, Object>> slides = noticeService.liveInSlideOrder().stream()
      .filter(notice -> !notice.getId().equals(editingId))
      .map(AdminNoticeController::previewSlide)
      .toList();
    Map<String, Object> data = new LinkedHashMap<>();
    data.put("hideDays", hideDays);
    data.put("notices", slides);
    // 편집 화면이 "저장하면 바로 나가요 / 시작 시각부터 나가요"를 말할 때 쓰는 서버 시각(밀리초).
    // 관리자 PC 시계로 판단하면 앱 API(서버 시계)와 다른 말을 한다 (#385 E).
    data.put("serverNow", noticeService.now().atZone(NoticeService.ZONE).toInstant().toEpochMilli());
    model.addAttribute("hideDays", hideDays);
    model.addAttribute("previewJson", toJson(data));
  }

  private static Map<String, Object> previewSlide(AppNotice notice) {
    Map<String, Object> slide = new LinkedHashMap<>();
    slide.put("id", notice.getId());
    slide.put("title", notice.getTitle());
    slide.put("body", notice.getBody());
    slide.put("imageUrl", notice.getImageKey() == null ? null : "/admin/notices/" + notice.getId() + "/image");
    slide.put("buttonLabel", notice.getButtonLabel());
    slide.put("buttonUrl", notice.getButtonUrl());
    slide.put("platform", notice.getPlatform().name());
    slide.put("priority", notice.getPriority());
    slide.put("startsAt", notice.getStartsAt().format(ISO_MINUTE));
    return slide;
  }

  private static String toJson(Map<String, Object> data) {
    try {
      return JSON.writeValueAsString(data);
    } catch (JsonProcessingException e) {
      // 미리보기가 없어도 편집은 된다. 빈 자료로 그리고 원인은 남긴다.
      log.warn("[공지 관리] 미리보기 자료를 만들지 못했습니다", e);
      return "{\"hideDays\":7,\"notices\":[]}";
    }
  }

  /** 오류마다 무엇을 고치면 되는지와 추적용 코드를 함께 준다. */
  private static String failureReason(CustomException e) {
    return switch (e.getErrorCode()) {
      case NOTICE_TITLE_BLANK -> "제목을 적어주세요. 공백이나 ** 표기만 있으면 앱에 빈 제목이 떠요. (E-NTC-001)";
      case NOTICE_TITLE_TOO_LONG -> "제목은 ** 표기까지 세어 " + AppNotice.TITLE_MAX_LENGTH + "자까지예요. (E-NTC-002)";
      case NOTICE_TITLE_EMPHASIS_UNPAIRED ->
        "제목의 강조 표기 ** 짝이 맞지 않아요. 강조할 글자를 **이렇게** 앞뒤로 감싸 주세요. (E-NTC-003)";
      case NOTICE_BODY_BLANK -> "본문을 적어주세요. (E-NTC-004)";
      case NOTICE_BODY_TOO_LONG -> "본문은 " + AppNotice.BODY_MAX_LENGTH + "자까지예요. (E-NTC-005)";
      case NOTICE_BUTTON_INCOMPLETE -> "버튼은 문구와 링크를 함께 적거나 둘 다 비워 주세요. (E-NTC-006)";
      case NOTICE_BUTTON_LABEL_TOO_LONG ->
        "버튼 문구는 " + AppNotice.BUTTON_LABEL_MAX_LENGTH + "자까지예요. 버튼 한 줄에 들어가야 해요. (E-NTC-007)";
      case NOTICE_BUTTON_URL_INVALID ->
        "버튼 링크는 https:// 로 시작하는 주소만 받아요. (E-NTC-008)";
      case NOTICE_PERIOD_INVALID -> "시작 일시를 적고, 종료는 시작보다 늦게 적어 주세요. 종료를 비우면 끌 때까지 나가요. (E-NTC-009)";
      case NOTICE_PRIORITY_INVALID -> "우선순위는 숫자로 적어 주세요. 클수록 먼저 보여요. (E-NTC-010)";
      case NOTICE_PLATFORM_INVALID -> "플랫폼은 전체, iOS, Android 중에서 골라 주세요. (E-NTC-011)";
      case NOTICE_IMAGE_INVALID_TYPE -> "이미지는 png, jpg, webp 만 올릴 수 있어요. (E-NTC-012)";
      case NOTICE_IMAGE_TOO_LARGE -> "이미지는 2MB 까지예요. 크기를 줄여 주세요. (E-NTC-013)";
      case NOTICE_IMAGE_SAVE_FAILED -> "이미지를 저장하지 못했어요. 잠시 뒤 다시 해 주세요. (E-NTC-014)";
      case NOTICE_NOT_FOUND -> "공지를 찾을 수 없어요. 다른 관리자가 지웠을 수 있어요. (E-NTC-015)";
      default -> "저장하지 못했어요. (E-NTC-000)";
    };
  }

  /** 안내 문구에 쓰는 제목. 강조 표기는 걷어낸다 — "'**하루 3개**' 공지를…"는 읽기 어렵다. */
  private static String plainTitle(AppNotice notice) {
    return NoticeEmphasis.visibleText(notice.getTitle());
  }

  private static String name(Principal principal) {
    return principal == null ? null : principal.getName();
  }
}
