package com.chuseok22.elumserver.admin.application.list;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineResponse;
import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import java.time.LocalDateTime;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class AdminRoutineListTest {

  private static final AdminDateFormatter DATE_FORMATTER = new AdminDateFormatter();

  private AdminRoutineResponse response(String memberUsername) {
    return new AdminRoutineResponse("r1", "아침 준비", "m1", "하늘이", memberUsername, RoutineStatus.COMPLETED,
      LocalDateTime.of(2026, 10, 2, 9, 0), null, "ko", LocalDateTime.of(2026, 10, 3, 10, 5));
  }

  @Test
  @DisplayName("허용 밖 정렬 키는 기본(최근 변경 내림차순)으로 돌아간다")
  void unknownSort_fallsBackToDefault() {
    AdminListQuery query = AdminListQuery.of(null, null, "rawInputText,asc", null, AdminRoutineList.DEFINITION);

    assertThat(query.sort()).isEqualTo("updatedAt,desc");
  }

  @Test
  @DisplayName("정렬 가능 열은 받아들이고, 상태 필터는 허용 값만 남긴다")
  void allowedSortAndStatusOnly() {
    AdminListQuery ok = AdminListQuery.of(null, Map.of("status", "CONFIRMED"), "title,asc", "3", AdminRoutineList.DEFINITION);
    AdminListQuery bad = AdminListQuery.of(null, Map.of("status", "NOPE"), "member,asc", "-5", AdminRoutineList.DEFINITION);

    assertThat(ok.sort()).isEqualTo("title,asc");
    assertThat(ok.filters()).containsEntry("status", "CONFIRMED");
    assertThat(ok.page()).isEqualTo(3);
    assertThat(bad.filters()).isEmpty();
    assertThat(bad.sort()).isEqualTo("updatedAt,desc");
    assertThat(bad.page()).isEqualTo(1);
  }

  @Test
  @DisplayName("검색어의 LIKE 특수문자 %, _, \\ 가 이스케이프된다")
  void likePattern_escapesSpecialCharacters() {
    AdminListQuery query = AdminListQuery.of("a%b_c\\d", null, null, null, AdminRoutineList.DEFINITION);

    assertThat(query.likePattern()).isEqualTo("%a\\%b\\_c\\\\d%");
  }

  @Test
  @DisplayName("행은 제목을 일과 상세로, 보호자를 회원 상세로 잇고 마지막 변경을 보인다")
  void row_linksRoutineAndMember() {
    AdminListRow row = AdminRoutineList.toRow(response("parent1"), DATE_FORMATTER);

    assertThat(row.linkUrl()).isEqualTo("/admin/routines/r1");
    assertThat(row.cellLinks()).containsEntry("member", "/admin/members/m1");
    assertThat(row.cells()).containsEntry("member", "parent1").containsEntry("status", "완료")
      .containsEntry("completedAt", "-").containsEntry("updatedAt", "2026-10-03 10:05");
  }

  @Test
  @DisplayName("보호자 계정을 못 찾으면 회원 링크를 만들지 않는다")
  void row_withoutMember_hasNoMemberLink() {
    AdminListRow row = AdminRoutineList.toRow(response(null), DATE_FORMATTER);

    assertThat(row.cellLinks()).isEmpty();
    assertThat(row.cells()).containsEntry("member", "-");
  }
}
