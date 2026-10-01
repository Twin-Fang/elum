package com.chuseok22.elumserver.member.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.dto.request.GuardianUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.response.GuardianListResponse;
import com.chuseok22.elumserver.member.application.dto.response.GuardianResponse;
import com.chuseok22.elumserver.member.infrastructure.entity.GuardianKind;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileGuardian;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

/**
 * 함께하는 사람 목록 · 내 이름 고치기 · 나가기 (이슈 #361). 권한 표의 "이 이룸이에서 나가기" 칸마다 허용 하나·거절 하나.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ProfileGuardianServiceTest {

  @Mock private ProfileGuardianRepository profileGuardianRepository;
  @Mock private ProfileAccessGuard profileAccessGuard;
  @Mock private GuardianshipService guardianshipService;

  @InjectMocks private ProfileGuardianService service;

  private ProfileGuardian mine;
  private ProfileGuardian theirs;

  @BeforeEach
  void setUp() {
    Profile profile = new Profile();
    profile.setId("p1");
    mine = guardian("g1", profile, "A", "엄마", GuardianKind.GUARDIAN, LocalDateTime.of(2026, 9, 1, 9, 0));
    theirs = guardian("g2", profile, "B", null, GuardianKind.CAREGIVER, LocalDateTime.of(2026, 9, 2, 9, 0));
    when(profileGuardianRepository.findAllByProfileIdOrderByJoinedAtAsc("p1")).thenReturn(List.of(mine, theirs));
    when(profileGuardianRepository.findByProfileIdAndMemberId("p1", "A")).thenReturn(Optional.of(mine));
  }

  private ProfileGuardian guardian(String id, Profile profile, String memberId, String name, GuardianKind kind,
    LocalDateTime joinedAt) {
    Member member = new Member();
    member.setId(memberId);
    member.setUsername("naver_" + memberId);
    ProfileGuardian g = new ProfileGuardian();
    g.setId(id);
    g.setProfile(profile);
    g.setMember(member);
    g.setDisplayName(name);
    g.setKind(kind);
    g.setJoinedAt(joinedAt);
    return g;
  }

  private static void assertFails(Runnable call, ErrorCode expected) {
    assertThatThrownBy(call::run)
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", expected);
  }

  // ── 목록 ──

  @Test
  @DisplayName("연결된 보호자는 함께하는 사람을 합류 순서대로 보고 나는 me=true 다")
  void list_allowedForGuardian() {
    GuardianListResponse res = service.list(Caller.guardian("A"), "p1");

    assertThat(res.guardians()).extracting(GuardianResponse::id).containsExactly("g1", "g2");
    assertThat(res.guardians()).extracting(GuardianResponse::me).containsExactly(true, false);
    assertThat(res.guardians()).extracting(GuardianResponse::displayName).containsExactly("엄마", null);
    assertThat(res.guardians()).extracting(GuardianResponse::kind)
      .containsExactly(GuardianKind.GUARDIAN, GuardianKind.CAREGIVER);
  }

  @Test
  @DisplayName("목록에는 다른 보호자의 계정 정보(아이디·계정 ID)가 없다")
  void list_exposesNoAccountFields() {
    GuardianResponse other = service.list(Caller.guardian("A"), "p1").guardians().get(1);

    // 응답 모양 자체에 계정 값을 담을 자리가 없다
    assertThat(GuardianResponse.class.getRecordComponents())
      .extracting(c -> c.getName())
      .containsExactly("id", "me", "displayName", "kind", "joinedAt");
    assertThat(other.id()).isEqualTo("g2").isNotEqualTo("B");
  }

  @Test
  @DisplayName("연결되지 않은 보호자는 목록을 볼 수 없다 (403)")
  void list_deniedForNonGuardian() {
    doThrow(new CustomException(ErrorCode.PROFILE_ACCESS_DENIED)).when(profileAccessGuard).requireGuardianOf("X", "p1");

    assertFails(() -> service.list(Caller.guardian("X"), "p1"), ErrorCode.PROFILE_ACCESS_DENIED);
  }

  @Test
  @DisplayName("이룸이 휴대폰은 목록을 볼 수 없다 (403)")
  void list_deniedForElumi() {
    assertFails(() -> service.list(Caller.elumi("A", "link1"), "p1"), ErrorCode.DEVICE_LINK_FORBIDDEN_FOR_ELUMI);
    verifyNoInteractions(profileGuardianRepository);
  }

  // ── 내 이름 고치기 ──

  @Test
  @DisplayName("내 이름과 표시를 고친다 — 보낸 항목만 바뀐다")
  void updateMe_changesOnlySentFields() {
    GuardianResponse res = service.updateMe(Caller.guardian("A"), "p1",
      new GuardianUpdateRequest(GuardianKind.CAREGIVER, null));

    assertThat(res.kind()).isEqualTo(GuardianKind.CAREGIVER);
    assertThat(mine.getDisplayName()).isEqualTo("엄마");
  }

  @Test
  @DisplayName("이름은 앞뒤 공백을 자르고, 빈 문자열이면 이름을 지운다")
  void updateMe_trimsAndClearsName() {
    service.updateMe(Caller.guardian("A"), "p1", new GuardianUpdateRequest(null, "  센터 선생님 "));
    assertThat(mine.getDisplayName()).isEqualTo("센터 선생님");

    service.updateMe(Caller.guardian("A"), "p1", new GuardianUpdateRequest(null, "   "));
    assertThat(mine.getDisplayName()).isNull();
  }

  @Test
  @DisplayName("고치는 대상은 항상 나다 — 남의 관계 행은 조회조차 하지 않는다")
  void updateMe_targetsOnlyMe() {
    service.updateMe(Caller.guardian("A"), "p1", new GuardianUpdateRequest(null, "아빠"));

    verify(profileGuardianRepository).findByProfileIdAndMemberId("p1", "A");
    verify(profileGuardianRepository, never()).findByProfileIdAndMemberId("p1", "B");
    assertThat(theirs.getDisplayName()).isNull();
  }

  @Test
  @DisplayName("보낸 항목이 없으면 400, 이름이 20자를 넘어도 400")
  void updateMe_invalidInput() {
    assertFails(() -> service.updateMe(Caller.guardian("A"), "p1", new GuardianUpdateRequest(null, null)),
      ErrorCode.INVALID_INPUT_VALUE);
    assertFails(() -> service.updateMe(Caller.guardian("A"), "p1", new GuardianUpdateRequest(null, "가".repeat(21))),
      ErrorCode.INVALID_INPUT_VALUE);
    assertFails(() -> service.updateMe(Caller.guardian("A"), "p1", null), ErrorCode.INVALID_INPUT_VALUE);
    assertThat(mine.getDisplayName()).isEqualTo("엄마");
  }

  @Test
  @DisplayName("연결되지 않은 보호자·이룸이 휴대폰은 고칠 수 없다 (403)")
  void updateMe_denied() {
    doThrow(new CustomException(ErrorCode.PROFILE_ACCESS_DENIED)).when(profileAccessGuard).requireGuardianOf("X", "p1");

    assertFails(() -> service.updateMe(Caller.guardian("X"), "p1", new GuardianUpdateRequest(null, "이름")),
      ErrorCode.PROFILE_ACCESS_DENIED);
    assertFails(() -> service.updateMe(Caller.elumi("A", "link1"), "p1", new GuardianUpdateRequest(null, "이름")),
      ErrorCode.DEVICE_LINK_FORBIDDEN_FOR_ELUMI);
  }

  // ── 나가기 ──

  @Test
  @DisplayName("연결된 보호자는 자기만 나간다 — 1단계의 나가기 규칙을 그대로 부른다")
  void leave_allowed_delegatesToLeaveRule() {
    service.leave(Caller.guardian("A"), "p1");

    verify(guardianshipService).leave("A", "p1");
  }

  @Test
  @DisplayName("연결되지 않은 보호자의 나가기는 403 — 아무것도 지우지 않는다")
  void leave_deniedForNonGuardian() {
    doThrow(new CustomException(ErrorCode.PROFILE_ACCESS_DENIED)).when(profileAccessGuard).requireGuardianOf("X", "p1");

    assertFails(() -> service.leave(Caller.guardian("X"), "p1"), ErrorCode.PROFILE_ACCESS_DENIED);
    verify(guardianshipService, never()).leave(anyString(), anyString());
  }

  @Test
  @DisplayName("E7 이룸이 휴대폰은 나갈 수 없다 (403) — 그 휴대폰을 붙여 준 보호자가 쫓겨나선 안 된다")
  void e7_leave_deniedForElumi() {
    assertFails(() -> service.leave(Caller.elumi("A", "link1"), "p1"), ErrorCode.DEVICE_LINK_FORBIDDEN_FOR_ELUMI);
    verify(guardianshipService, never()).leave(anyString(), anyString());
  }
}
