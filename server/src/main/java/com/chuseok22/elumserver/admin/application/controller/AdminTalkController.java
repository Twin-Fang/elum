package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.list.AdminListDefaults;
import com.chuseok22.elumserver.admin.application.list.AdminListPaging;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminTalkPostList;
import com.chuseok22.elumserver.admin.application.list.AdminTalkReportList;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage.ImageContent;
import com.chuseok22.elumserver.talk.application.dto.response.TalkAdminChange;
import com.chuseok22.elumserver.talk.application.dto.response.TalkAdminPostRow;
import com.chuseok22.elumserver.talk.application.dto.response.TalkAdminReportRow;
import com.chuseok22.elumserver.talk.application.service.TalkAdminService;
import java.util.HashMap;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/// 이야기 관리: 글 목록·상세, 글·댓글 가리기와 되돌리기, 신고 목록과 처리. 자동으로 가리거나 지우지 않는다.
@Controller
@RequiredArgsConstructor
public class AdminTalkController {

  private static final String POSTS_PATH = "/admin/talk/posts";
  private static final String REPORTS_PATH = "/admin/talk/reports";
  /// 신고 처리 폼이 돌아갈 곳: 글 상세에서 눌렀으면 그 글 상세, 아니면 (필터·정렬이 유지된) 신고 목록
  static final String RETURN_TO_DETAIL = "detail";

  private final TalkAdminService talkAdminService;

  /// 글 목록: 검색어(q, 제목), 상태 필터(status), 정렬(sort), 페이지(page, 1부터). 허용 밖 값은 보정된다
  @GetMapping(POSTS_PATH)
  public String listPosts(
    @RequestParam(name = "q", required = false) String q,
    @RequestParam(name = "status", required = false) String status,
    @RequestParam(name = "sort", required = false) String sort,
    @RequestParam(name = "page", required = false) String page,
    Model model
  ) {
    Map<String, String> rawFilters = new HashMap<>();
    rawFilters.put(AdminTalkPostList.FILTER_STATUS, status);
    AdminListQuery query = AdminListQuery.of(q, rawFilters, sort, page, AdminTalkPostList.DEFINITION);
    Page<TalkAdminPostRow> posts = AdminListPaging.fetchWithPageCorrection(query,
      condition -> talkAdminService.searchPosts(condition.likePattern(), AdminTalkPostList.statusFilterOf(condition),
        PageRequest.of(condition.pageIndex(), AdminListDefaults.PAGE_SIZE, AdminTalkPostList.sortOf(condition))));
    model.addAttribute("posts", posts);
    model.addAttribute("definition", AdminTalkPostList.DEFINITION);
    model.addAttribute("query", query);
    model.addAttribute("unresolvedReportCount", talkAdminService.countUnresolvedReports());
    // 페이저 링크가 검색·필터·정렬을 유지하도록 (page 는 페이저가 붙임)
    model.addAttribute("pagerBaseUrl", POSTS_PATH + query.toQueryString(query.sort(), 1));
    return "admin/talk";
  }

  @GetMapping(POSTS_PATH + "/{id}")
  public String postDetail(@PathVariable("id") String id, Model model) {
    model.addAttribute("detail", talkAdminService.getPostDetail(id));
    return "admin/talk-detail";
  }

  @PostMapping(POSTS_PATH + "/{id}/hide")
  public String hidePost(@PathVariable("id") String id, RedirectAttributes redirectAttributes) {
    TalkAdminChange change = talkAdminService.hidePost(id);
    addChangeMessage(redirectAttributes, change, "글을 가렸어요. 앱에서는 더 이상 보이지 않아요.",
      "이미 가렸거나 글쓴이가 지운 글이라 바꾸지 않았어요.");
    return "redirect:" + postDetailPath(id);
  }

  @PostMapping(POSTS_PATH + "/{id}/restore")
  public String restorePost(@PathVariable("id") String id, RedirectAttributes redirectAttributes) {
    TalkAdminChange change = talkAdminService.restorePost(id);
    if (change.result() == TalkAdminChange.Result.SOURCE_ALREADY_VISIBLE) {
      redirectAttributes.addFlashAttribute("errorMessage",
        "같은 일과로 올린 보이는 글이 이미 있어서 되돌리지 못했어요. 그 글을 먼저 가려 주세요.");
    } else {
      addChangeMessage(redirectAttributes, change, "글을 되돌렸어요. 앱에 다시 보여요.",
        "가린 글이 아니라서 바꾸지 않았어요. 글쓴이가 지운 글은 되돌릴 수 없어요.");
    }
    return "redirect:" + postDetailPath(id);
  }

  @PostMapping("/admin/talk/comments/{id}/hide")
  public String hideComment(@PathVariable("id") String id, RedirectAttributes redirectAttributes) {
    TalkAdminChange change = talkAdminService.hideComment(id);
    addChangeMessage(redirectAttributes, change, "댓글을 가렸어요. 앱에서는 더 이상 보이지 않아요.",
      "이미 가렸거나 쓴 사람이 지운 댓글이라 바꾸지 않았어요.");
    return "redirect:" + postDetailPath(change.postId());
  }

  @PostMapping("/admin/talk/comments/{id}/restore")
  public String restoreComment(@PathVariable("id") String id, RedirectAttributes redirectAttributes) {
    TalkAdminChange change = talkAdminService.restoreComment(id);
    addChangeMessage(redirectAttributes, change, "댓글을 되돌렸어요. 앱에 다시 보여요.",
      "가린 댓글이 아니라서 바꾸지 않았어요. 쓴 사람이 지운 댓글은 되돌릴 수 없어요.");
    return "redirect:" + postDetailPath(change.postId());
  }

  /// 신고 목록: 처리 여부 필터(resolved), 정렬(sort), 페이지(page, 1부터). 허용 밖 값은 보정된다
  @GetMapping(REPORTS_PATH)
  public String listReports(
    @RequestParam(name = "resolved", required = false) String resolved,
    @RequestParam(name = "sort", required = false) String sort,
    @RequestParam(name = "page", required = false) String page,
    Model model
  ) {
    AdminListQuery query = reportQueryOf(resolved, sort, page);
    Page<TalkAdminReportRow> reports = AdminListPaging.fetchWithPageCorrection(query,
      condition -> talkAdminService.searchReports(AdminTalkReportList.resolvedFilterOf(condition),
        PageRequest.of(condition.pageIndex(), AdminListDefaults.PAGE_SIZE, AdminTalkReportList.sortOf(condition))));
    model.addAttribute("reports", reports);
    model.addAttribute("definition", AdminTalkReportList.DEFINITION);
    model.addAttribute("query", query);
    model.addAttribute("pagerBaseUrl", REPORTS_PATH + query.toQueryString(query.sort(), 1));
    return "admin/talk-reports";
  }

  /**
   * 신고 처리: 처리 시각 기록 > 돌아가기 (글 상세에서 눌렀으면 그 글, 아니면 필터·정렬·페이지가 유지된 신고 목록)
   * 신고만 처리하고 글·댓글은 건드리지 않는다
   */
  @PostMapping(REPORTS_PATH + "/{id}/resolve")
  public String resolveReport(
    @PathVariable("id") String id,
    @RequestParam(name = "returnTo", required = false) String returnTo,
    @RequestParam(name = "returnResolved", required = false) String returnResolved,
    @RequestParam(name = "returnSort", required = false) String returnSort,
    @RequestParam(name = "returnPage", required = false) String returnPage,
    RedirectAttributes redirectAttributes
  ) {
    TalkAdminChange change = talkAdminService.resolveReport(id);
    addChangeMessage(redirectAttributes, change, "신고를 처리한 것으로 표시했어요.", "이미 처리한 신고예요.");
    if (RETURN_TO_DETAIL.equals(returnTo)) {
      return "redirect:" + postDetailPath(change.postId());
    }
    AdminListQuery query = reportQueryOf(returnResolved, returnSort, returnPage);
    return "redirect:" + REPORTS_PATH + query.toQueryString(query.sort(), query.page());
  }

  /// 카드 그림: 가린·지운 글도 본다. 캐시하지 않고(숨긴 뒤에도 남지 않게) 내용 추측을 막는다
  @GetMapping(POSTS_PATH + "/{id}/steps/{stepOrder}/image")
  @ResponseBody
  public ResponseEntity<byte[]> stepImage(@PathVariable("id") String id, @PathVariable("stepOrder") int stepOrder) {
    ImageContent content = talkAdminService.stepImage(id, stepOrder);
    return ResponseEntity.ok()
      .cacheControl(CacheControl.noStore())
      .contentType(MediaType.parseMediaType(content.contentType()))
      .header("X-Content-Type-Options", "nosniff")
      .body(content.bytes());
  }

  private static void addChangeMessage(
    RedirectAttributes redirectAttributes, TalkAdminChange change, String changedMessage, String unchangedMessage
  ) {
    redirectAttributes.addFlashAttribute(change.isChanged() ? "message" : "errorMessage",
      change.isChanged() ? changedMessage : unchangedMessage);
  }

  private static String postDetailPath(String postId) {
    return POSTS_PATH + "/" + postId;
  }

  private static AdminListQuery reportQueryOf(String resolved, String sort, String page) {
    Map<String, String> rawFilters = new HashMap<>();
    rawFilters.put(AdminTalkReportList.FILTER_RESOLVED, resolved);
    return AdminListQuery.of(null, rawFilters, sort, page, AdminTalkReportList.DEFINITION);
  }
}
