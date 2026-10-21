package com.chuseok22.elumserver.talk.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * 실제 Postgres 로 하는 Flyway 마이그레이션 <-> 엔티티 매핑 검증. 평소 빌드에서는 건너뛴다.
 * Flyway 적용 후 ddl-auto=validate 로 컨텍스트가 뜨면 V52 의 표·칼럼이 엔티티와 맞는 것이다.
 * 빈 DB 에서는 V8 에서 멈추므로(ddl-auto 로 만든 스키마 위의 ALTER), 이야기 표를 뺀 스키마에서 ELUM_IT_FLYWAY_BASELINE=51 로 V52 만 적용한다.
 * 전용 임시 DB 의 주소가 있을 때만 돌고, 다른 IT 와 달리 기본 주소가 없다.
 *
 * <pre>
 * ELUM_IT_SCHEMA_VALIDATE_DB_URL=jdbc:postgresql://localhost:5432/elum_it_schema ELUM_IT_FLYWAY_BASELINE=51 \
 *   ./gradlew test --tests '*TalkSchemaValidateIT'
 * </pre>
 */
@SpringBootTest(properties = {
  "spring.datasource.url=${ELUM_IT_SCHEMA_VALIDATE_DB_URL}",
  "spring.datasource.username=${ELUM_IT_DB_USERNAME:elum}",
  "spring.datasource.password=${ELUM_IT_DB_PASSWORD:pw}",
  "spring.flyway.enabled=true",
  "spring.flyway.baseline-on-migrate=true",
  "spring.flyway.baseline-version=${ELUM_IT_FLYWAY_BASELINE:0}",
  "spring.jpa.hibernate.ddl-auto=validate",
  "gemini.api-key=rehearsal-invalid"
})
@EnabledIfEnvironmentVariable(named = "ELUM_IT_SCHEMA_VALIDATE_DB_URL", matches = ".+")
class TalkSchemaValidateIT {

  private static final List<String> EXPECTED_INDEXES = List.of(
    "idx_talk_report_post_id", "idx_talk_comment_author_member_id", "idx_talk_helpful_member_id",
    "idx_talk_import_member_id", "idx_talk_block_blocked_member_id", "uk_talk_post_visible_source");

  @Autowired private JdbcTemplate jdbcTemplate;

  @Test
  @DisplayName("Flyway 적용 뒤 엔티티 검증(validate)으로 컨텍스트가 뜨고, V52 의 인덱스가 실제로 만들어진다")
  void contextStartsWithValidateAndIndexesExist() {
    List<String> indexNames = jdbcTemplate.queryForList(
      "select indexname from pg_indexes where schemaname = current_schema() and tablename like 'talk_%'", String.class);

    assertThat(indexNames).containsAll(EXPECTED_INDEXES);
  }
}
