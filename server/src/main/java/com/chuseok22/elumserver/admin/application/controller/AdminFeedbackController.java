package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.list.AdminFeedbackList;
import com.chuseok22.elumserver.admin.application.list.AdminListPaging;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.feedback.application.service.FeedbackService;
import com.chuseok22.elumserver.feedback.core.FeedbackStatus;
import com.chuseok22.elumserver.feedback.infrastructure.entity.Feedback;
import java.security.Principal;
import java.util.HashMap;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/// 보호자가 보낸 의견을 관리자 화면에서 보고, 처리 상태를 바꾸고, 지운다. 자동 삭제는 없다.
@Controller
@RequiredArgsConstructor
public class AdminFeedbackController {

  private static final String LIST_PATH = "/admin/feedback";
  /// 상태 변경 폼이 돌아갈 곳: 상세에서 눌렀으면 상세, 아니면 (검색·필터가 유지된) 목록
  static final String RETURN_TO_DETAIL = "detail";

  private final FeedbackService feedbackService;

  /// 의견 목록: 검색어(q), 처리 상태 필터(status), 정렬(sort), 페이지(page, 1부터). 허용 밖 값은 보정된다
  @GetMapping(LIST_PATH)
  public String list(
    @RequestParam(name = "q", required = false) String q,
    @RequestParam(name = "status", required = false) String status,
    @RequestParam(name = "sort", required = false) String sort,
    @RequestParam(name = "page", required = false) String page,
    Model model
  ) {
    AdminListQuery query = queryOf(q, status, sort, page);
    Page<Feedback> feedbacks = AdminListPaging.fetchWithPageCorrection(query,
      condition -> feedbackService.search(condition.likePattern(), AdminFeedbackList.statusFilterOf(condition),
        AdminFeedbackList.sortOf(condition), condition.pageIndex()));
    model.addAttribute("feedbacks", feedbacks);
    model.addAttribute("definition", AdminFeedbackList.DEFINITION);
    model.addAttribute("query", query);
    model.addAttribute("statuses", FeedbackStatus.values());
    // 페이저 링크가 검색·필터·정렬을 유지하도록 (page 는 페이저가 붙임)
    model.addAttribute("pagerBaseUrl", LIST_PATH + query.toQueryString(query.sort(), 1));
    return "admin/feedback";
  }

  @GetMapping("/admin/feedback/{id}")
  public String detail(@PathVariable("id") String id, Model model) {
    model.addAttribute("feedback", feedbackService.get(id));
    model.addAttribute("statuses", FeedbackStatus.values());
    return "admin/feedback-detail";
  }

  /**
   * 처리 상태 변경: 상태 해석 > 변경(변경자·시각 기록) > 돌아가기
   * 알 수 없는 상태 값은 바꾸지 않고 안내 (폼을 고쳐 쓴 요청)
   */
  @PostMapping("/admin/feedback/{id}/status")
  public String changeStatus(
    @PathVariable("id") String id,
    @RequestParam("status") String status,
    @RequestParam(name = "returnTo", required = false) String returnTo,
    @RequestParam(name = "returnQ", required = false) String returnQ,
    @RequestParam(name = "returnStatus", required = false) String returnStatus,
    @RequestParam(name = "returnSort", required = false) String returnSort,
    @RequestParam(name = "returnPage", required = false) String returnPage,
    Principal principal,
    RedirectAttributes redirectAttributes
  ) {
    String destination = RETURN_TO_DETAIL.equals(returnTo)
      ? LIST_PATH + "/" + id
      : listPathOf(queryOf(returnQ, returnStatus, returnSort, returnPage));
    FeedbackStatus nextStatus = FeedbackStatus.fromName(status).orElse(null);
    if (nextStatus == null) {
      redirectAttributes.addFlashAttribute("errorMessage", "알 수 없는 처리 상태예요. 화면을 새로 고친 뒤 다시 골라 주세요.");
      return "redirect:" + destination;
    }
    feedbackService.changeStatus(id, nextStatus, principal == null ? null : principal.getName());
    redirectAttributes.addFlashAttribute("message", "처리 상태를 '" + nextStatus.getLabel() + "'(으)로 바꿨어요.");
    return "redirect:" + destination;
  }

  @PostMapping("/admin/feedback/{id}/delete")
  public String delete(@PathVariable("id") String id, RedirectAttributes redirectAttributes) {
    feedbackService.delete(id);
    redirectAttributes.addFlashAttribute("message", "의견을 지웠어요.");
    return "redirect:" + LIST_PATH;
  }

  /// 검색·필터·정렬·페이지를 유지한 목록 주소 (값은 정의로 보정·URL 인코딩된 것만 쓴다)
  private static String listPathOf(AdminListQuery query) {
    return LIST_PATH + query.toQueryString(query.sort(), query.page());
  }

  private static AdminListQuery queryOf(String q, String status, String sort, String page) {
    Map<String, String> rawFilters = new HashMap<>();
    rawFilters.put(AdminFeedbackList.FILTER_STATUS, status);
    return AdminListQuery.of(q, rawFilters, sort, page, AdminFeedbackList.DEFINITION);
  }
}
