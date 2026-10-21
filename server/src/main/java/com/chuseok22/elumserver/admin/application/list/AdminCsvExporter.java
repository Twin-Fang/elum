package com.chuseok22.elumserver.admin.application.list;

import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.function.Function;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.CacheControl;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.servlet.FlashMap;
import org.springframework.web.servlet.support.RequestContextUtils;

/**
 * 관리자 목록 CSV 내보내기 공통: 열 선언 > 셀 정리(수식 주입 방지·따옴표) > UTF-8 BOM 첨부 응답
 * 건수 상한 MAX_ROWS 초과면 파일 대신 목록으로 돌려보내 안내 (화면 필터 조건 그대로 유지)
 */
public final class AdminCsvExporter {

  /// 한 번에 내보내는 최대 건수 (메모리에 모아 한 번에 쓰므로 상한을 둠)
  public static final int MAX_ROWS = 10_000;
  /// 목록 주소 뒤에 붙는 내보내기 경로: /admin/members > /admin/members/export.csv
  public static final String EXPORT_PATH_SUFFIX = "/export.csv";

  /// 엑셀이 UTF-8 로 읽도록 맨 앞에 두는 표지 (없으면 한글이 깨짐)
  private static final byte[] UTF8_BOM = {(byte) 0xEF, (byte) 0xBB, (byte) 0xBF};
  private static final MediaType TEXT_CSV_UTF8 = new MediaType("text", "csv", StandardCharsets.UTF_8);
  /// 파일명: {접두어}_{yyyyMMdd}.csv
  private static final DateTimeFormatter FILE_DATE = DateTimeFormatter.BASIC_ISO_DATE;
  private static final String FILE_EXTENSION = ".csv";
  private static final String CELL_DELIMITER = ",";
  private static final String LINE_BREAK = "\r\n";
  /// 엑셀이 수식으로 읽는 첫 글자 6개: = + - @ 탭 CR (OWASP CSV Injection)
  private static final String FORMULA_LEADING_CHARACTERS = "=+-@\t\r";
  private static final String FORMULA_GUARD = "'";
  private static final String QUOTE = "\"";
  /// 상한 초과 안내를 실어 보낼 플래시 키 (목록 화면의 오류 알림)
  private static final String FLASH_ERROR_MESSAGE = "errorMessage";

  private AdminCsvExporter() {
  }

  /// CSV 한 열: 머리글 + 행 > 셀 값 (null 은 빈 칸)
  public record CsvColumn<T>(String header, Function<T, String> valueOf) {
  }

  /// 내보낼 행 + 조건에 맞는 전체 건수 (전체가 상한을 넘으면 rows 는 비워 둠)
  public record ExportRows<T>(List<T> rows, long totalCount) {

    public ExportRows {
      rows = rows == null ? List.of() : List.copyOf(rows);
    }

    public static <T> ExportRows<T> overLimit(long totalCount) {
      return new ExportRows<>(List.of(), totalCount);
    }

    /// 첫 쪽(크기 MAX_ROWS) 조회 결과 > 내보낼 행 (전체가 상한을 넘으면 행을 버림)
    public static <T> ExportRows<T> fromPage(Page<T> page) {
      return AdminCsvExporter.isOverLimit(page.getTotalElements())
        ? overLimit(page.getTotalElements())
        : new ExportRows<>(page.getContent(), page.getTotalElements());
    }

    public boolean isOverLimit() {
      return AdminCsvExporter.isOverLimit(totalCount);
    }
  }

  /// 내보내기 조회용 페이지 요청: 첫 쪽, 크기 MAX_ROWS, 목록과 같은 정렬
  public static Pageable exportPageable(Sort sort) {
    return PageRequest.of(0, MAX_ROWS, sort);
  }

  /// 목록 화면의 내보내기 버튼: 주소 + 지금 조건의 전체 건수 (상한을 넘으면 버튼을 막음)
  public record ExportLink(String url, long totalCount) {

    public boolean isOverLimit() {
      return AdminCsvExporter.isOverLimit(totalCount);
    }

    public int maxRows() {
      return MAX_ROWS;
    }
  }

  /// 목록 주소 + 현재 검색·필터·정렬 + 전체 건수 > 내보내기 버튼 (페이지는 뺌)
  public static ExportLink linkOf(String listPath, AdminListQuery query, long totalCount) {
    return new ExportLink(listPath + EXPORT_PATH_SUFFIX + query.toQueryString(query.sort(), 1), totalCount);
  }

  public static boolean isOverLimit(long totalCount) {
    return totalCount > MAX_ROWS;
  }

  /// 행 > CSV 첨부 응답 (BOM + 머리글 + 행, 파일명에 오늘 날짜, 캐시 금지)
  public static <T> ResponseEntity<byte[]> toAttachment(
    String fileNamePrefix, LocalDate today, List<CsvColumn<T>> columns, List<T> rows
  ) {
    byte[] body = toCsv(columns, rows).getBytes(StandardCharsets.UTF_8);
    byte[] withBom = new byte[UTF8_BOM.length + body.length];
    System.arraycopy(UTF8_BOM, 0, withBom, 0, UTF8_BOM.length);
    System.arraycopy(body, 0, withBom, UTF8_BOM.length, body.length);
    String fileName = fileNamePrefix + "_" + today.format(FILE_DATE) + FILE_EXTENSION;
    return ResponseEntity.ok()
      .contentType(TEXT_CSV_UTF8)
      .header(HttpHeaders.CONTENT_DISPOSITION,
        // 파일명은 영문·숫자뿐이라 filename* 인코딩 없이 그대로 (오래된 브라우저 호환)
        ContentDisposition.attachment().filename(fileName).build().toString())
      // 개인정보가 담긴 파일이라 브라우저·프록시에 남기지 않음
      .cacheControl(CacheControl.noStore())
      .body(withBom);
  }

  /// 상한 초과 > 같은 조건의 목록으로 303 이동 + 오류 안내 (플래시라 새로 고치면 사라짐)
  public static ResponseEntity<byte[]> redirectOverLimit(
    String listPath, AdminListQuery query, long totalCount, HttpServletRequest request, HttpServletResponse response
  ) {
    String location = listPath + query.toQueryString(query.sort(), 1);
    FlashMap flashMap = RequestContextUtils.getOutputFlashMap(request);
    flashMap.put(FLASH_ERROR_MESSAGE, overLimitMessage(totalCount));
    RequestContextUtils.saveOutputFlashMap(location, request, response);
    return ResponseEntity.status(HttpStatus.SEE_OTHER).location(URI.create(location)).build();
  }

  /// 상한 초과 안내 문구
  public static String overLimitMessage(long totalCount) {
    return String.format("조건에 맞는 항목이 %,d건이라 CSV로 내보낼 수 없어요. 필터로 %,d건 이하로 좁혀 주세요.",
      totalCount, MAX_ROWS);
  }

  /// 시각 > CSV 칸 (관리자 공통 표기, 없으면 "-" 대신 빈 칸: 수식 방지 처리에 걸리지 않게)
  public static String dateTimeCell(LocalDateTime dateTime, AdminDateFormatter dateFormatter) {
    return dateTime == null ? "" : dateFormatter.format(dateTime);
  }

  /// 열·행 > CSV 글 (줄바꿈 CRLF)
  static <T> String toCsv(List<CsvColumn<T>> columns, List<T> rows) {
    StringBuilder builder = new StringBuilder();
    appendLine(builder, columns.stream().map(CsvColumn::header).toList());
    for (T row : rows) {
      appendLine(builder, columns.stream().map(column -> column.valueOf().apply(row)).toList());
    }
    return builder.toString();
  }

  /// 셀 정리: null > 빈 칸, 수식 첫 글자 > ' 붙임, 쉼표·따옴표·줄바꿈 > 따옴표로 감싸고 " 는 "" 로
  static String escapeCell(String raw) {
    if (raw == null || raw.isEmpty()) {
      return "";
    }
    String guarded = FORMULA_LEADING_CHARACTERS.indexOf(raw.charAt(0)) >= 0 ? FORMULA_GUARD + raw : raw;
    boolean isQuoteNeeded = guarded.contains(CELL_DELIMITER) || guarded.contains(QUOTE)
      || guarded.contains("\n") || guarded.contains("\r");
    return isQuoteNeeded ? QUOTE + guarded.replace(QUOTE, QUOTE + QUOTE) + QUOTE : guarded;
  }

  private static void appendLine(StringBuilder builder, List<String> cells) {
    builder.append(String.join(CELL_DELIMITER, cells.stream().map(AdminCsvExporter::escapeCell).toList()));
    builder.append(LINE_BREAK);
  }
}
