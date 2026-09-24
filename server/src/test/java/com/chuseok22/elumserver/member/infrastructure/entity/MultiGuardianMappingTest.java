package com.chuseok22.elumserver.member.infrastructure.entity;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import jakarta.persistence.Column;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.Table;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 엔티티가 V25 가 만든 표·컬럼 이름과 맞는지 본다.
 *
 * <p>테스트가 DB 를 띄우지 않아 이름 하나가 어긋나도 컴파일·단위 테스트가 모두 통과한다.
 * 운영 ddl-auto 가 validate 면 부팅이 죽고, update 면 Hibernate 가 엉뚱한 컬럼을 새로 만든다.
 */
class MultiGuardianMappingTest {

  @Test
  @DisplayName("관계 엔티티는 V25 의 profile_guardian 표·컬럼과 이름이 같다")
  void profileGuardian_matchesV25Columns() throws NoSuchFieldException {
    Table table = ProfileGuardian.class.getAnnotation(Table.class);
    assertThat(table.name()).isEqualTo("profile_guardian");
    assertThat(table.uniqueConstraints()[0].columnNames()).containsExactly("profile_id", "member_id");
    assertThat(joinColumn(ProfileGuardian.class, "profile").name()).isEqualTo("profile_id");
    assertThat(joinColumn(ProfileGuardian.class, "member").name()).isEqualTo("member_id");
    assertThat(column(ProfileGuardian.class, "kind").length()).isEqualTo(30);
    Column joinedAt = column(ProfileGuardian.class, "joinedAt");
    assertThat(joinedAt.name()).isEqualTo("joined_at");
    assertThat(joinedAt.nullable()).isFalse();
  }

  @Test
  @DisplayName("일과를 만든 사람은 created_by 에 담기고 비워 둘 수 있다 — 옛 서버가 이 컬럼을 모른다")
  void routine_createdByIsNullableColumn() throws NoSuchFieldException {
    Column createdBy = column(Routine.class, "createdBy");
    assertThat(createdBy.name()).isEqualTo("created_by");
    assertThat(createdBy.nullable()).isTrue();
  }

  @Test
  @DisplayName("profile.member_id 는 비워 둘 수 있다 — 처음 만든 보호자가 나가도 이룸이가 남는다")
  void profile_memberIsNullable() throws NoSuchFieldException {
    assertThat(joinColumn(Profile.class, "member").nullable()).isTrue();
  }

  private JoinColumn joinColumn(Class<?> type, String field) throws NoSuchFieldException {
    return type.getDeclaredField(field).getAnnotation(JoinColumn.class);
  }

  private Column column(Class<?> type, String field) throws NoSuchFieldException {
    return type.getDeclaredField(field).getAnnotation(Column.class);
  }
}
