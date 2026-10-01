package com.chuseok22.elumserver.routine.application.dto.response;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** 응답이 만든 사람 판단에 쓰는 값(이룸이 ID)을 품고, 호출자별 createdByMe 를 정한다 (#361·#362). */
class RoutineResponseCreatorTest {

  private static RoutineResponse from(String createdBy) {
    Profile profile = new Profile();
    profile.setId("p1");
    Routine routine = new Routine();
    routine.setId("r1");
    routine.setProfile(profile);
    routine.setCreatedBy(createdBy);
    routine.setTitle("제목");
    routine.setRawInputText("원문");
    routine.setSanitizedInputText("마스킹본");
    routine.setStatus(RoutineStatus.CONFIRMED);
    routine.setSteps(List.of());
    return RoutineResponse.from(routine);
  }

  @Test
  @DisplayName("from 은 이룸이 ID 를 품는다 — 이름을 이룸이 단위로 한 번에 찾으려는 것")
  void fromCarriesProfileId() {
    assertThat(from("member-1").profileId()).isEqualTo("p1");
  }

  @Test
  @DisplayName("forCaller: 내 것 true, 남의 것 false, 이룸이 휴대폰 false")
  void createdByMeByCaller() {
    assertThat(from("member-1").forCaller(Caller.guardian("member-1")).createdByMe()).isTrue();
    assertThat(from("member-2").forCaller(Caller.guardian("member-1")).createdByMe()).isFalse();
    assertThat(from("member-1").forCaller(Caller.elumi("member-1", "link-1")).createdByMe()).isFalse();
  }

  @Test
  @DisplayName("만든 사람이 비어 있는 옛 일과는 모른다(null) — 서버가 수정을 막는 일과를 내 것이라 약속하지 않는다")
  void legacyIsUnknown() {
    assertThat(from(null).forCaller(Caller.guardian("member-1")).createdByMe()).isNull();
  }

  @Test
  @DisplayName("withCredit·withImageSkippedReason·withoutSourceText 는 만든 사람 값을 잃지 않는다")
  void copiesKeepAuthorFields() {
    RoutineResponse base = from("member-2").forCaller(Caller.guardian("member-1"));
    RoutineResponse.CreditUsage usage = new RoutineResponse.CreditUsage(1, 1, 1, 1);

    assertThat(base.withCredit(usage).createdByMe()).isFalse();
    assertThat(base.withImageSkippedReason("X").profileId()).isEqualTo("p1");
    assertThat(base.withoutSourceText().createdByMe()).isFalse();
  }
}
