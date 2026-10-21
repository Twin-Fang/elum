package com.chuseok22.elumserver.admin.application.list;

import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.list.AdminCsvExporter.CsvColumn;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Column;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Filter;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Option;
import com.chuseok22.elumserver.feedback.application.service.FeedbackAdminSearch;
import com.chuseok22.elumserver.feedback.core.FeedbackStatus;
import com.chuseok22.elumserver.feedback.infrastructure.entity.Feedback;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.List;
import org.springframework.data.domain.Sort;

/**
 * 의견 목록 선언: 열, 필터 5개(처리 상태, OS, 앱 버전, 보낸 기간), 정렬 허용 열, 조건 > 검색 조건·Sort·CSV 변환
 * 정렬은 isSortable 열만 허용되고 그 밖은 기본 정렬(최신순)로 돌아감
 */
public final class AdminFeedbackList {

  /// 필터 키: 처리 상태
  public static final String FILTER_STATUS = "status";
  /// 필터 키: OS (앱이 보내는 "ios 17.5" / "android 14" 의 앞부분)
  public static final String FILTER_OS = "os";
  /// 필터 키: 앱 버전 앞부분 ("1.0" 이면 1.0.x 전부)
  public static final String FILTER_APP_VERSION = "appVersion";
  /// 필터 키: 보낸 기간 (yyyy-MM-dd, 비우면 제한 없음)
  public static final String FILTER_FROM = "from";
  public static final String FILTER_TO = "to";
  /// OS 필터 값: 앱의 Platform.operatingSystem 값과 같음
  public static final String OS_IOS = "ios";
  public static final String OS_ANDROID = "android";
  /// 정렬 키 (열 키와 같음)
  public static final String SORT_CREATED_AT = "createdAt";
  public static final String SORT_STATUS = "status";
  public static final String SORT_STATUS_CHANGED_AT = "statusChangedAt";

  public static final String COLUMN_MEMBER = "member";
  public static final String COLUMN_MESSAGE = "message";
  public static final String COLUMN_APP_LOG = "appLog";
  public static final String COLUMN_ACTIONS = "actions";

  public static final AdminListDefinition DEFINITION = new AdminListDefinition(
    List.of(
      new Column(SORT_CREATED_AT, "보낸 때", true),
      new Column(COLUMN_MEMBER, "회원", false),
      new Column(COLUMN_MESSAGE, "의견", false),
      new Column(COLUMN_APP_LOG, "상태 기록", false),
      new Column(SORT_STATUS, "처리 상태", true),
      new Column(SORT_STATUS_CHANGED_AT, "처리 변경", true),
      new Column(COLUMN_ACTIONS, "", false)),
    List.of("message", "memberId"),
    List.of(
      new Filter(FILTER_STATUS, "처리 상태", Arrays.stream(FeedbackStatus.values())
        .map(status -> new Option(status.name(), status.getLabel())).toList()),
      new Filter(FILTER_OS, "OS", List.of(new Option(OS_IOS, "iOS"), new Option(OS_ANDROID, "Android"))),
      Filter.text(FILTER_APP_VERSION, "앱 버전"),
      Filter.date(FILTER_FROM, "보낸 날 시작"),
      Filter.date(FILTER_TO, "보낸 날 끝")),
    SORT_CREATED_AT + AdminListDefinition.SORT_DELIMITER + AdminListDefinition.SORT_DESCENDING);

  private AdminFeedbackList() {
  }

  /// 조건 > 정렬: 정렬 열 키 > 엔티티 속성, 동률은 id 로 고정해 페이지가 겹치지 않게 한다
  public static Sort sortOf(AdminListQuery query) {
    Sort.Direction direction = query.isAscending() ? Sort.Direction.ASC : Sort.Direction.DESC;
    Sort.Order mainOrder = switch (query.sortKey()) {
      case SORT_STATUS -> new Sort.Order(direction, "status");
      // 한 번도 안 바꾼(null) 의견은 방향과 상관없이 뒤로
      case SORT_STATUS_CHANGED_AT -> new Sort.Order(direction, "statusChangedAt").with(Sort.NullHandling.NULLS_LAST);
      default -> new Sort.Order(direction, "createdAt");
    };
    return Sort.by(mainOrder, new Sort.Order(Sort.Direction.ASC, "id"));
  }

  /// 필터 값 > 상태 (필터 없음/허용 밖은 null: 정의로 이미 보정된 값만 들어옴)
  public static FeedbackStatus statusFilterOf(AdminListQuery query) {
    return FeedbackStatus.fromName(query.filters().get(FILTER_STATUS)).orElse(null);
  }

  /// 조건 > 의견 검색 조건 (기간 끝은 끝 날 다음 날 0시, 앱 버전·OS 는 앞부분 일치)
  public static FeedbackAdminSearch searchOf(AdminListQuery query) {
    LocalDate from = AdminDateParameter.parseOrNull(query.filters().get(FILTER_FROM));
    LocalDate to = AdminDateParameter.parseOrNull(query.filters().get(FILTER_TO));
    return new FeedbackAdminSearch(
      query.likePattern(),
      statusFilterOf(query),
      from == null ? null : from.atStartOfDay(),
      to == null ? null : to.plusDays(1).atStartOfDay(),
      AdminListQuery.toPrefixLikePattern(query.filters().get(FILTER_APP_VERSION)),
      AdminListQuery.toPrefixLikePattern(query.filters().get(FILTER_OS)));
  }

  /**
   * CSV 열 10개: 보낸 때, 회원 ID, 처리 상태, 앱 버전, OS, 의견, 상태 기록 유무, 기록 속 오류 건수, 처리 변경 시각·변경자
   * 앱 상태 기록 원문은 넣지 않음 (길고 기기 정보가 섞임, 필요하면 상세에서 봄)
   */
  public static List<CsvColumn<Feedback>> csvColumns(AdminDateFormatter dateFormatter) {
    return List.of(
      new CsvColumn<>("보낸 때", feedback -> AdminCsvExporter.dateTimeCell(feedback.getCreatedAt(), dateFormatter)),
      new CsvColumn<>("회원 ID", Feedback::getMemberId),
      new CsvColumn<>("처리 상태", feedback -> feedback.getStatus().getLabel()),
      new CsvColumn<>("앱 버전", Feedback::getAppVersion),
      new CsvColumn<>("OS", Feedback::getOs),
      new CsvColumn<>("의견", Feedback::getMessage),
      new CsvColumn<>("상태 기록", feedback -> feedback.hasAppLog() ? "있음" : "없음"),
      new CsvColumn<>("기록 속 오류 건수", feedback -> String.valueOf(feedback.appLogErrorCount())),
      new CsvColumn<>("처리 변경 시각",
        feedback -> AdminCsvExporter.dateTimeCell(feedback.getStatusChangedAt(), dateFormatter)),
      new CsvColumn<>("처리 변경자", Feedback::getStatusChangedBy));
  }
}
