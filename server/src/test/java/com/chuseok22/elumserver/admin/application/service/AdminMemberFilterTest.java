package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.member.application.service.MemberAdminLookupService;
import java.util.List;
import java.util.stream.IntStream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 광고 보상·알림 목록의 회원 조건: 회원 ID 와 검색어를 함께 넣으면 교집합, 너무 많으면 잘림 표시
 */
class AdminMemberFilterTest {

  private final MemberAdminLookupService lookupService = mock(MemberAdminLookupService.class);
  private final AdminMemberFilter memberFilter = new AdminMemberFilter(lookupService);

  @Test
  @DisplayName("회원 ID 와 맞지 않는 검색어를 함께 넣으면 다른 회원 기록이 섞이지 않고 0건이 된다")
  void memberIdAndKeywordIntersect() {
    when(lookupService.findMemberIdsByKeyword("kakao", AdminMemberFilter.MAX_KEYWORD_MEMBER_COUNT + 1)).thenReturn(List.of("member-2", "member-3"));

    assertThat(memberFilter.resolve("member-1", "kakao").memberIds()).isEmpty();
    assertThat(memberFilter.resolve("member-2", "kakao").memberIds()).containsExactly("member-2");
    assertThat(memberFilter.resolve(null, null).memberIds()).isNull();
  }

  @Test
  @DisplayName("검색어에 맞는 회원이 상한을 넘으면 잘렸다고 알린다 (조용히 일부만 보이지 않게)")
  void tooManyKeywordMatchesAreFlagged() {
    List<String> manyIds = IntStream.range(0, AdminMemberFilter.MAX_KEYWORD_MEMBER_COUNT + 1)
      .mapToObj(index -> "member-" + index).toList();
    when(lookupService.findMemberIdsByKeyword("a", AdminMemberFilter.MAX_KEYWORD_MEMBER_COUNT + 1)).thenReturn(manyIds);

    AdminMemberFilter.Resolved resolved = memberFilter.resolve(null, "a");

    assertThat(resolved.isTruncated()).isTrue();
    assertThat(resolved.memberIds()).hasSize(AdminMemberFilter.MAX_KEYWORD_MEMBER_COUNT);
  }
}
