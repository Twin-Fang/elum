package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.request.ExpertRoutineEditForm;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.expertroutine.application.service.ExpertRoutineAdminService;
import com.chuseok22.elumserver.expertroutine.application.service.ExpertRoutineInputRules;
import com.chuseok22.elumserver.expertroutine.core.ExpertRoutineReviewStatus;
import com.chuseok22.elumserver.expertroutine.infrastructure.entity.ExpertRoutine;
import com.chuseok22.elumserver.routine.infrastructure.constant.RewardPreset;
import com.chuseok22.elumserver.talk.core.TalkCategory;
import jakarta.servlet.http.HttpServletResponse;
import java.security.Principal;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/**
 * 관리자 전문가 일과 화면: 목록, 만들기·고치기, 공개·내리기, 지우기, 보호자 일과에서 초안 만들기
 * 저장 검증에 걸리면 리다이렉트 없이 입력 그대로 다시 그림 (상태 코드는 실패 그대로, 문구에 E-EXR 코드)
 */
@Slf4j
@Controller
@RequiredArgsConstructor
public class AdminExpertRoutineController {

  private static final String LIST = "redirect:/admin/expert-routines";
  private static final String LIST_VIEW = "admin/expert-routines";
  private static final String EDIT_VIEW = "admin/expert-routine-edit";

  private final ExpertRoutineAdminService expertRoutineAdminService;

  @GetMapping("/admin/expert-routines")
  public String list(Model model) {
    model.addAttribute("routines", expertRoutineAdminService.listAll());
    return LIST_VIEW;
  }

  @GetMapping("/admin/expert-routines/new")
  public String newForm(Model model) {
    addEditModel(model, ExpertRoutineEditForm.blank(), null);
    return EDIT_VIEW;
  }

  @GetMapping("/admin/expert-routines/{id}")
  public String edit(@PathVariable("id") String id, Model model) {
    ExpertRoutine routine = expertRoutineAdminService.get(id);
    addEditModel(model, ExpertRoutineEditForm.of(routine, expertRoutineAdminService.stepsOf(id)), routine);
    return EDIT_VIEW;
  }

  @PostMapping("/admin/expert-routines")
  public String create(
    @ModelAttribute("form") ExpertRoutineEditForm form,
    Principal principal,
    Model model,
    HttpServletResponse response,
    RedirectAttributes redirectAttributes
  ) {
    try {
      ExpertRoutine saved = expertRoutineAdminService.create(form.toInput(), name(principal));
      redirectAttributes.addFlashAttribute("message", "'" + saved.getTitle() + "' 전문가 일과를 만들었어요. 아직 앱에는 나가지 않아요.");
      return LIST;
    } catch (CustomException e) {
      return rejected(e, form, null, model, response);
    }
  }

  @PostMapping("/admin/expert-routines/{id}")
  public String update(
    @PathVariable("id") String id,
    @ModelAttribute("form") ExpertRoutineEditForm form,
    Principal principal,
    Model model,
    HttpServletResponse response,
    RedirectAttributes redirectAttributes
  ) {
    try {
      ExpertRoutine saved = expertRoutineAdminService.update(id, form.toInput(), name(principal));
      redirectAttributes.addFlashAttribute("message", "'" + saved.getTitle() + "' 전문가 일과를 저장했어요."
        + (saved.isVisibleInApp() ? " 앱에 바로 반영돼요." : ""));
      return LIST;
    } catch (CustomException e) {
      return rejected(e, form, expertRoutineAdminService.get(id), model, response);
    }
  }

  /// 공개·내리기: 공개는 검수 완료일 때만 (실패 사유는 목록 위 안내)
  @PostMapping("/admin/expert-routines/{id}/published")
  public String setPublished(
    @PathVariable("id") String id,
    @RequestParam("published") boolean isPublished,
    Principal principal,
    RedirectAttributes redirectAttributes
  ) {
    try {
      ExpertRoutine saved = expertRoutineAdminService.setPublished(id, isPublished, name(principal));
      redirectAttributes.addFlashAttribute("message", "'" + saved.getTitle() + "' 전문가 일과를 "
        + (isPublished ? "공개했어요. Pro 보호자 앱 목록에 나가요." : "내렸어요. 이미 가져간 일과는 그대로 남아요."));
    } catch (CustomException e) {
      log.info("[expert routine admin] publish rejected : code={}, reason={}", e.getErrorCode().name(), e.getDetail());
      redirectAttributes.addFlashAttribute("errorMessage", failureReason(e));
    }
    return LIST;
  }

  @PostMapping("/admin/expert-routines/{id}/delete")
  public String delete(@PathVariable("id") String id, RedirectAttributes redirectAttributes) {
    String title = expertRoutineAdminService.get(id).getTitle();
    expertRoutineAdminService.delete(id);
    redirectAttributes.addFlashAttribute("message", "'" + title + "' 전문가 일과를 지웠어요. 이미 가져간 일과는 그대로 남아요.");
    return LIST;
  }

  /// 보호자 일과 id > 이름을 지운 초안 > 그 초안 편집 화면
  @PostMapping("/admin/expert-routines/from-routine")
  public String createFromRoutine(
    @RequestParam(value = "routineId", required = false) String routineId,
    Principal principal,
    RedirectAttributes redirectAttributes
  ) {
    try {
      ExpertRoutine draft = expertRoutineAdminService.createDraftFromRoutine(routineId, name(principal));
      redirectAttributes.addFlashAttribute("message",
        "보호자 일과에서 초안을 만들었어요. 이름·장소가 남았는지 확인하고 분류·보상을 정해 주세요.");
      return "redirect:/admin/expert-routines/" + draft.getId();
    } catch (CustomException e) {
      log.info("[expert routine admin] copy rejected : code={}, reason={}", e.getErrorCode().name(), e.getDetail());
      redirectAttributes.addFlashAttribute("errorMessage", failureReason(e));
      return LIST;
    }
  }

  // ── 도움 ────────────────────────────────────────────

  private void addEditModel(Model model, ExpertRoutineEditForm form, ExpertRoutine routine) {
    model.addAttribute("form", form);
    model.addAttribute("routine", routine);
    model.addAttribute("categories", TalkCategory.values());
    model.addAttribute("languages", AppLocale.values());
    model.addAttribute("reviewStatuses", ExpertRoutineReviewStatus.values());
    model.addAttribute("rewardPresets", RewardPreset.values());
  }

  private String rejected(
    CustomException e, ExpertRoutineEditForm form, ExpertRoutine routine, Model model, HttpServletResponse response
  ) {
    addEditModel(model, form, routine);
    model.addAttribute("errorMessage", failureReason(e));
    // 화면은 그리되 상태 코드는 실패로 둔다 (200 이면 모니터링이 성공으로 셈)
    response.setStatus(e.getErrorCode().getStatus().value());
    log.info("[expert routine admin] save rejected : code={}, reason={}", e.getErrorCode().name(), e.getDetail());
    return EDIT_VIEW;
  }

  /** 오류마다 무엇을 고치면 되는지와 추적 코드 */
  static String failureReason(CustomException e) {
    if (e.getErrorCode() == ErrorCode.ROUTINE_NOT_FOUND) {
      return "그 id 의 보호자 일과가 없어요. 루틴 관리 상세 화면의 일과 id 를 붙여 넣어 주세요. (E-EXR-020)";
    }
    if (e.getErrorCode() == ErrorCode.EXPERT_ROUTINE_NOT_FOUND) {
      return "전문가 일과를 찾을 수 없어요. 다른 관리자가 지웠을 수 있어요. (E-EXR-021)";
    }
    if (e.getErrorCode() != ErrorCode.EXPERT_ROUTINE_INVALID || e.getDetail() == null) {
      return "저장하지 못했어요. (E-EXR-000)";
    }
    return switch (e.getDetail()) {
      case ExpertRoutineInputRules.REASON_TITLE_REQUIRED -> "제목을 적어 주세요. (E-EXR-001)";
      case ExpertRoutineInputRules.REASON_TITLE_TOO_LONG -> "제목은 " + ExpertRoutine.TITLE_MAX_LENGTH + "자까지예요. (E-EXR-002)";
      case ExpertRoutineInputRules.REASON_SUMMARY_TOO_LONG ->
        "한 줄 설명은 " + ExpertRoutine.SUMMARY_MAX_LENGTH + "자까지예요. (E-EXR-003)";
      case ExpertRoutineInputRules.REASON_CATEGORY_INVALID -> "분류를 골라 주세요. (E-EXR-004)";
      case ExpertRoutineInputRules.REASON_LANGUAGE_INVALID -> "언어는 ko, en, ja, zh, es 중에서 골라 주세요. (E-EXR-005)";
      case ExpertRoutineInputRules.REASON_REWARD_TOO_LONG ->
        "보상 제안은 " + ExpertRoutine.REWARD_TEXT_MAX_LENGTH + "자까지예요. (E-EXR-006)";
      case ExpertRoutineInputRules.REASON_SORT_ORDER_INVALID -> "순서는 숫자로 적어 주세요. 작을수록 위에 보여요. (E-EXR-007)";
      case ExpertRoutineInputRules.REASON_STEPS_REQUIRED -> "카드를 한 장 이상 적어 주세요. 한 줄이 카드 한 장이에요. (E-EXR-008)";
      case ExpertRoutineInputRules.REASON_STEPS_TOO_MANY -> "카드는 10장까지예요. (E-EXR-009)";
      case ExpertRoutineInputRules.REASON_STEP_TEXT_TOO_LONG -> "카드 문장은 200자까지예요. (E-EXR-010)";
      case ExpertRoutineInputRules.REASON_PICTOGRAM_UNKNOWN ->
        "없는 픽토그램 id 가 있어요. pictograms/catalog.json 의 id 를 그대로 적어 주세요. (E-EXR-011)";
      case ExpertRoutineInputRules.REASON_EXAMPLE_IMAGE_INVALID ->
        "예시 이미지 id 는 소문자·숫자·밑줄만 써요. 모르면 비워 두세요. (E-EXR-012)";
      case ExpertRoutineInputRules.REASON_NOT_REVIEWED ->
        "검수를 마친 일과만 공개할 수 있어요. 검수 상태를 '검수 완료'로 바꾸고 검수한 분을 메모에 남겨 주세요. (E-EXR-013)";
      default -> "저장하지 못했어요. (E-EXR-000)";
    };
  }

  private static String name(Principal principal) {
    return principal == null ? null : principal.getName();
  }
}
