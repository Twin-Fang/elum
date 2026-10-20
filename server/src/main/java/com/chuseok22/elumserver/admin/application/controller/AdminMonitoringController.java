package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminMonitoringList;
import com.chuseok22.elumserver.admin.application.service.AdminMonitoringService;
import com.chuseok22.elumserver.admin.application.service.AdminStatsService;
import com.chuseok22.elumserver.ai.application.service.AiCallStatsService;
import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.infrastructure.entity.AiCallLog;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;

@Controller
@RequiredArgsConstructor
public class AdminMonitoringController {

  private final AdminMonitoringService adminMonitoringService;
  private final AdminStatsService adminStatsService;
  private final AiCallStatsService aiCallStatsService;

  /// 모니터링: 필터(callType, success, memberId, from, to), 정렬(sort), 페이지(page, 1부터). 허용 밖 값·기간은 보정된다
  @GetMapping("/admin/monitoring")
  public String monitoring(
    @RequestParam(name = "callType", required = false) String callType,
    @RequestParam(name = "success", required = false) String success,
    @RequestParam(name = "memberId", required = false) String memberId,
    @RequestParam(name = "from", required = false) String from,
    @RequestParam(name = "to", required = false) String to,
    @RequestParam(name = "sort", required = false) String sort,
    @RequestParam(name = "page", required = false) String page,
    Model model
  ) {
    Map<String, String> rawFilters = new HashMap<>();
    rawFilters.put(AdminMonitoringList.FILTER_CALL_TYPE, callType);
    rawFilters.put(AdminMonitoringList.FILTER_SUCCESS, success);
    rawFilters.put(AdminMonitoringList.FILTER_MEMBER_ID, memberId);
    rawFilters.put(AdminMonitoringList.FILTER_FROM, from);
    rawFilters.put(AdminMonitoringList.FILTER_TO, to);
    AdminListQuery query = AdminMonitoringList.withCorrectedPeriod(
      AdminListQuery.of(null, rawFilters, sort, page, AdminMonitoringList.DEFINITION), LocalDate.now());

    Page<AiCallLog> calls = adminMonitoringService.search(query);
    model.addAttribute("todayStats", adminMonitoringService.getTodayStats());
    model.addAttribute("totalStats", adminMonitoringService.getTotalStats());
    // 이번 달 요약·제공자 상태 (사용량 추이 그래프는 화면 스크립트가 따로 불러옴)
    LocalDateTime now = LocalDateTime.now();
    model.addAttribute("monthSummary", adminStatsService.loadAiMonthSummary(now));
    model.addAttribute("aiHealth", aiCallStatsService.loadHealthSnapshot(now));
    model.addAttribute("calls", calls);
    model.addAttribute("callTypes", AiCallType.values());
    model.addAttribute("definition", AdminMonitoringList.DEFINITION);
    model.addAttribute("query", query);
    // 페이저 링크가 필터·정렬을 유지하도록 (page 는 페이저가 붙임)
    model.addAttribute("pagerBaseUrl", "/admin/monitoring" + query.toQueryString(query.sort(), 1));
    return "admin/monitoring";
  }
}
