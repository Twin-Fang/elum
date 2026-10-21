package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.list.AdminCsvExporter;
import com.chuseok22.elumserver.admin.application.list.AdminCsvExporter.ExportRows;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminMonitoringList;
import com.chuseok22.elumserver.admin.application.service.AdminMonitoringService;
import com.chuseok22.elumserver.admin.application.service.AdminStatsService;
import com.chuseok22.elumserver.ai.application.service.AiCallStatsService;
import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.infrastructure.entity.AiCallLog;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.security.Principal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;

@Slf4j
@Controller
@RequiredArgsConstructor
public class AdminMonitoringController {

  private static final String LIST_PATH = "/admin/monitoring";
  /// CSV 파일명 접두어: ai-calls_{yyyyMMdd}.csv
  private static final String CSV_FILE_PREFIX = "ai-calls";

  private final AdminMonitoringService adminMonitoringService;
  private final AdminStatsService adminStatsService;
  private final AiCallStatsService aiCallStatsService;
  private final AdminDateFormatter adminDateFormatter;

  /// 모니터링: 필터(AdminMonitoringList 정의 8개), 정렬(sort), 페이지(page, 1부터). 허용 밖 값·기간은 보정된다
  @GetMapping(LIST_PATH)
  public String monitoring(@RequestParam Map<String, String> parameters, Model model) {
    AdminListQuery query = queryOf(parameters);

    Page<AiCallLog> calls = adminMonitoringService.search(query);
    model.addAttribute("todayStats", adminMonitoringService.getTodayStats());
    model.addAttribute("totalStats", adminMonitoringService.getTotalStats());
    // 이번 달 요약·제공자 상태 (사용량 추이 그래프는 화면 스크립트가 따로 불러옴)
    LocalDateTime now = LocalDateTime.now();
    model.addAttribute("monthSummary", adminStatsService.loadAiMonthSummary(now));
    model.addAttribute("aiHealth", aiCallStatsService.loadHealthSnapshot(now));
    model.addAttribute("calls", calls);
    model.addAttribute("memberNicknames", memberNicknamesOrEmpty(calls));
    model.addAttribute("csvExport", AdminCsvExporter.linkOf(LIST_PATH, query, calls.getTotalElements()));
    model.addAttribute("callTypes", AiCallType.values());
    model.addAttribute("definition", AdminMonitoringList.DEFINITION);
    model.addAttribute("query", query);
    // 페이저 링크가 필터·정렬을 유지하도록 (page 는 페이저가 붙임)
    model.addAttribute("pagerBaseUrl", LIST_PATH + query.toQueryString(query.sort(), 1));
    return "admin/monitoring";
  }

  /// 모니터링 CSV: 목록과 같은 조건(보정된 기간 포함) > 상한 이내면 파일, 넘으면 같은 조건 목록으로 돌아가 안내
  @GetMapping(LIST_PATH + AdminCsvExporter.EXPORT_PATH_SUFFIX)
  public ResponseEntity<byte[]> exportCsv(
    @RequestParam Map<String, String> parameters, Principal principal,
    HttpServletRequest request, HttpServletResponse response
  ) {
    AdminListQuery query = queryOf(parameters);
    ExportRows<AiCallLog> export = adminMonitoringService.searchForExport(query);
    if (export.isOverLimit()) {
      log.info("[admin csv] rejected ai calls : total={} over limit", export.totalCount());
      return AdminCsvExporter.redirectOverLimit(LIST_PATH, query, export.totalCount(), request, response);
    }
    log.info("[admin csv] exported ai calls : rows={}, admin={}", export.rows().size(),
      principal == null ? null : principal.getName());
    return AdminCsvExporter.toAttachment(CSV_FILE_PREFIX, LocalDate.now(),
      AdminMonitoringList.csvColumns(adminDateFormatter), export.rows());
  }

  // 요청 파라미터 > 정의로 보정 + 기간 보정 (목록·CSV 공통)
  private static AdminListQuery queryOf(Map<String, String> parameters) {
    return AdminMonitoringList.withCorrectedPeriod(
      AdminListQuery.fromParameters(parameters, AdminMonitoringList.DEFINITION), LocalDate.now());
  }

  // 회원 닉네임 조회 실패는 표의 이름만 비우고 화면은 그대로 (원시 ID 로 대신 보임)
  private Map<String, String> memberNicknamesOrEmpty(Page<AiCallLog> calls) {
    try {
      return adminMonitoringService.memberNicknamesOf(calls.getContent());
    } catch (RuntimeException e) {
      log.warn("[admin monitoring] member nickname load failed", e);
      return Map.of();
    }
  }
}
