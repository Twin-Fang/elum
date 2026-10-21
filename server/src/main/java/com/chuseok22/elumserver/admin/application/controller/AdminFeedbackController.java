package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.list.AdminCsvExporter;
import com.chuseok22.elumserver.admin.application.list.AdminCsvExporter.ExportRows;
import com.chuseok22.elumserver.admin.application.list.AdminFeedbackList;
import com.chuseok22.elumserver.admin.application.list.AdminListPaging;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.feedback.application.service.FeedbackService;
import com.chuseok22.elumserver.feedback.core.FeedbackStatus;
import com.chuseok22.elumserver.feedback.infrastructure.entity.Feedback;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.security.Principal;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/// 보호자가 보낸 의견을 관리자 화면에서 보고, 처리 상태를 바꾸고, 지우고, CSV 로 내보낸다. 자동 삭제는 없다.
@Slf4j
@Controller
@RequiredArgsConstructor
public class AdminFeedbackController {

  private static final String LIST_PATH = "/admin/feedback";
  /// 상태 변경 폼이 돌아갈 곳: 상세에서 눌렀으면 상세, 아니면 (검색·필터가 유지된) 목록
  static final String RETURN_TO_DETAIL = "detail";
  /// 상태 변경 폼이 목록 조건을 실어 보내는 파라미터 접두어: return.q, return.status, return.sort ...
  static final String RETURN_PARAMETER_PREFIX = "return.";
  /// CSV 파일명 접두어: feedback_{yyyyMMdd}.csv
  private static final String CSV_FILE_PREFIX = "feedback";

  private final FeedbackService feedbackService;
  private final AdminDateFormatter adminDateFormatter;

  /// 의견 목록: 검색어(q), 필터(AdminFeedbackList 정의 5개), 정렬(sort), 페이지(page, 1부터). 허용 밖 값은 보정된다
  @GetMapping(LIST_PATH)
  public String list(@RequestParam Map<String, String> parameters, Model model) {
    AdminListQuery query = AdminListQuery.fromParameters(parameters, AdminFeedbackList.DEFINITION);
    Page<Feedback> feedbacks = AdminListPaging.fetchWithPageCorrection(query,
      condition -> feedbackService.search(AdminFeedbackList.searchOf(condition),
        AdminFeedbackList.sortOf(condition), condition.pageIndex()));
    model.addAttribute("feedbacks", feedbacks);
    model.addAttribute("definition", AdminFeedbackList.DEFINITION);
    model.addAttribute("query", query);
    model.addAttribute("statuses", FeedbackStatus.values());
    // 페이저 링크가 검색·필터·정렬을 유지하도록 (page 는 페이저가 붙임)
    model.addAttribute("pagerBaseUrl", LIST_PATH + query.toQueryString(query.sort(), 1));
    model.addAttribute("csvExport", AdminCsvExporter.linkOf(LIST_PATH, query, feedbacks.getTotalElements()));
    return "admin/feedback";
  }

  /// 의견 CSV: 목록과 같은 조건 > 상한 이내면 파일, 넘으면 같은 조건 목록으로 돌아가 안내 (내보낸 관리자·건수 기록)
  @GetMapping(LIST_PATH + AdminCsvExporter.EXPORT_PATH_SUFFIX)
  public ResponseEntity<byte[]> exportCsv(
    @RequestParam Map<String, String> parameters, Principal principal,
    HttpServletRequest request, HttpServletResponse response
  ) {
    AdminListQuery query = AdminListQuery.fromParameters(parameters, AdminFeedbackList.DEFINITION);
    ExportRows<Feedback> export = ExportRows.fromPage(feedbackService.searchFirstRows(
      AdminFeedbackList.searchOf(query), AdminFeedbackList.sortOf(query), AdminCsvExporter.MAX_ROWS));
    if (export.isOverLimit()) {
      log.info("[admin csv] rejected feedback : total={} over limit", export.totalCount());
      return AdminCsvExporter.redirectOverLimit(LIST_PATH, query, export.totalCount(), request, response);
    }
    log.info("[admin csv] exported feedback : rows={}, admin={}", export.rows().size(),
      principal == null ? null : principal.getName());
    return AdminCsvExporter.toAttachment(CSV_FILE_PREFIX, LocalDate.now(),
      AdminFeedbackList.csvColumns(adminDateFormatter), export.rows());
  }

  @GetMapping("/admin/feedback/{id}")
  public String detail(@PathVariable("id") String id, Model model) {
    model.addAttribute("feedback", feedbackService.get(id));
    model.addAttribute("statuses", FeedbackStatus.values());
    return "admin/feedback-detail";
  }

  /**
   * 처리 상태 변경: 상태 해석 > 변경(변경자·시각 기록) > 돌아가기
   * 알 수 없는 상태 값은 바꾸지 않고 안내 (폼을 고쳐 쓴 요청). 목록 조건은 return.* 파라미터로 받아 정의로 보정
   */
  @PostMapping("/admin/feedback/{id}/status")
  public String changeStatus(
    @PathVariable("id") String id,
    @RequestParam("status") String status,
    @RequestParam(name = "returnTo", required = false) String returnTo,
    @RequestParam Map<String, String> parameters,
    Principal principal,
    RedirectAttributes redirectAttributes
  ) {
    String destination = RETURN_TO_DETAIL.equals(returnTo)
      ? LIST_PATH + "/" + id
      : listPathOf(AdminListQuery.fromParameters(returnParametersOf(parameters), AdminFeedbackList.DEFINITION));
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

  /// return.* 파라미터 > 접두어를 뗀 목록 파라미터 (그 밖의 폼 값은 버림)
  private static Map<String, String> returnParametersOf(Map<String, String> parameters) {
    Map<String, String> returnParameters = new LinkedHashMap<>();
    parameters.forEach((key, value) -> {
      if (key.startsWith(RETURN_PARAMETER_PREFIX)) {
        returnParameters.put(key.substring(RETURN_PARAMETER_PREFIX.length()), value);
      }
    });
    return returnParameters;
  }
}
