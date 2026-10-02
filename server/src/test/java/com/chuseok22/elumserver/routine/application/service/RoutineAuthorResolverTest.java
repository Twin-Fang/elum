package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository.GuardianName;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;

/**
 * 일과 응답에 만든 사람 정보를 싣는다 (#361·#362).
 *
 * <p>스프링을 띄우지 않는다. 호출자별 createdByMe 판단과, 이름을 목록 한 번에 가져오는지(N+1 없음)만 본다.
 */
class RoutineAuthorResolverTest {

  private final ProfileGuardianRepository guardians = mock(ProfileGuardianRepository.class);
  private final RoutineAuthorResolver resolver = new RoutineAuthorResolver(guardians);

  private final Caller me = Caller.guardian("member-1");
  private final Caller elumi = Caller.elumi("member-1", "link-1");

  private static RoutineResponse routine(String id, String profileId, String createdBy) {
    return new RoutineResponse(id, "제목", "원문", "마스킹본", null, "CONFIRMED", "피드백", null,
      0, 0, 0, null, null, List.of(), null, null, createdBy, null, null, profileId, "ko");
  }

  /// 쿼리 투영 대역. 목으로 만들면 thenReturn 안에서 중첩 스텁이 된다.
  private record Name(String memberId, String displayName) implements GuardianName {

    @Override
    public String getMemberId() {
      return memberId;
    }

    @Override
    public String getDisplayName() {
      return displayName;
    }
  }

  private static GuardianName name(String memberId, String displayName) {
    return new Name(memberId, displayName);
  }

  @Test
  @DisplayName("내가 만든 일과는 createdByMe=true, 남이 만든 일과는 false 와 만든 사람 이름이 실린다")
  void marksMineAndOthers() {
    when(guardians.findNamesByProfileIdAndMemberIdIn(eq("p1"), anyCollection()))
      .thenReturn(List.of(name("member-1", "엄마"), name("member-2", "센터 선생님")));

    List<RoutineResponse> out = resolver.forCaller(me,
      List.of(routine("r1", "p1", "member-1"), routine("r2", "p1", "member-2")));

    assertThat(out.get(0).createdByMe()).isTrue();
    assertThat(out.get(0).creatorName()).isEqualTo("엄마");
    assertThat(out.get(1).createdByMe()).isFalse();
    assertThat(out.get(1).creatorName()).isEqualTo("센터 선생님");
  }

  @Test
  @DisplayName("목록은 이룸이마다 한 번만 이름을 묻는다 — 일과 수만큼 쿼리가 늘지 않는다")
  void listAsksNamesOncePerProfile() {
    when(guardians.findNamesByProfileIdAndMemberIdIn(anyString(), anyCollection())).thenReturn(List.of());

    resolver.forCaller(me, List.of(
      routine("r1", "p1", "member-1"), routine("r2", "p1", "member-2"),
      routine("r3", "p1", "member-2"), routine("r4", "p1", "member-3")));

    verify(guardians, times(1)).findNamesByProfileIdAndMemberIdIn(eq("p1"), anyCollection());
  }

  @Test
  @DisplayName("표시 이름이 없거나 공백이면 creatorName 은 null — 앱이 '보호자'로 부른다")
  void blankNameIsNull() {
    when(guardians.findNamesByProfileIdAndMemberIdIn(eq("p1"), anyCollection()))
      .thenReturn(List.of(name("member-2", "   "), name("member-3", null)));

    List<RoutineResponse> out = resolver.forCaller(me,
      List.of(routine("r2", "p1", "member-2"), routine("r3", "p1", "member-3")));

    assertThat(out).allSatisfy(r -> {
      assertThat(r.createdByMe()).isFalse();
      assertThat(r.creatorName()).isNull();
    });
  }

  @Test
  @DisplayName("만든 사람이 비어 있는 옛 일과: createdByMe 는 null(모름), 이름도 null, 쿼리도 하지 않는다")
  void legacyWithoutCreatorIsUnknown() {
    List<RoutineResponse> out = resolver.forCaller(me, List.of(routine("r1", "p1", null)));

    assertThat(out.get(0).createdByMe()).isNull();
    assertThat(out.get(0).creatorName()).isNull();
    verify(guardians, never()).findNamesByProfileIdAndMemberIdIn(anyString(), any());
  }

  @Test
  @DisplayName("이룸이 휴대폰: createdByMe=false, 보호자 이름은 주지 않고 쿼리도 하지 않는다")
  void elumiGetsNoNames() {
    RoutineResponse out = resolver.forCaller(elumi, routine("r1", "p1", "member-1"));

    assertThat(out.createdByMe()).isFalse();
    assertThat(out.creatorName()).isNull();
    verifyNoInteractions(guardians);
  }

  @Test
  @DisplayName("응답 JSON 에는 계정 ID 도 이룸이 ID 도 실리지 않는다")
  void jsonHasNoAccountIds() throws Exception {
    when(guardians.findNamesByProfileIdAndMemberIdIn(eq("p1"), anyCollection()))
      .thenReturn(List.of(name("member-2", "아빠")));

    RoutineResponse out = resolver.forCaller(me, routine("r1", "p1", "member-2"));
    String json = new ObjectMapper().writeValueAsString(out);

    assertThat(json).contains("\"createdByMe\":false").contains("\"creatorName\":\"아빠\"");
    assertThat(json).doesNotContain("member-2").doesNotContain("createdBy\"").doesNotContain("\"p1\"")
      .doesNotContain("profileId");
  }
}
