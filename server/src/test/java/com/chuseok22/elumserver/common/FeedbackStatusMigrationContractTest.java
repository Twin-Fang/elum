package com.chuseok22.elumserver.common;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * V40(의견 처리 상태)이 "추가만 한다"는 약속을 글로 확인한다 (#756). DB 를 띄우지 않는다.
 * 기존 행은 NEW 로 채워지고, 옛 서버 이미지로 되돌려도 새 행이 NEW 가 되며, 몇 번을 실행해도 같다.
 */
class FeedbackStatusMigrationContractTest {

  private static final Path V40 = Path.of("src/main/resources/db/migration/V40__add_feedback_status.sql");

  private static String sqlWithoutComments() throws IOException {
    StringBuilder sql = new StringBuilder();
    for (String line : Files.readAllLines(V40)) {
      if (!line.strip().startsWith("--")) {
        sql.append(line).append(' ');
      }
    }
    return sql.toString().replaceAll("\\s+", " ").toLowerCase(Locale.ROOT).trim();
  }

  @Test
  @DisplayName("기존 의견은 status 가 NEW 로 채워진다: NOT NULL DEFAULT 'NEW' 로 한 번에 더한다")
  void existingRowsBecomeNew() throws IOException {
    assertThat(sqlWithoutComments())
      .contains("alter table feedback add column if not exists status varchar(20) not null default 'new';");
  }

  @Test
  @DisplayName("변경자·변경 시각 컬럼은 NULL 을 허용한다 — 한 번도 안 바꾼 의견과 옛 서버가 쓴 행")
  void changeColumnsNullable() throws IOException {
    String sql = sqlWithoutComments();
    assertThat(sql).contains("add column if not exists status_changed_at timestamp(6);");
    assertThat(sql).contains("add column if not exists status_changed_by varchar(255);");
  }

  @Test
  @DisplayName("지우거나 줄이지 않고, 모든 문장이 여러 번 실행해도 같다 (IF NOT EXISTS)")
  void additiveAndIdempotent() throws IOException {
    String sql = sqlWithoutComments();
    assertThat(sql).doesNotContain("drop ").doesNotContain("truncate").doesNotContain("delete from")
      .doesNotContain("update ").doesNotContain("create table ");
    for (String statement : sql.split(";")) {
      if (!statement.isBlank()) {
        assertThat(statement).as(statement).contains("if not exists");
      }
    }
  }
}
