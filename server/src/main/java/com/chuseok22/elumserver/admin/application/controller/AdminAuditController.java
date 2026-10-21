package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.list.AdminAuditList;
import com.chuseok22.elumserver.admin.application.list.AdminCsvExporter;
import com.chuseok22.elumserver.admin.application.list.AdminCsvExporter.ExportRows;
import com.chuseok22.elumserver.admin.application.list.AdminListPaging;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.service.AdminAuditService;
import com.chuseok22.elumserver.admin.infrastructure.entity.AdminAuditLog;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.security.Principal;
import java.time.LocalDate;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;

/// 관리자 기록 (#653): 목록(관리자·동작·대상·기간 필터, 최신순)과 CSV. 읽기 전용
@Slf4j
@Controller
@RequiredArgsConstructor
public class AdminAuditController {

  /// CSV 파일명 접두어: admin_audit_{yyyyMMdd}.csv
  private static final String CSV_FILE_PREFIX = "admin_audit";

  private final AdminAuditService adminAuditService;
  private final AdminDateFormatter adminDateFormatter;

  /// 관리자 기록 목록: 필터(AdminAuditList 정의 6개), 정렬(sort), 페이지(page, 1부터). 허용 밖 값은 보정된다
  @GetMapping(AdminAuditList.LIST_PATH)
  public String list(@RequestParam Map<String, String> parameters, Model model) {
    AdminListQuery query = AdminListQuery.fromParameters(parameters, AdminAuditList.DEFINITION);
    Page<AdminAuditLog> auditLogs = AdminListPaging.fetchWithPageCorrection(query,
      condition -> adminAuditService.search(AdminAuditList.searchOf(condition),
        AdminAuditList.sortOf(condition), condition.pageIndex()));
    model.addAttribute("auditLogs", auditLogs);
    model.addAttribute("rows", auditLogs.getContent().stream()
      .map(auditLog -> AdminAuditList.toRow(auditLog, adminDateFormatter)).toList());
    model.addAttribute("definition", AdminAuditList.DEFINITION);
    model.addAttribute("query", query);
    // 페이저 링크가 필터·정렬을 유지하도록 (page 는 페이저가 붙임)
    model.addAttribute("pagerBaseUrl", AdminAuditList.LIST_PATH + query.toQueryString(query.sort(), 1));
    model.addAttribute("csvExport",
      AdminCsvExporter.linkOf(AdminAuditList.LIST_PATH, query, auditLogs.getTotalElements()));
    return "admin/audit";
  }

  /// 관리자 기록 CSV: 목록과 같은 조건 > 상한 이내면 파일, 넘으면 같은 조건 목록으로 돌아가 안내 (내보낸 관리자·건수 기록)
  @GetMapping(AdminAuditList.LIST_PATH + AdminCsvExporter.EXPORT_PATH_SUFFIX)
  public ResponseEntity<byte[]> exportCsv(
    @RequestParam Map<String, String> parameters, Principal principal,
    HttpServletRequest request, HttpServletResponse response
  ) {
    AdminListQuery query = AdminListQuery.fromParameters(parameters, AdminAuditList.DEFINITION);
    ExportRows<AdminAuditLog> export = ExportRows.fromPage(adminAuditService.searchFirstRows(
      AdminAuditList.searchOf(query), AdminAuditList.sortOf(query), AdminCsvExporter.MAX_ROWS));
    if (export.isOverLimit()) {
      log.info("[admin csv] rejected audit : total={} over limit", export.totalCount());
      return AdminCsvExporter.redirectOverLimit(AdminAuditList.LIST_PATH, query, export.totalCount(), request, response);
    }
    log.info("[admin csv] exported audit : rows={}, admin={}", export.rows().size(),
      principal == null ? null : principal.getName());
    return AdminCsvExporter.toAttachment(CSV_FILE_PREFIX, LocalDate.now(),
      AdminAuditList.csvColumns(adminDateFormatter), export.rows());
  }
}
