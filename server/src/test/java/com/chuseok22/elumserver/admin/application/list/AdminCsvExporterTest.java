package com.chuseok22.elumserver.admin.application.list;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.list.AdminCsvExporter.CsvColumn;
import com.chuseok22.elumserver.admin.application.list.AdminCsvExporter.ExportRows;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;

/** CSV 내보내기 공통: 엑셀에서 수식이 실행되거나 열이 밀리거나 한글이 깨지지 않게, 상한을 넘기면 파일을 만들지 않게 */
class AdminCsvExporterTest {

  private static final List<CsvColumn<String[]>> TWO_COLUMNS = List.of(
    new CsvColumn<>("이름", row -> row[0]), new CsvColumn<>("메모", row -> row[1]));

  @Test
  @DisplayName("= + - @ 탭 CR 로 시작하는 셀은 ' 를 붙여 엑셀이 수식으로 실행하지 않는다")
  void formulaLeadingCell_isGuarded() {
    assertThat(AdminCsvExporter.escapeCell("=HYPERLINK(\"http://x\")")).isEqualTo("\"'=HYPERLINK(\"\"http://x\"\")\"");
    assertThat(AdminCsvExporter.escapeCell("+1")).isEqualTo("'+1");
    assertThat(AdminCsvExporter.escapeCell("-2")).isEqualTo("'-2");
    assertThat(AdminCsvExporter.escapeCell("@SUM(A1)")).isEqualTo("'@SUM(A1)");
    assertThat(AdminCsvExporter.escapeCell("\tcmd")).isEqualTo("'\tcmd");
    assertThat(AdminCsvExporter.escapeCell("\rcmd")).isEqualTo("\"'\rcmd\"");
    assertThat(AdminCsvExporter.escapeCell("일반 글")).isEqualTo("일반 글");
  }

  @Test
  @DisplayName("쉼표·따옴표·줄바꿈이 든 셀은 따옴표로 감싸 열이 밀리지 않고, null 은 빈 칸이다")
  void delimiterCell_isQuoted() {
    String csv = AdminCsvExporter.toCsv(TWO_COLUMNS, List.<String[]>of(
      new String[] {"하늘, 바다", "그가 \"안녕\"\n했어요"}, new String[] {null, ""}));

    assertThat(csv).isEqualTo("이름,메모\r\n\"하늘, 바다\",\"그가 \"\"안녕\"\"\n했어요\"\r\n,\r\n");
  }

  @Test
  @DisplayName("첨부 응답은 UTF-8 BOM 으로 시작하고 파일명에 날짜가 붙고 캐시를 막는다")
  void attachment_hasBomDatedFileNameAndNoStore() {
    ResponseEntity<byte[]> response = AdminCsvExporter.toAttachment("members", LocalDate.of(2026, 10, 21),
      TWO_COLUMNS, List.<String[]>of(new String[] {"하늘", "메모"}));

    byte[] body = response.getBody();
    assertThat(Arrays.copyOfRange(body, 0, 3)).containsExactly(0xEF, 0xBB, 0xBF);
    assertThat(new String(body, 3, body.length - 3, StandardCharsets.UTF_8)).startsWith("이름,메모\r\n하늘,메모");
    assertThat(response.getHeaders().getFirst(HttpHeaders.CONTENT_DISPOSITION))
      .startsWith("attachment").contains("members_20261021.csv");
    assertThat(response.getHeaders().getFirst(HttpHeaders.CACHE_CONTROL)).isEqualTo("no-store");
    assertThat(response.getHeaders().getContentType().toString()).isEqualTo("text/csv;charset=UTF-8");
  }

  @Test
  @DisplayName("전체가 상한 이하면 행을 담고, 상한을 넘으면 행을 버리고 건수만 남긴다")
  void exportRows_overLimitDropsRows() {
    ExportRows<String> withinLimit = ExportRows.fromPage(
      new PageImpl<>(List.of("a"), PageRequest.of(0, AdminCsvExporter.MAX_ROWS), AdminCsvExporter.MAX_ROWS));
    ExportRows<String> overLimit = ExportRows.fromPage(
      new PageImpl<>(List.of("a"), PageRequest.of(0, AdminCsvExporter.MAX_ROWS), AdminCsvExporter.MAX_ROWS + 1L));

    assertThat(withinLimit.isOverLimit()).isFalse();
    assertThat(withinLimit.rows()).containsExactly("a");
    assertThat(overLimit.isOverLimit()).isTrue();
    assertThat(overLimit.rows()).isEmpty();
    assertThat(AdminCsvExporter.overLimitMessage(overLimit.totalCount())).contains("10,001건").contains("10,000건");
  }

  @Test
  @DisplayName("내보내기 주소는 목록의 검색·필터·정렬을 그대로 싣고 페이지는 뺀다")
  void exportLink_keepsConditionsWithoutPage() {
    AdminListQuery query = AdminListQuery.of("하늘", java.util.Map.of("status", "NEW"), null, "3",
      AdminFeedbackList.DEFINITION);

    assertThat(AdminCsvExporter.linkOf("/admin/feedback", query, 5).url())
      .isEqualTo("/admin/feedback/export.csv?q=%ED%95%98%EB%8A%98&status=NEW&sort=createdAt,desc");
  }
}
