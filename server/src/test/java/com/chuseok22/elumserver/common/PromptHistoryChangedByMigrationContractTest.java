package com.chuseok22.elumserver.common;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * V41(프롬프트 이력 수정자)이 "추가만 한다"는 약속을 글로 확인한다 (#758). DB 를 띄우지 않는다.
 * 기존 이력 행은 changed_by 가 NULL 로 남고, 몇 번을 실행해도 같다.
 */
class PromptHistoryChangedByMigrationContractTest {

  private static final Path V41 = Path.of("src/main/resources/db/migration/V41__add_prompt_history_changed_by.sql");

  private static String sqlWithoutComments() throws IOException {
    StringBuilder sql = new StringBuilder();
    for (String line : Files.readAllLines(V41)) {
      if (!line.strip().startsWith("--")) {
        sql.append(line).append(' ');
      }
    }
    return sql.toString().replaceAll("\\s+", " ").toLowerCase(Locale.ROOT).trim();
  }

  @Test
  @DisplayName("changed_by 는 NULL 을 허용하는 컬럼 하나만 더한다 — 기존 행은 값이 비어 '-' 로 보인다")
  void addsNullableColumnOnly() throws IOException {
    assertThat(sqlWithoutComments())
      .isEqualTo("alter table prompt_template_history add column if not exists changed_by varchar(255);");
  }

  @Test
  @DisplayName("지우거나 고치지 않는다")
  void isAdditive() throws IOException {
    assertThat(sqlWithoutComments()).doesNotContain("drop ").doesNotContain("truncate")
      .doesNotContain("delete from").doesNotContain("update ").doesNotContain("not null");
  }
}
