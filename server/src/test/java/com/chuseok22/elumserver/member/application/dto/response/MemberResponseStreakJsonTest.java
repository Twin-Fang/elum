package com.chuseok22.elumserver.member.application.dto.response;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.core.ElumiStreak;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;

/// GET /api/member/me 의 연속 기록 필드 이름이 바뀌면 보호자·이룸이 홈 불꽃이 사라진다 (#1409 앱 계약)
class MemberResponseStreakJsonTest {

  @Test
  @DisplayName("연속 기록은 currentStreakDays·isStreakAtRiskToday 이름으로 실린다")
  void streakFields_haveContractNames() throws Exception {
    MemberResponse response = MemberResponse.from(member(), profile(), List.of(profile()), null, null, null, null,
      new ElumiStreak(3, true));

    String json = new ObjectMapper().writeValueAsString(response);

    assertThat(json).contains("\"currentStreakDays\":3").contains("\"isStreakAtRiskToday\":true");
  }

  @Test
  @DisplayName("기록을 못 구했으면(null) 0·false 로 실려 홈이 null 을 만나지 않는다")
  void missingStreak_isZeroAndFalse() throws Exception {
    MemberResponse response = MemberResponse.from(member(), null, List.of(), null, null, null, null, null);

    String json = new ObjectMapper().writeValueAsString(response);

    assertThat(json).contains("\"currentStreakDays\":0").contains("\"isStreakAtRiskToday\":false");
  }

  private static Member member() {
    Member member = new Member();
    member.setId("member-1");
    member.setUsername("guardian01");
    return member;
  }

  private static Profile profile() {
    Profile profile = new Profile();
    profile.setId("profile-1");
    profile.setNickname("하늘");
    return profile;
  }
}
