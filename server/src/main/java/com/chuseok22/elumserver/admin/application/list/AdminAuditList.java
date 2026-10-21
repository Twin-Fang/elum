package com.chuseok22.elumserver.admin.application.list;

import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.list.AdminCsvExporter.CsvColumn;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Column;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Filter;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Option;
import com.chuseok22.elumserver.admin.application.service.AdminAuditSearch;
import com.chuseok22.elumserver.admin.core.AdminAuditAction;
import com.chuseok22.elumserver.admin.core.AdminAuditTargetType;
import com.chuseok22.elumserver.admin.infrastructure.entity.AdminAuditLog;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.springframework.data.domain.Sort;
import org.springframework.web.util.UriUtils;

/**
 * 관리자 기록 목록 선언: 열 6개, 필터 6개(관리자, 동작, 대상 종류, 대상 id, 기간 시작·끝), 최신순 > 검색 조건·Sort·행·CSV 변환
 * 대상 링크: 회원 > 회원 상세, 프롬프트 > 프롬프트 이력, 의견 > 의견 상세 (삭제류 동작은 링크 없음)
 */
public final class AdminAuditList {

  public static final String LIST_PATH = "/admin/audit";

  /// 필터 키: 관리자 아이디·대상 id 는 완전 일치
  public static final String FILTER_ADMIN = "admin";
  public static final String FILTER_ACTION = "action";
  public static final String FILTER_TARGET_TYPE = "targetType";
  public static final String FILTER_TARGET_ID = "targetId";
  /// 필터 키: 기록 기간 (yyyy-MM-dd, 비우면 제한 없음)
  public static final String FILTER_FROM = "from";
  public static final String FILTER_TO = "to";

  /// 정렬 키 (열 키와 같음): 기록 시각만 정렬 허용
  public static final String SORT_CREATED_AT = "createdAt";

  public static final String COLUMN_ADMIN = "admin";
  public static final String COLUMN_ACTION = "action";
  public static final String COLUMN_TARGET = "target";
  public static final String COLUMN_DETAIL = "detail";
  public static final String COLUMN_REQUEST_ID = "requestId";

  /// 빈 칸 표시
  private static final String EMPTY_CELL = "-";

  public static final AdminListDefinition DEFINITION = new AdminListDefinition(
    List.of(
      new Column(SORT_CREATED_AT, "때", true),
      new Column(COLUMN_ADMIN, "관리자", false),
      new Column(COLUMN_ACTION, "동작", false),
      new Column(COLUMN_TARGET, "대상", false),
      new Column(COLUMN_DETAIL, "내용", false),
      new Column(COLUMN_REQUEST_ID, "요청 id", false)),
    List.of(),
    List.of(
      Filter.text(FILTER_ADMIN, "관리자"),
      new Filter(FILTER_ACTION, "동작", Arrays.stream(AdminAuditAction.values())
        .map(action -> new Option(action.name(), action.getLabel())).toList()),
      new Filter(FILTER_TARGET_TYPE, "대상 종류", Arrays.stream(AdminAuditTargetType.values())
        .map(targetType -> new Option(targetType.name(), targetType.getLabel())).toList()),
      Filter.text(FILTER_TARGET_ID, "대상 id"),
      Filter.date(FILTER_FROM, "기록 시작일"),
      Filter.date(FILTER_TO, "기록 종료일")),
    SORT_CREATED_AT + AdminListDefinition.SORT_DELIMITER + AdminListDefinition.SORT_DESCENDING);

  private AdminAuditList() {
  }

  /// 조건 > 정렬: 기록 시각, 동률은 id 로 고정해 페이지가 겹치지 않게 한다
  public static Sort sortOf(AdminListQuery query) {
    Sort.Direction direction = query.isAscending() ? Sort.Direction.ASC : Sort.Direction.DESC;
    return Sort.by(new Sort.Order(direction, "createdAt"), new Sort.Order(Sort.Direction.ASC, "id"));
  }

  /// 조건 > 검색 조건 (정의로 보정된 값만 들어옴, 기간 끝은 끝 날 다음 날 0시)
  public static AdminAuditSearch searchOf(AdminListQuery query) {
    String action = query.filters().get(FILTER_ACTION);
    String targetType = query.filters().get(FILTER_TARGET_TYPE);
    LocalDate from = AdminDateParameter.parseOrNull(query.filters().get(FILTER_FROM));
    LocalDate to = AdminDateParameter.parseOrNull(query.filters().get(FILTER_TO));
    return new AdminAuditSearch(
      query.filters().get(FILTER_ADMIN),
      action == null ? null : AdminAuditAction.valueOf(action),
      targetType == null ? null : AdminAuditTargetType.valueOf(targetType),
      query.filters().get(FILTER_TARGET_ID),
      from == null ? null : from.atStartOfDay(),
      to == null ? null : to.plusDays(1).atStartOfDay());
  }

  /// 기록 1줄 > 표 행 (대상 칸은 대상 화면 링크, 없으면 글만)
  public static AdminListRow toRow(AdminAuditLog auditLog, AdminDateFormatter dateFormatter) {
    Map<String, String> cells = new HashMap<>();
    cells.put(SORT_CREATED_AT, dateFormatter.format(auditLog.getCreatedAt()));
    cells.put(COLUMN_ADMIN, auditLog.getAdminUsername());
    cells.put(COLUMN_ACTION, auditLog.getAction().getLabel());
    cells.put(COLUMN_TARGET, targetLabelOf(auditLog));
    cells.put(COLUMN_DETAIL, valueOrEmptyCell(auditLog.getDetail()));
    cells.put(COLUMN_REQUEST_ID, valueOrEmptyCell(auditLog.getRequestId()));
    String targetLink = targetLinkOf(auditLog);
    return new AdminListRow(null, cells, targetLink == null ? Map.of() : Map.of(COLUMN_TARGET, targetLink));
  }

  /// CSV 열 7개: 때, 관리자, 동작, 대상 종류, 대상 id, 내용, 요청 id
  public static List<CsvColumn<AdminAuditLog>> csvColumns(AdminDateFormatter dateFormatter) {
    return List.of(
      new CsvColumn<>("때", auditLog -> AdminCsvExporter.dateTimeCell(auditLog.getCreatedAt(), dateFormatter)),
      new CsvColumn<>("관리자", AdminAuditLog::getAdminUsername),
      new CsvColumn<>("동작", auditLog -> auditLog.getAction().getLabel()),
      new CsvColumn<>("대상 종류", auditLog -> auditLog.getTargetType().getLabel()),
      new CsvColumn<>("대상 id", AdminAuditLog::getTargetId),
      new CsvColumn<>("내용", AdminAuditLog::getDetail),
      new CsvColumn<>("요청 id", AdminAuditLog::getRequestId));
  }

  /// 대상 종류 + id (id 가 없으면 종류만)
  private static String targetLabelOf(AdminAuditLog auditLog) {
    String label = auditLog.getTargetType().getLabel();
    return auditLog.getTargetId() == null ? label : label + " " + auditLog.getTargetId();
  }

  /// 대상 화면 주소: 삭제류·id 없음·로그 파일은 null
  static String targetLinkOf(AdminAuditLog auditLog) {
    String targetId = auditLog.getTargetId();
    if (targetId == null || auditLog.getAction().isTargetRemoved()) {
      return null;
    }
    return switch (auditLog.getTargetType()) {
      case MEMBER -> "/admin/members/" + encodePathSegment(targetId);
      case FEEDBACK -> "/admin/feedback/" + encodePathSegment(targetId);
      case PROMPT -> promptHistoryLinkOf(targetId);
      case LOG_FILE -> null;
    };
  }

  /// "{PromptKey}:{언어}" > 프롬프트 이력 주소 (형식이 다르면 null)
  private static String promptHistoryLinkOf(String targetId) {
    String[] parts = targetId.split(AdminAuditTargetType.PROMPT_TARGET_ID_DELIMITER, -1);
    if (parts.length != 2 || parts[0].isBlank() || parts[1].isBlank()) {
      return null;
    }
    return "/admin/prompts/" + encodePathSegment(parts[0]) + "/history?locale="
      + UriUtils.encodeQueryParam(parts[1], StandardCharsets.UTF_8);
  }

  private static String encodePathSegment(String value) {
    return UriUtils.encodePathSegment(value, StandardCharsets.UTF_8);
  }

  private static String valueOrEmptyCell(String value) {
    return value == null || value.isBlank() ? EMPTY_CELL : value;
  }
}
