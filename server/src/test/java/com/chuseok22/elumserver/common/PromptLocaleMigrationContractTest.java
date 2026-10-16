package com.chuseok22.elumserver.common;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplate;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplateHistory;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.stream.Collectors;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * V36(프롬프트 언어)이 "더하고 풀기만 한다"는 약속을 지키는지 글로 확인한다. DB 는 띄우지 않는다 —
 * 실제 적용은 운영 사본 리허설에서 본다.
 */
class PromptLocaleMigrationContractTest {

  private static final Path V36 = Path.of("src/main/resources/db/migration/V36__add_prompt_template_locale.sql");

  @Test
  @DisplayName("V36 은 locale 을 DEFAULT 'ko' 로 더한다 — 기존 행은 모두 ko 가 되고 옛 서버의 INSERT 도 깨지지 않는다")
  void addsLocaleWithKoDefault() throws IOException {
    String sql = normalizedSql();
    assertThat(sql).contains("alter table prompt_template add column if not exists locale varchar(8) not null default 'ko'");
    assertThat(sql).contains("alter table prompt_template_history add column if not exists locale varchar(8) not null default 'ko'");
  }

  @Test
  @DisplayName("V36 은 표·컬럼을 지우지 않고 유니크를 (prompt_key, locale) 로 푼다")
  void relaxesUniqueOnly() throws IOException {
    String sql = normalizedSql();
    assertThat(sql).doesNotContain("drop column").doesNotContain("drop table").doesNotContain("set not null");
    assertThat(sql).contains("create unique index if not exists ux_prompt_template_key_locale on prompt_template (prompt_key, locale)");
    // 옛 유니크 제약은 ddl-auto 가 이름을 정해 만들었다 — 이름을 박지 않고 prompt_key 한 칸짜리 제약을 찾아 지운다
    assertThat(sql).contains("con.contype = 'u'").contains("drop constraint");
  }

  @Test
  @DisplayName("V36 은 엔티티와 같다 — 운영은 validate 라 컬럼 이름·길이가 어긋나면 서버가 뜨지 않는다")
  void matchesEntities() throws Exception {
    var template = PromptTemplate.class.getDeclaredField("locale").getAnnotation(jakarta.persistence.Column.class);
    assertThat(template.name().isEmpty() ? "locale" : template.name()).isEqualTo("locale");
    assertThat(template.length()).isEqualTo(8);
    assertThat(template.nullable()).isFalse();
    var history = PromptTemplateHistory.class.getDeclaredField("locale").getAnnotation(jakarta.persistence.Column.class);
    assertThat(history.length()).isEqualTo(8);
    assertThat(history.nullable()).isFalse();
    var table = PromptTemplate.class.getAnnotation(jakarta.persistence.Table.class);
    assertThat(table.uniqueConstraints()).hasSize(1);
    assertThat(table.uniqueConstraints()[0].columnNames()).containsExactly("prompt_key", "locale");
  }

  @Test
  @DisplayName("V36 머리 주석은 되돌리기 전에 ko 가 아닌 행을 지우라고 적는다 — 옛 서버의 findByPromptKey 가 여러 행에 터진다")
  void headerWarnsAboutRollback() throws IOException {
    String raw = String.join("\n", Files.readAllLines(V36));
    assertThat(raw).contains("옛 서버").contains("locale <> 'ko'");
  }

  /** 주석을 빼고 공백을 하나로, 소문자로 — 주석에 적힌 설명이 검사를 속이지 않게 한다. */
  private String normalizedSql() throws IOException {
    return Files.readAllLines(V36).stream()
      .map(line -> line.contains("--") ? line.substring(0, line.indexOf("--")) : line)
      .collect(Collectors.joining(" "))
      .replaceAll("\\s+", " ")
      .toLowerCase();
  }
}
