package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.list.AdminAdRewardList;
import com.chuseok22.elumserver.admin.application.list.AdminListPeriod;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.service.AdminAdRewardService;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;

/// 광고 보상 조회 (읽기 전용): 세션 목록·상태 요약, 세션 상세(콜백 결과·지급 내역·타임라인)
@Controller
@RequiredArgsConstructor
public class AdminAdRewardController {

  static final String LIST_PATH = "/admin/ad-rewards";

  private final AdminAdRewardService adminAdRewardService;

  /// 목록: 검색어(q, 회원 아이디·호칭), 필터(memberId, status, reason, from, to), 정렬(sort), 페이지(page, 1부터). 허용 밖 값·기간은 보정된다
  @GetMapping(LIST_PATH)
  public String list(
    @RequestParam(name = "q", required = false) String q,
    @RequestParam(name = "memberId", required = false) String memberId,
    @RequestParam(name = "status", required = false) String status,
    @RequestParam(name = "reason", required = false) String reason,
    @RequestParam(name = "from", required = false) String from,
    @RequestParam(name = "to", required = false) String to,
    @RequestParam(name = "sort", required = false) String sort,
    @RequestParam(name = "page", required = false) String page,
    Model model
  ) {
    Map<String, String> rawFilters = new HashMap<>();
    rawFilters.put(AdminAdRewardList.FILTER_MEMBER_ID, memberId);
    rawFilters.put(AdminAdRewardList.FILTER_STATUS, status);
    rawFilters.put(AdminAdRewardList.FILTER_REASON, reason);
    rawFilters.put(AdminListPeriod.FILTER_FROM, from);
    rawFilters.put(AdminListPeriod.FILTER_TO, to);
    LocalDateTime now = LocalDateTime.now();
    AdminListQuery query = AdminListPeriod.withCorrectedPeriod(
      AdminListQuery.of(q, rawFilters, sort, page, AdminAdRewardList.DEFINITION), now.toLocalDate());

    AdminAdRewardService.SearchResult result = adminAdRewardService.search(query, now);
    model.addAttribute("sessions", result.rows());
    model.addAttribute("isMemberSearchTruncated", result.isMemberSearchTruncated());
    model.addAttribute("todaySummary", adminAdRewardService.summarizeToday(now).orElse(null));
    model.addAttribute("periodSummary", adminAdRewardService.summarizePeriod(query, now).orElse(null));
    model.addAttribute("statusOptions", AdminAdRewardList.STATUS_OPTIONS);
    model.addAttribute("reasonOptions", AdminAdRewardList.REASON_OPTIONS);
    model.addAttribute("definition", AdminAdRewardList.DEFINITION);
    model.addAttribute("query", query);
    // 페이저 링크가 검색·필터·정렬을 유지하도록 (page 는 페이저가 붙임)
    model.addAttribute("pagerBaseUrl", LIST_PATH + query.toQueryString(query.sort(), 1));
    return "admin/ad-rewards";
  }

  /// 상세: 세션 한 건. 없는 id 는 404 오류 화면
  @GetMapping(LIST_PATH + "/{id}")
  public String detail(@PathVariable("id") String id, Model model) {
    model.addAttribute("detail", adminAdRewardService.getDetail(id, LocalDateTime.now()));
    return "admin/ad-reward-detail";
  }
}
