package com.chuseok22.elumserver.common;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.stream.Collectors;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * V25 가 "추가만 한다"는 약속을 지키는지 글로 확인한다 (다중 보호자 명세 5장 되돌리기, E38).
 *
 * <p>Flyway 는 스키마를 되돌리지 않는다. 1단계 배포 뒤 옛 서버 이미지로 되돌려도 V25 위에서 옛 코드가
 * 돌아야 하는데, 한 줄만 어긋나도(NOT NULL 하나, CASCADE 하나) 옛 서버의 일과 생성이나 탈퇴가 통째로
 * 실패한다. 무중단 배포(#163)가 없어 그때는 돌아갈 곳이 없다.
 *
 * <p>명세는 이 마이그레이션을 V22 로 적었지만 그 번호는 공지(#370)·탈퇴 보관(#372)·프롬프트 키(#375)가
 * 먼저 썼다(운영 최신 V24). 내용은 명세 5장 "V22 — 늘리고 옮긴다" 그대로다.
 *
 * <p>DB 를 띄우지 않는다. 실제 적용은 운영 사본 리허설에서 본다.
 */
class MigrationRollbackContractTest {

  private static final Path V25 = Path.of(
    "src/main/resources/db/migration/V25__add_profile_guardian_and_routine_creator.sql");

  @Test
  @DisplayName("E38 V25 는 routine.created_by 에 NOT NULL 을 걸지 않는다 — 옛 서버의 일과 생성이 전부 실패한다")
  void e38_createdByStaysNullable() throws IOException {
    String sql = normalizedSql();
    assertThat(sql).contains("add column if not exists created_by varchar(255) references member (id)");
    assertThat(sql).doesNotContainPattern("created_by[^;]*not null");
  }

  @Test
  @DisplayName("E38 V25 는 컬럼·표를 지우지 않는다 — profile.member_id 는 NULL 만 허용한다")
  void e38_dropsNothing() throws IOException {
    String sql = normalizedSql();
    assertThat(sql).doesNotContain("drop column").doesNotContain("drop table");
    assertThat(sql).contains("alter table profile alter column member_id drop not null");
  }

  @Test
  @DisplayName("E38 관계 표의 외래키는 ON DELETE CASCADE 다 — 옛 서버의 탈퇴는 이 표를 모르고 profile·member 를 지운다")
  void e38_guardianForeignKeysCascade() throws IOException {
    // 표마다 따로 본다 — 초대 표에도 같은 모양의 줄이 있어 파일 전체로 보면 관계 표에서 빠져도 통과한다.
    String table = tableBlock("profile_guardian");
    assertThat(table).contains("profile_id varchar(255) not null references profile (id) on delete cascade");
    assertThat(table).contains("member_id varchar(255) not null references member (id) on delete cascade");
  }

  @Test
  @DisplayName("E38 초대 코드 표도 이룸이·발급자를 CASCADE 로 잡는다 — 1단계 서버로 되돌려도 탈퇴가 막히지 않는다")
  void e38_inviteForeignKeysDoNotBlockDeletes() throws IOException {
    String sql = tableBlock("profile_invite");
    assertThat(sql).contains("profile_id varchar(255) not null references profile (id) on delete cascade");
    assertThat(sql).contains("issued_by varchar(255) not null references member (id) on delete cascade");
    assertThat(sql).contains("redeemed_by varchar(255) references member (id) on delete set null");
  }

  @Test
  @DisplayName("E31 기존 일과의 만든 사람은 그 프로필의 보호자로 채운다")
  void e31_backfillsCreatorFromProfileOwner() throws IOException {
    assertThat(normalizedSql()).contains(
      "update routine r set created_by = (select p.member_id from profile p where p.id = r.profile_id) where r.created_by is null");
  }

  // --- V26 AI 크레딧 (#407) — 같은 "추가만 한다" 약속 ---

  private static final Path V26 = Path.of("src/main/resources/db/migration/V26__create_ai_credit.sql");

  @Test
  @DisplayName("V26 은 표·컬럼을 지우지 않고 기존 표에 NOT NULL 을 걸지 않는다 — 옛 서버가 그대로 돈다")
  void v26_addsOnly() throws IOException {
    String sql = normalizedSql(V26);
    assertThat(sql).doesNotContain("drop column").doesNotContain("drop table").doesNotContain("drop not null");
    assertThat(sql).contains("alter table ai_call_log add column if not exists credit_job_id varchar(255);");
    assertThat(sql).doesNotContainPattern("credit_job_id[^;]*not null");
  }

  @Test
  @DisplayName("V26 의 크레딧 계정은 member 에 외래키를 걸지 않는다 — 옛 서버의 완전 삭제가 이 표를 모르고 member 를 지운다")
  void v26_accountHasNoMemberForeignKey() throws IOException {
    String sql = normalizedSql(V26);
    int start = sql.indexOf("create table if not exists ai_credit_account (");
    assertThat(start).isNotNegative();
    assertThat(sql.substring(start, sql.indexOf(");", start))).doesNotContain("references member");
  }

  @Test
  @DisplayName("V26 의 주간 지급 키는 코드(CreditPeriod)와 같은 ISO 주 형식이다 — 어긋나면 이번 주에 한 번 더 지급한다")
  void v26_periodKeyMatchesCode() throws IOException {
    String sql = normalizedSql(V26);
    assertThat(sql).contains("to_char(now() at time zone 'asia/seoul', 'iyyy-\"w\"iw')");
    assertThat(sql).contains("date_trunc('week', now() at time zone 'asia/seoul')");
  }

  @Test
  @DisplayName("V26 시드는 다시 돌려도 중복을 만들지 않는다")
  void v26_seedIsIdempotent() throws IOException {
    String sql = normalizedSql(V26);
    assertThat(sql).contains("on conflict do nothing");
    assertThat(sql).contains("not exists (select 1 from ai_credit_ledger l where l.grant_id = g.id)");
  }

  /** create table 한 덩이 — 여는 괄호부터 그 표를 닫는 ");" 까지. */
  private String tableBlock(String table) throws IOException {
    String sql = normalizedSql();
    int start = sql.indexOf("create table if not exists " + table + " (");
    assertThat(start).as("%s 표를 만드는 문장이 없다", table).isNotNegative();
    return sql.substring(start, sql.indexOf(");", start));
  }

  /** 주석을 빼고 공백을 하나로, 소문자로 — 주석에 적힌 "not null" 설명이 검사를 속이지 않게 한다. */
  private String normalizedSql() throws IOException {
    return normalizedSql(V25);
  }

  private String normalizedSql(Path file) throws IOException {
    return Files.readAllLines(file).stream()
      .map(line -> line.contains("--") ? line.substring(0, line.indexOf("--")) : line)
      .collect(Collectors.joining(" "))
      .replaceAll("\\s+", " ")
      .toLowerCase();
  }
}
