package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.chuseok22.elumserver.admin.application.dto.response.LogSearchResponse;
import com.chuseok22.elumserver.admin.application.dto.response.LogSearchResponse.Entry;
import com.chuseok22.elumserver.admin.application.list.AdminCsvExporter.CsvColumn;
import com.chuseok22.elumserver.admin.application.list.AdminLogSearchCsv;
import java.util.List;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.zip.GZIPOutputStream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class AdminLogSearchServiceTest {

  private static final String LOG = """
    2026-10-08T09:00:00.000+09:00  INFO 1 --- [green] [main] c.c.e.Boot : 서버 시작
    2026-10-08T09:01:00.000+09:00 DEBUG 1 --- [green] [exec-1] o.s.w.DispatcherServlet : GET "/api/routines"
    2026-10-08T09:02:00.000+09:00 ERROR 1 --- [green] [exec-2] c.c.e.RoutineService : 일과 생성 실패
    java.lang.IllegalStateException: boom
    \tat com.chuseok22.Foo.bar(Foo.java:10)
    2026-10-08T09:03:00.000+09:00  WARN 1 --- [green] [exec-3] c.c.e.AiClient : 재시도 Timeout
    2026-10-08T09:04:00.000+09:00  INFO 1 --- [green] [exec-4] c.c.l.Aspect : [METHOD] RoutineController
      - authorization: Bearer x
    """;

  @TempDir
  Path tempDir;

  private AdminLogSearchService service;

  @BeforeEach
  void setUp() throws IOException {
    service = new AdminLogSearchService(new LogFileLocator(tempDir.toString(), "green"));
    Files.createDirectories(tempDir.resolve("green"));
    Files.writeString(tempDir.resolve("green/elum.log"), LOG, StandardCharsets.UTF_8);
  }

  @Test
  @DisplayName("스택트레이스·덤프 줄은 앞 항목에 붙어 한 건이 되고, 최신이 앞에 온다")
  void groupsContinuationLines() {
    LogSearchResponse response = service.search(null, null, null, null, null);

    assertThat(response.scanned()).isEqualTo(5);
    assertThat(response.entries()).extracting(Entry::level).containsExactly("INFO", "WARN", "ERROR", "DEBUG", "INFO");
    assertThat(response.entries().get(2).text()).contains("IllegalStateException").contains("Foo.java:10");
    assertThat(response.entries().get(0).text()).contains("authorization");
  }

  @Test
  @DisplayName("요청 id·회원 id 가 붙은 새 형식 줄도 한 항목으로 읽고, 요청 id 로 찾고, CSV 열로 꺼낸다 (옛 형식은 빈 칸)")
  void readsRequestContextLines() throws IOException {
    // logback-spring.xml FILE_LOG_PATTERN: --- [인스턴스] [요청 id] [회원 id] [스레드]
    Files.writeString(tempDir.resolve("green/elum.log"), LOG
      + "2026-10-08T09:05:00.000+09:00 ERROR 1 --- [green] [a1b2c3d4e5f6] [m-123] [exec-5] c.c.e.Handler : 실패\n"
      + "java.lang.IllegalStateException: boom2\n"
      + "2026-10-08T09:06:00.000+09:00  INFO 1 --- [green] [] [] [scheduling-1] c.c.e.Job : 정리 끝\n",
      StandardCharsets.UTF_8);

    LogSearchResponse all = service.search(null, null, null, null, null);
    assertThat(all.scanned()).isEqualTo(7);

    LogSearchResponse byRequestId = service.search(null, null, "a1b2c3d4e5f6", null, null);
    assertThat(byRequestId.entries()).hasSize(1);
    Entry requestEntry = byRequestId.entries().get(0);
    assertThat(requestEntry.level()).isEqualTo("ERROR");
    assertThat(requestEntry.text()).contains("boom2");

    List<CsvColumn<Entry>> columns = AdminLogSearchCsv.csvColumns();
    assertThat(columns.get(2).header()).isEqualTo("요청 id");
    assertThat(columns.get(2).valueOf().apply(requestEntry)).isEqualTo("a1b2c3d4e5f6");
    assertThat(columns.get(3).valueOf().apply(requestEntry)).isEqualTo("m-123");
    // 요청 밖 줄([] [])과 옛 형식 줄은 빈 칸
    assertThat(columns.get(2).valueOf().apply(all.entries().get(0))).isEmpty();
    assertThat(columns.get(2).valueOf().apply(all.entries().get(2))).isEmpty();
  }

  @Test
  @DisplayName("최소 레벨 WARN 이면 WARN·ERROR 만")
  void filtersByMinimumLevel() {
    LogSearchResponse response = service.search("green/elum.log", "warn", null, null, null);

    assertThat(response.entries()).extracting(Entry::level).containsExactly("WARN", "ERROR");
    assertThat(response.matched()).isEqualTo(2);
  }

  @Test
  @DisplayName("키워드는 대소문자를 가리지 않고 항목 전체(스택트레이스 포함)에서 찾는다")
  void filtersByKeyword() {
    assertThat(service.search(null, null, "illegalstate", null, null).entries()).hasSize(1);
    assertThat(service.search(null, null, "timeout", null, null).entries()).extracting(Entry::level).containsExactly("WARN");
  }

  @Test
  @DisplayName("from 이후 항목만, limit 은 최신 순으로 자른다")
  void filtersByFromAndLimit() {
    LogSearchResponse fromResult = service.search(null, null, null, "2026-10-08T09:02:00+09:00", null);
    assertThat(fromResult.entries()).hasSize(3);

    LogSearchResponse limited = service.search(null, null, null, null, 2);
    assertThat(limited.matched()).isEqualTo(5);
    assertThat(limited.entries()).extracting(Entry::timestamp)
      .containsExactly("2026-10-08T09:04:00.000+09:00", "2026-10-08T09:03:00.000+09:00");
  }

  @Test
  @DisplayName("압축된 지난 로그도 검색한다")
  void searchesGzip() throws IOException {
    Path gz = tempDir.resolve("green/elum.2026-10-07.0.log.gz");
    try (OutputStream out = new GZIPOutputStream(Files.newOutputStream(gz))) {
      out.write(LOG.getBytes(StandardCharsets.UTF_8));
    }

    assertThat(service.search("green/elum.2026-10-07.0.log.gz", "ERROR", null, null, null).entries()).hasSize(1);
  }

  @Test
  @DisplayName("깨진 압축 파일은 LOG_FILE_READ_FAILED, 잘못된 레벨·시각은 400")
  void failures() throws IOException {
    Files.write(tempDir.resolve("green/elum.2026-10-06.0.log.gz"), new byte[] {1, 2, 3, 4});

    assertThatThrownBy(() -> service.search("green/elum.2026-10-06.0.log.gz", null, null, null, null))
      .extracting("errorCode").isEqualTo(ErrorCode.LOG_FILE_READ_FAILED);
    assertThatThrownBy(() -> service.search(null, "LOUD", null, null, null))
      .extracting("errorCode").isEqualTo(ErrorCode.INVALID_LOG_LEVEL);
    assertThatThrownBy(() -> service.search(null, null, null, "어제", null))
      .extracting("errorCode").isEqualTo(ErrorCode.INVALID_INPUT_VALUE);
  }

  @Test
  @DisplayName("거대한 항목은 잘라서 truncated 로 표시한다")
  void truncatesHugeEntry() throws IOException {
    String huge = "2026-10-08T09:00:00.000+09:00  INFO 1 --- [green] [main] a.B : start\n"
      + ("x".repeat(1000) + "\n").repeat(50);
    Files.writeString(tempDir.resolve("green/elum.log"), huge, StandardCharsets.UTF_8);

    Entry entry = service.search(null, null, null, null, null).entries().get(0);

    assertThat(entry.truncated()).isTrue();
    assertThat(entry.text().length()).isLessThanOrEqualTo(AdminLogSearchService.MAX_ENTRY_CHARS);
  }
}
