package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.list.AdminAuditList;
import com.chuseok22.elumserver.admin.application.list.AdminCsvExporter;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.core.AdminAuditAction;
import com.chuseok22.elumserver.admin.core.AdminAuditTargetType;
import com.chuseok22.elumserver.admin.infrastructure.entity.AdminAuditLog;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * 관리자 기록 화면 (#653): 행·대상 링크(회원 상세, 프롬프트 이력, 삭제류는 링크 없음)·필터가 실제로 그려지는지
 * 서버를 띄우지 않고 템플릿 엔진만으로 그린다
 */
class AdminAuditTemplateTest {

  private static final String MEMBER_ID = "3f1c2b9a-0000-4000-8000-000000000001";

  private final AdminTemplateRenderSupport renderer = new AdminTemplateRenderSupport();

  private static AdminAuditLog auditLog(AdminAuditAction action, String targetId, String detail) {
    AdminAuditLog auditLog = new AdminAuditLog();
    auditLog.setId(action.name());
    auditLog.setAdminUsername("<b>kimchi</b>");
    auditLog.setAction(action);
    auditLog.setTargetType(action.getTargetType());
    auditLog.setTargetId(targetId);
    auditLog.setDetail(detail);
    auditLog.setRequestId("req-1234");
    // 감사 컬럼은 setter 가 없어 JPA 가 채운다. 화면 확인용으로 직접 넣는다.
    ReflectionTestUtils.setField(auditLog, "createdAt", LocalDateTime.of(2026, 10, 22, 9, 30));
    return auditLog;
  }

  @Test
  @DisplayName("기록 행이 그려지고, 회원은 상세·프롬프트는 이력으로 링크, 삭제된 대상은 링크 없음, 관리자 이름은 이스케이프")
  void rendersRowsWithTargetLinks() {
    List<AdminAuditLog> auditLogs = List.of(
      auditLog(AdminAuditAction.MEMBER_SUSPENDED, MEMBER_ID, null),
      auditLog(AdminAuditAction.PROMPT_UPDATED,
        AdminAuditTargetType.toPromptTargetId("ROUTINE_CREATE", "ko"), "언어 ko · 120자"),
      auditLog(AdminAuditAction.FEEDBACK_DELETED, "feedback-1", "보낸 회원 " + MEMBER_ID));
    AdminListQuery query = AdminListQuery.fromParameters(
      Map.of(AdminAuditList.FILTER_ACTION, AdminAuditAction.MEMBER_SUSPENDED.name()), AdminAuditList.DEFINITION);
    AdminDateFormatter dateFormatter = new AdminDateFormatter();

    Map<String, Object> variables = new HashMap<>();
    variables.put("auditLogs", new PageImpl<>(auditLogs, PageRequest.of(0, 20), auditLogs.size()));
    variables.put("rows", auditLogs.stream().map(auditLog -> AdminAuditList.toRow(auditLog, dateFormatter)).toList());
    variables.put("definition", AdminAuditList.DEFINITION);
    variables.put("query", query);
    variables.put("pagerBaseUrl", AdminAuditList.LIST_PATH + query.toQueryString(query.sort(), 1));
    variables.put("csvExport", AdminCsvExporter.linkOf(AdminAuditList.LIST_PATH, query, auditLogs.size()));
    String html = renderer.render("admin/audit", variables);

    assertThat(html)
      .contains("계정 정지", "프롬프트 저장", "의견 삭제", "2026-10-22 09:30", "req-1234")
      .contains("href=\"/admin/members/" + MEMBER_ID + "\"")
      .contains("href=\"/admin/prompts/ROUTINE_CREATE/history?locale=ko\"")
      .doesNotContain("href=\"/admin/feedback/feedback-1\"")
      .contains("&lt;b&gt;kimchi&lt;/b&gt;")
      .doesNotContain("<b>kimchi</b>");
    // 적용된 동작 필터가 선택 상자와 조건 칩에 보인다
    assertThat(html).containsPattern("value=\"MEMBER_SUSPENDED\"\\s+selected").contains("data-admin-active-filter");
  }
}
