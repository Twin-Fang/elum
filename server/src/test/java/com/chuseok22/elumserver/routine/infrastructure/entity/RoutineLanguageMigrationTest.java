package com.chuseok22.elumserver.routine.infrastructure.entity;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.AppLocaleConverter;
import jakarta.persistence.Column;
import jakarta.persistence.Convert;
import java.io.IOException;
import java.lang.reflect.Field;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.stream.Collectors;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * V33 이 "추가만 한다"는 약속을 지키고 엔티티와 같은지 글로 확인한다 (다국어 #526, V25~V31 과 같은 약속).
 *
 * <p>운영은 ddl-auto: validate 라 컬럼 이름·길이가 어긋나면 서버가 뜨지 않는다. 옛 서버 이미지로 되돌려도 이 스키마 위에서
 * 옛 코드가 돌아야 하므로 NOT NULL 에는 DEFAULT 가 있어야 한다. DB 를 띄우지 않는다 — 실제 적용은 운영 사본 리허설에서 본다.
 */
class RoutineLanguageMigrationTest {

  private static final Path V33 = Path.of("src/main/resources/db/migration/V33__add_routine_language.sql");

  private static String normalizedSql() throws IOException {
    return Files.readAllLines(V33).stream()
      .map(line -> line.contains("--") ? line.substring(0, line.indexOf("--")) : line)
      .collect(Collectors.joining(" "))
      .replaceAll("\\s+", " ")
      .toLowerCase();
  }

  @Test
  @DisplayName("V33 은 language 를 DEFAULT 'ko' 와 함께 더하기만 한다 — 기존 일과는 모두 한국어다")
  void addsColumnWithDefaultOnly() throws IOException {
    String sql = normalizedSql();

    assertThat(sql).doesNotContain("drop ").doesNotContain("rename ").doesNotContain("update routine")
      .doesNotContain("set not null");
    assertThat(sql).contains(
      "alter table routine add column if not exists language varchar(8) not null default 'ko';");
  }

  @Test
  @DisplayName("V33 은 엔티티와 같다 — 컬럼 이름·길이·NOT NULL·변환기")
  void matchesEntity() throws Exception {
    Field field = Routine.class.getDeclaredField("language");
    Column column = field.getAnnotation(Column.class);

    assertThat(column.name()).isEqualTo("language");
    assertThat(column.length()).isEqualTo(8);
    assertThat(column.nullable()).isFalse();
    assertThat(field.getAnnotation(Convert.class).converter()).isEqualTo(AppLocaleConverter.class);
  }

  @Test
  @DisplayName("새 Routine 의 기본 언어는 ko 다 — 언어를 모르는 생성 경로(복제·테스트)도 지금과 같다")
  void newRoutine_defaultsToKo() {
    assertThat(new Routine().getLanguage()).isEqualTo(AppLocale.KO);
  }
}
