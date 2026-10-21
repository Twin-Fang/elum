package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.list.AdminListPeriod;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminNotificationList;
import com.chuseok22.elumserver.admin.application.service.AdminNotificationService;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;

/// 알림 기록 조회 (읽기 전용): 알림 목록, 회원을 고르면 그 회원의 안 읽음 수·푸시 설정 요약
@Controller
@RequiredArgsConstructor
public class AdminNotificationController {

  static final String LIST_PATH = "/admin/notifications";

  private final AdminNotificationService adminNotificationService;

  /// 목록: 검색어(q, 회원 아이디·호칭), 필터(memberId, type, read, from, to), 정렬(sort), 페이지(page, 1부터). 허용 밖 값·기간은 보정된다
  @GetMapping(LIST_PATH)
  public String list(
    @RequestParam(name = "q", required = false) String q,
    @RequestParam(name = "memberId", required = false) String memberId,
    @RequestParam(name = "type", required = false) String type,
    @RequestParam(name = "read", required = false) String read,
    @RequestParam(name = "from", required = false) String from,
    @RequestParam(name = "to", required = false) String to,
    @RequestParam(name = "sort", required = false) String sort,
    @RequestParam(name = "page", required = false) String page,
    Model model
  ) {
    Map<String, String> rawFilters = new HashMap<>();
    rawFilters.put(AdminNotificationList.FILTER_MEMBER_ID, memberId);
    rawFilters.put(AdminNotificationList.FILTER_TYPE, type);
    rawFilters.put(AdminNotificationList.FILTER_READ, read);
    rawFilters.put(AdminListPeriod.FILTER_FROM, from);
    rawFilters.put(AdminListPeriod.FILTER_TO, to);
    AdminListQuery query = AdminListPeriod.withCorrectedPeriod(
      AdminListQuery.of(q, rawFilters, sort, page, AdminNotificationList.DEFINITION), LocalDate.now());

    AdminNotificationService.SearchResult result = adminNotificationService.search(query);
    String selectedMemberId = AdminNotificationList.memberIdOf(query);
    model.addAttribute("notifications", result.rows());
    model.addAttribute("isMemberSearchTruncated", result.isMemberSearchTruncated());
    model.addAttribute("selectedMemberId", selectedMemberId);
    model.addAttribute("memberSummary",
      selectedMemberId == null ? null : adminNotificationService.summarizeMember(selectedMemberId).orElse(null));
    model.addAttribute("typeOptions", AdminNotificationList.TYPE_OPTIONS);
    model.addAttribute("definition", AdminNotificationList.DEFINITION);
    model.addAttribute("query", query);
    // 페이저 링크가 검색·필터·정렬을 유지하도록 (page 는 페이저가 붙임)
    model.addAttribute("pagerBaseUrl", LIST_PATH + query.toQueryString(query.sort(), 1));
    return "admin/notifications";
  }
}
