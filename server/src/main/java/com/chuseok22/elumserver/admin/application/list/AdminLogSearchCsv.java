package com.chuseok22.elumserver.admin.application.list;

import com.chuseok22.elumserver.admin.application.dto.response.LogSearchResponse.Entry;
import com.chuseok22.elumserver.admin.application.list.AdminCsvExporter.CsvColumn;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 서버 로그 검색 결과 CSV: 열 6개(시각, 레벨, 요청 id, 회원 id, 내용, 잘림) (#656)
 * 요청 id·회원 id 는 항목 첫 줄의 [인스턴스] [요청 id] [회원 id] 묶음에서 꺼냄 (옛 형식 줄은 빈 칸)
 */
public final class AdminLogSearchCsv {

  /// CSV 파일명 접두어: server_logs_{yyyyMMdd}.csv
  public static final String CSV_FILE_PREFIX = "server_logs";

  /// 로그 줄 묶음: "--- [blue] [요청 id] [회원 id] [스레드]" (logback-spring.xml 패턴과 같은 순서)
  static final Pattern REQUEST_CONTEXT = Pattern.compile(
    " --- \\[[^\\]]*\\] \\[([A-Za-z0-9-]*)\\] \\[([^\\]\\s]*)\\] \\[");
  private static final int REQUEST_ID_GROUP = 1;
  private static final int MEMBER_ID_GROUP = 2;
  /// 잘림 열 값
  private static final String TRUNCATED_TEXT = "잘림";

  private AdminLogSearchCsv() {
  }

  /// 검색 항목 > CSV 열
  public static List<CsvColumn<Entry>> csvColumns() {
    return List.of(
      new CsvColumn<>("시각", Entry::timestamp),
      new CsvColumn<>("레벨", Entry::level),
      new CsvColumn<>("요청 id", entry -> requestContextValueOf(entry, REQUEST_ID_GROUP)),
      new CsvColumn<>("회원 id", entry -> requestContextValueOf(entry, MEMBER_ID_GROUP)),
      new CsvColumn<>("내용", Entry::text),
      new CsvColumn<>("잘림", entry -> entry.truncated() ? TRUNCATED_TEXT : ""));
  }

  /// 항목 첫 줄 > 요청 id 또는 회원 id (없거나 옛 형식이면 빈 칸)
  static String requestContextValueOf(Entry entry, int group) {
    String text = entry.text();
    if (text == null) {
      return "";
    }
    int lineEnd = text.indexOf('\n');
    String firstLine = lineEnd < 0 ? text : text.substring(0, lineEnd);
    Matcher matcher = REQUEST_CONTEXT.matcher(firstLine);
    return matcher.find() ? matcher.group(group) : "";
  }
}
