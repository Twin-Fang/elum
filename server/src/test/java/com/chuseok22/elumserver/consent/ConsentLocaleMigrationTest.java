package com.chuseok22.elumserver.consent;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import jakarta.persistence.Column;
import jakarta.persistence.Table;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * V58 계약 (#531): 기존 행 ko, 옛 서버 호환(더하고 푸는 것만), 엔티티와 열 일치
 * 운영은 ddl-auto 로 열 이름이 어긋나면 새 열이 따로 생기므로 이름까지 맞춘다. DB 는 띄우지 않는다
 */
class ConsentLocaleMigrationTest {

  private static final Path V58 = Path.of(
    "src/main/resources/db/migration/V58__add_consent_locale_and_notice_target_countries.sql");

  @Test
  @DisplayName("약관·이력 언어 열은 DEFAULT 'ko' 와 함께 더한다 — 기존 약관이 모두 한국어 행이 된다")
  void addsLocaleWithKoDefault() throws IOException {
    String sql = normalizedSql();
    assertThat(sql).contains(
      "alter table consent_document add column if not exists locale varchar(8) not null default 'ko'");
    assertThat(sql).contains(
      "alter table consent_document_history add column if not exists locale varchar(8) not null default 'ko'");
  }

  @Test
  @DisplayName("유니크를 (consent_key, locale) 로 바꾼다 — 옛 유니크는 이름이 아니라 모양으로 찾아 지운다")
  void swapsUniqueToKeyAndLocale() throws IOException {
    String sql = normalizedSql();
    assertThat(sql).contains("con.contype = 'u'").contains("att.attname = 'consent_key'").contains("drop constraint");
    assertThat(sql).contains(
      "create unique index if not exists ux_consent_document_key_locale on consent_document (consent_key, locale)");
    Table table = ConsentDocument.class.getAnnotation(Table.class);
    assertThat(table.uniqueConstraints()[0].name()).isEqualTo("ux_consent_document_key_locale");
  }

  @Test
  @DisplayName("이미 동의한 회원은 ko 로 채우고, 동의 언어·대상 국가 열은 NULL 을 허용한다 — 옛 서버가 그대로 돈다")
  void backfillsConsentedMembersAndKeepsNullable() throws Exception {
    String sql = normalizedSql();
    assertThat(sql).contains("alter table member add column if not exists consent_locale varchar(8);");
    assertThat(sql).contains(
      "update member set consent_locale = 'ko' where consented_at is not null and consent_locale is null");
    assertThat(sql).contains("alter table app_notice add column if not exists target_countries varchar(255);");
    assertThat(sql).doesNotContain("drop column").doesNotContain("drop table").doesNotContain("set not null");

    assertThat(Member.class.getDeclaredField("consentLocale").getAnnotation(Column.class).name())
      .isEqualTo("consent_locale");
    assertThat(AppNotice.class.getDeclaredField("targetCountries").getAnnotation(Column.class).name())
      .isEqualTo("target_countries");
  }

  /** 주석을 걷고 공백을 하나로, 소문자로 */
  private static String normalizedSql() throws IOException {
    StringBuilder body = new StringBuilder();
    for (String line : Files.readAllLines(V58)) {
      String withoutComment = line.contains("--") ? line.substring(0, line.indexOf("--")) : line;
      body.append(withoutComment).append(' ');
    }
    return body.toString().replaceAll("\\s+", " ").toLowerCase(Locale.ROOT);
  }
}
