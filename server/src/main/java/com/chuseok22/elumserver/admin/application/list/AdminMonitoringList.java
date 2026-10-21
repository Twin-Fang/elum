package com.chuseok22.elumserver.admin.application.list;

import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.list.AdminCsvExporter.CsvColumn;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Column;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Filter;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Option;
import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.infrastructure.entity.AiCallLog;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

/**
 * AI 모니터링 목록 선언: 필터 8개(호출 유형, 결과, 회원 ID, 회원 검색, 모델명, 오류 메시지, 시작일, 종료일), 정렬 허용 열 2개(시각, 추정 비용), 기간 보정, CSV 열
 * 기간은 기본 최근 N일(AdminListDefaults.DEFAULT_PERIOD_DAYS, 오늘 포함), 범위 밖·역전 날짜는 보정
 */
public final class AdminMonitoringList {

  /// 필터 키
  public static final String FILTER_CALL_TYPE = "callType";
  public static final String FILTER_SUCCESS = "success";
  public static final String FILTER_MEMBER_ID = "memberId";
  /// 회원 검색: 회원 ID 그대로, 아이디·닉네임·로그인 이메일 일부 (원시 ID 를 몰라도 찾게)
  public static final String FILTER_MEMBER = "member";
  /// 모델명·오류 메시지 일부 (대소문자 무시)
  public static final String FILTER_MODEL = "model";
  public static final String FILTER_ERROR_MESSAGE = "error";
  public static final String FILTER_FROM = AdminListPeriod.FILTER_FROM;
  public static final String FILTER_TO = AdminListPeriod.FILTER_TO;

  /// 정렬 키 (열 키 = 엔티티 필드 이름): 시각, 추정 비용
  public static final String SORT_CREATED_AT = "createdAt";
  public static final String SORT_ESTIMATED_COST = "estimatedCostUsd";

  public static final String SUCCESS_TRUE = "true";
  public static final String SUCCESS_FALSE = "false";

  public static final AdminListDefinition DEFINITION = new AdminListDefinition(
    List.of(new Column(SORT_CREATED_AT, "시각", true), Column.numeric(SORT_ESTIMATED_COST, "추정 비용", true)),
    List.of(),
    List.of(
      new Filter(FILTER_CALL_TYPE, "호출 유형", Arrays.stream(AiCallType.values())
        .map(type -> new Option(type.name(), type.getLabel())).toList()),
      new Filter(FILTER_SUCCESS, "결과", List.of(
        new Option(SUCCESS_TRUE, "성공"), new Option(SUCCESS_FALSE, "실패"))),
      new Filter(FILTER_MEMBER_ID, "회원 ID", List.of()),
      Filter.text(FILTER_MEMBER, "회원"),
      Filter.text(FILTER_MODEL, "모델"),
      Filter.text(FILTER_ERROR_MESSAGE, "오류 메시지"),
      new Filter(FILTER_FROM, "시작일", List.of()),
      new Filter(FILTER_TO, "종료일", List.of())),
    SORT_CREATED_AT + AdminListDefinition.SORT_DELIMITER + AdminListDefinition.SORT_DESCENDING);

  private AdminMonitoringList() {
  }

  /// 기간 보정 (규칙은 AdminListPeriod 공통)
  public static AdminListQuery withCorrectedPeriod(AdminListQuery query, LocalDate today) {
    return AdminListPeriod.withCorrectedPeriod(query, today);
  }

  public static LocalDateTime periodStart(AdminListQuery query) {
    return AdminListPeriod.periodStart(query);
  }

  public static LocalDateTime periodEndExclusive(AdminListQuery query) {
    return AdminListPeriod.periodEndExclusive(query);
  }

  public static AiCallType callTypeOf(AdminListQuery query) {
    String value = query.filters().get(FILTER_CALL_TYPE);
    return value == null ? null : AiCallType.valueOf(value);
  }

  /// 결과 필터: 성공 true, 실패 false, 전체 null
  public static Boolean successOf(AdminListQuery query) {
    String value = query.filters().get(FILTER_SUCCESS);
    return value == null ? null : Boolean.valueOf(value);
  }

  public static String memberIdOf(AdminListQuery query) {
    return query.filters().get(FILTER_MEMBER_ID);
  }

  /// 회원 검색어 원문 (회원 ID 정확히 일치 비교용, 없으면 null)
  public static String memberKeywordOf(AdminListQuery query) {
    return query.filters().get(FILTER_MEMBER);
  }

  /// 소문자 포함 검색 패턴 (lower(열) 과 비교, 없으면 null): 회원·모델명·오류 메시지
  public static String lowerLikePatternOf(AdminListQuery query, String filterKey) {
    String pattern = AdminListQuery.toLikePattern(query.filters().get(filterKey));
    return pattern == null ? null : pattern.toLowerCase(Locale.ROOT);
  }

  /// 정렬 > 페이지 요청 (한 쪽 LOG_PAGE_SIZE)
  public static Pageable pageableOf(AdminListQuery query) {
    return PageRequest.of(query.pageIndex(), AdminListDefaults.LOG_PAGE_SIZE, sortOf(query));
  }

  /// 정렬 (목록·CSV 공통): 비용 없는 호출(실패 등)은 방향과 무관하게 뒤로, 동률은 시각 최신 > id 로 고정해 페이지가 겹치지 않게
  public static Sort sortOf(AdminListQuery query) {
    Sort.Direction direction = query.isAscending() ? Sort.Direction.ASC : Sort.Direction.DESC;
    if (SORT_ESTIMATED_COST.equals(query.sortKey())) {
      return Sort.by(new Sort.Order(direction, SORT_ESTIMATED_COST).nullsLast(),
        new Sort.Order(Sort.Direction.DESC, SORT_CREATED_AT), new Sort.Order(Sort.Direction.ASC, "id"));
    }
    return Sort.by(new Sort.Order(direction, SORT_CREATED_AT), new Sort.Order(Sort.Direction.ASC, "id"));
  }

  /**
   * CSV 열 10개: 시각, 호출 유형, 모델, 회원 ID, 결과, 오류 메시지, 지연, 입력·출력 토큰, 추정 비용
   * 지시문·응답 원문은 넣지 않음 (서비스 원칙 5번, 호출 기록에도 없음)
   */
  public static List<CsvColumn<AiCallLog>> csvColumns(AdminDateFormatter dateFormatter) {
    return List.of(
      new CsvColumn<>("시각", call -> AdminCsvExporter.dateTimeCell(call.getCreatedAt(), dateFormatter)),
      new CsvColumn<>("호출 유형", call -> call.getCallType().getLabel()),
      new CsvColumn<>("모델", AiCallLog::getModel),
      new CsvColumn<>("회원 ID", AiCallLog::getMemberId),
      new CsvColumn<>("결과", call -> call.isSuccess() ? "성공" : "실패"),
      new CsvColumn<>("오류 메시지", AiCallLog::getErrorMessage),
      new CsvColumn<>("지연(ms)", call -> textOrBlank(call.getLatencyMs())),
      new CsvColumn<>("입력 토큰", call -> textOrBlank(call.getPromptTokens())),
      new CsvColumn<>("출력 토큰", call -> textOrBlank(call.getOutputTokens())),
      new CsvColumn<>("추정 비용(USD)", call -> call.getEstimatedCostUsd() == null
        ? "" : String.format("%.6f", call.getEstimatedCostUsd())));
  }

  private static String textOrBlank(Number value) {
    return value == null ? "" : String.valueOf(value);
  }
}
