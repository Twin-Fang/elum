package com.chuseok22.elumserver.admin.application.list;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Column;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Filter;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Option;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** 목록 쿼리 보정: 잘못된 정렬·페이지·검색어·필터가 들어와도 기본값으로 돌아가 500 이 나지 않는다. */
class AdminListQueryTest {

  private static final AdminListDefinition DEFINITION = new AdminListDefinition(
    List.of(new Column("createdAt", "가입일", true), new Column("name", "이름", true), new Column("memo", "메모", false)),
    List.of("name"),
    List.of(new Filter("status", "상태", List.of(new Option("ACTIVE", "활성"), new Option("WITHDRAWN", "탈퇴")))),
    "createdAt,desc");

  private static AdminListQuery of(String q, Map<String, String> filters, String sort, String page) {
    return AdminListQuery.of(q, filters, sort, page, DEFINITION);
  }

  @Test
  @DisplayName("허용 목록 밖 정렬 키는 기본 정렬로 돌아간다")
  void unknownSort_fallsBackToDefault() {
    assertThat(of(null, null, "password", null).sort()).isEqualTo("createdAt,desc");
    assertThat(of(null, null, "memo", null).sort()).as("정렬 불가 열").isEqualTo("createdAt,desc");
    assertThat(of(null, null, "name,sideways", null).sort()).as("방향이 이상함").isEqualTo("createdAt,desc");
    assertThat(of(null, null, "'; drop table", null).sort()).isEqualTo("createdAt,desc");
  }

  @Test
  @DisplayName("정렬 가능한 열은 그대로 쓰고 방향을 읽는다")
  void sortableColumn_isKept() {
    AdminListQuery query = of(null, null, "name,asc", null);

    assertThat(query.sort()).isEqualTo("name,asc");
    assertThat(query.sortKey()).isEqualTo("name");
    assertThat(query.isAscending()).isTrue();
    assertThat(of(null, null, null, null).isAscending()).isFalse();
  }

  @Test
  @DisplayName("숫자가 아니거나 1 미만인 페이지는 첫 페이지가 된다")
  void invalidPage_becomesFirstPage() {
    assertThat(of(null, null, null, "abc").page()).isEqualTo(1);
    assertThat(of(null, null, null, "-1").page()).isEqualTo(1);
    assertThat(of(null, null, null, "0").page()).isEqualTo(1);
    assertThat(of(null, null, null, "").page()).isEqualTo(1);
    assertThat(of(null, null, null, null).page()).isEqualTo(1);
    assertThat(of(null, null, null, "99999999999999999999").page()).isEqualTo(1);
  }

  @Test
  @DisplayName("범위를 넘은 페이지는 전체 페이지 수를 안 뒤 마지막 페이지로 맞춘다")
  void pageBeyondTotal_isClampedToLast() {
    AdminListQuery query = of(null, null, null, "9999");

    assertThat(query.withTotalPages(5).page()).isEqualTo(5);
    assertThat(query.withTotalPages(0).page()).as("결과 0건이어도 1페이지").isEqualTo(1);
    assertThat(query.withTotalPages(5).pageIndex()).isEqualTo(4);
  }

  @Test
  @DisplayName("빈 검색어는 null(전체)이고 앞뒤 공백은 잘린다")
  void blankKeyword_isNull() {
    assertThat(of("", null, null, null).q()).isNull();
    assertThat(of("   ", null, null, null).q()).isNull();
    assertThat(of("  하늘  ", null, null, null).q()).isEqualTo("하늘");
  }

  @Test
  @DisplayName("LIKE 특수문자는 이스케이프되고 빈 검색은 패턴이 없다")
  void likePattern_escapesWildcards() {
    assertThat(of("100%_a\\b'\"", null, null, null).likePattern()).isEqualTo("%100\\%\\_a\\\\b'\"%");
    assertThat(of(null, null, null, null).likePattern()).isNull();
  }

  @Test
  @DisplayName("정의에 없는 필터 키·옵션 값은 버린다")
  void unknownFilter_isDropped() {
    Map<String, String> raw = new HashMap<>();
    raw.put("status", "ACTIVE");
    raw.put("hacker", "1");
    assertThat(of(null, raw, null, null).filters()).containsExactly(Map.entry("status", "ACTIVE"));

    raw.put("status", "NOPE");
    assertThat(of(null, raw, null, null).filters()).isEmpty();

    raw.put("status", " ");
    assertThat(of(null, raw, null, null).filters()).isEmpty();
  }

  @Test
  @DisplayName("현재 조건을 지킨 채 정렬·페이지만 바꾼 쿼리 문자열을 만든다")
  void toQueryString_keepsConditionsAndEncodes() {
    AdminListQuery query = of("a b&c", Map.of("status", "ACTIVE"), "name,asc", "3");

    assertThat(query.toQueryString("createdAt,desc", 1))
      .isEqualTo("?q=a%20b%26c&status=ACTIVE&sort=createdAt,desc");
    assertThat(query.toQueryString(query.sort(), 3)).endsWith("&page=3");
    assertThat(of(null, null, null, null).toQueryString("createdAt,desc", 1)).isEqualTo("?sort=createdAt,desc");
  }

  @Test
  @DisplayName("검색어의 + 는 %2B 로 실어 페이지를 넘겨도 공백으로 바뀌지 않는다")
  void toQueryString_keepsPlusSign() {
    AdminListQuery query = of("C++", Map.of(), "name,asc", "1");

    assertThat(query.toQueryString(query.sort(), 2)).startsWith("?q=C%2B%2B&");
  }

  @Test
  @DisplayName("같은 열을 다시 누르면 방향이 뒤집히고 다른 열은 내림차순으로 시작한다")
  void nextSortFor_togglesDirection() {
    AdminListQuery query = of(null, null, "name,asc", null);

    assertThat(query.nextSortFor("name")).isEqualTo("name,desc");
    assertThat(query.nextSortFor("createdAt")).isEqualTo("createdAt,desc");
  }

  @Test
  @DisplayName("기본 정렬이 정렬 가능한 열이 아니면 정의를 만들 때 바로 실패한다")
  void definitionWithBadDefaultSort_fails() {
    org.junit.jupiter.api.Assertions.assertThrows(IllegalArgumentException.class, () ->
      new AdminListDefinition(List.of(new Column("memo", "메모", false)), List.of(), List.of(), "memo,desc"));
  }

  @Test
  @DisplayName("요청 파라미터 맵에서 정의에 있는 필터만 읽고, 형식이 틀린 날짜 필터는 빼서 칩·조건에 남지 않는다")
  void fromParameters_readsDefinedFiltersOnly() {
    AdminListDefinition withDate = new AdminListDefinition(DEFINITION.columns(), List.of("name"),
      List.of(DEFINITION.filters().get(0), Filter.date("from", "시작일"), Filter.text("guardian", "보호자")),
      "createdAt,desc");
    Map<String, String> parameters = new HashMap<>();
    parameters.put("q", " 하늘 ");
    parameters.put("status", "ACTIVE");
    parameters.put("from", "2026-13-40");
    parameters.put("guardian", "kim");
    parameters.put("password", "x");
    parameters.put("page", "2");

    AdminListQuery query = AdminListQuery.fromParameters(parameters, withDate);

    assertThat(query.q()).isEqualTo("하늘");
    assertThat(query.filters()).containsOnlyKeys("status", "guardian");
    assertThat(query.page()).isEqualTo(2);
    assertThat(AdminListQuery.fromParameters(null, withDate).hasConditions()).isFalse();
  }

  @Test
  @DisplayName("필터 초기화는 검색어·필터를 모두 빼고 정렬은 유지하며, 칩 하나 빼기는 그 조건만 뺀다")
  void withoutConditions_keepsSortOnly() {
    AdminListQuery query = of("하늘", Map.of("status", "ACTIVE"), "name,asc", "3");

    assertThat(query.hasConditions()).isTrue();
    assertThat(query.withoutConditions().toQueryString(query.sort(), 1)).isEqualTo("?sort=name,asc");
    assertThat(query.withKeyword(null).toQueryString(query.sort(), 1)).isEqualTo("?status=ACTIVE&sort=name,asc");
  }

  @Test
  @DisplayName("필터 값 LIKE 패턴: 포함·앞부분 일치 모두 %, _, \\ 를 이스케이프하고 빈 값은 null")
  void filterLikePatterns_escapeSpecialCharacters() {
    assertThat(AdminListQuery.toLikePattern(" a_b% ")).isEqualTo("%a\\_b\\%%");
    assertThat(AdminListQuery.toPrefixLikePattern("1.0_")).isEqualTo("1.0\\_%");
    assertThat(AdminListQuery.toLikePattern("  ")).isNull();
    assertThat(AdminListQuery.toPrefixLikePattern(null)).isNull();
  }
}
