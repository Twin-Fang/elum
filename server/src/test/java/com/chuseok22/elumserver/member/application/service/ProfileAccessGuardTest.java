package com.chuseok22.elumserver.member.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.link.infrastructure.entity.DeviceLink;
import com.chuseok22.elumserver.link.infrastructure.repository.DeviceLinkRepository;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

/**
 * 권한 표(명세 4-2)의 칸마다 허용 하나·거절 하나 (명세 8장).
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ProfileAccessGuardTest {

  @Mock
  private ProfileRepository profileRepository;

  @Mock
  private ProfileGuardianRepository profileGuardianRepository;

  @Mock
  private DeviceLinkRepository deviceLinkRepository;

  @InjectMocks
  private ProfileAccessGuard guard;

  private static final Caller A = Caller.guardian("A");
  private static final Caller ELUMI = Caller.elumi("A", "l1");

  private Profile profile(String id) {
    Profile profile = new Profile();
    profile.setId(id);
    return profile;
  }

  private void connected(String memberId, String profileId) {
    when(profileGuardianRepository.existsByProfileIdAndMemberId(profileId, memberId)).thenReturn(true);
    when(profileRepository.findById(profileId)).thenReturn(Optional.of(profile(profileId)));
  }

  private void phoneLinkedTo(String profileId) {
    DeviceLink link = new DeviceLink();
    link.setId("l1");
    link.setMemberId("A");
    link.setProfileId(profileId);
    link.setRedeemedAt(LocalDateTime.now().minusDays(1));
    when(deviceLinkRepository.findById("l1")).thenReturn(Optional.of(link));
    when(profileRepository.findById(profileId)).thenReturn(Optional.of(profile(profileId)));
  }

  // ── 이룸이 고르기 ────────────────────────────────────────────

  @Test
  @DisplayName("E36 헤더가 없으면 가장 먼저 합류한 이룸이 — 옛 앱은 지금과 같은 이룸이를 본다")
  void e36_noHeader_usesEarliestJoinedProfile() {
    when(profileRepository.findAllGuardedBy("A")).thenReturn(List.of(profile("p1"), profile("p2")));

    assertThat(guard.profileFor(A, ProfileAction.VIEW).getId()).isEqualTo("p1");
  }

  @Test
  @DisplayName("E29 연결된 이룸이가 0명이면 PROFILE_NOT_FOUND — 앱이 이룸이 등록으로 보낸다")
  void e29_noProfiles_throwsProfileNotFound() {
    when(profileRepository.findAllGuardedBy("A")).thenReturn(List.of());

    assertThatThrownBy(() -> guard.profileFor(A, ProfileAction.VIEW))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.PROFILE_NOT_FOUND);
    assertThat(guard.profilesOf(A)).isEmpty();
  }

  @Test
  @DisplayName("헤더로 연결된 이룸이를 짚으면 그 이룸이")
  void header_connectedProfile_isUsed() {
    connected("A", "p2");

    assertThat(guard.profileFor(Caller.guardian("A", "p2"), ProfileAction.MANAGE).getId()).isEqualTo("p2");
  }

  @Test
  @DisplayName("E27 연결 안 된 이룸이를 헤더로 짚으면 403 — 있는 이룸이인지도 알려 주지 않는다")
  void e27_header_unconnectedProfile_isDenied() {
    assertThatThrownBy(() -> guard.profileFor(Caller.guardian("A", "p9"), ProfileAction.VIEW))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.PROFILE_ACCESS_DENIED);
    verify(profileRepository, never()).findById(any());
  }

  @Test
  @DisplayName("E39 이룸이 폰은 보호자의 첫 이룸이가 아니라 연결의 이룸이를 본다")
  void e39_elumiPhone_seesLinkedProfileNotGuardiansFirst() {
    when(profileRepository.findAllGuardedBy("A")).thenReturn(List.of(profile("p1"), profile("p2")));
    phoneLinkedTo("p2");

    assertThat(guard.profileFor(ELUMI, ProfileAction.VIEW).getId()).isEqualTo("p2");
    assertThat(guard.profilesOf(ELUMI)).extracting(Profile::getId).containsExactly("p2");
  }

  @Test
  @DisplayName("E28 이룸이 폰이 다른 이룸이를 헤더로 짚으면 403")
  void e28_elumiPhone_otherProfileHeader_isDenied() {
    phoneLinkedTo("p2");

    assertThatThrownBy(() -> guard.profileFor(Caller.elumi("A", "l1", "p1"), ProfileAction.VIEW))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.PROFILE_ACCESS_DENIED);
  }

  @Test
  @DisplayName("이룸이 폰은 이룸이 정보 수정·일과 만들기·순서·연결 암호를 할 수 없다")
  void elumiPhone_manage_isForbidden() {
    phoneLinkedTo("p2");

    assertThatThrownBy(() -> guard.profileFor(ELUMI, ProfileAction.MANAGE))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.DEVICE_LINK_FORBIDDEN_FOR_ELUMI);
  }

  @Test
  @DisplayName("이룸이가 정해지지 않은 연결(profile_id 없음)은 이룸이를 지어내지 않고 PROFILE_NOT_FOUND")
  void elumiPhone_linkWithoutProfile_isNotFound() {
    phoneLinkedTo(null);

    assertThatThrownBy(() -> guard.profileFor(ELUMI, ProfileAction.VIEW))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.PROFILE_NOT_FOUND);
  }

  // ── 일과 하나 ────────────────────────────────────────────────

  @ParameterizedTest
  @EnumSource(value = RoutineAction.class, names = {"VIEW", "PROGRESS", "COPY"})
  @DisplayName("연결된 보호자는 남이 만든 일과도 보고 진행하고 복제한다")
  void connectedGuardian_othersRoutine_viewProgressCopyAllowed(RoutineAction action) {
    when(profileGuardianRepository.existsByProfileIdAndMemberId("p1", "A")).thenReturn(true);

    assertThatCode(() -> guard.checkRoutine(A, "p1", "B", action)).doesNotThrowAnyException();
  }

  @Test
  @DisplayName("E30 남이 만든 일과의 승인·수정·삭제·보상은 403 ROUTINE_NOT_CREATOR")
  void e30_connectedGuardian_othersRoutine_editDenied() {
    when(profileGuardianRepository.existsByProfileIdAndMemberId("p1", "A")).thenReturn(true);

    assertThatThrownBy(() -> guard.checkRoutine(A, "p1", "B", RoutineAction.EDIT))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_NOT_CREATOR);
  }

  @Test
  @DisplayName("내가 만든 일과는 고칠 수 있다")
  void connectedGuardian_ownRoutine_editAllowed() {
    when(profileGuardianRepository.existsByProfileIdAndMemberId("p1", "A")).thenReturn(true);

    assertThatCode(() -> guard.checkRoutine(A, "p1", "A", RoutineAction.EDIT)).doesNotThrowAnyException();
  }

  @Test
  @DisplayName("만든 사람이 비어 있는 일과(옛 서버가 만든 것, 채우기 전)는 아무도 고치지 못한다")
  void routineWithoutCreator_editDenied() {
    when(profileGuardianRepository.existsByProfileIdAndMemberId("p1", "A")).thenReturn(true);

    assertThatThrownBy(() -> guard.checkRoutine(A, "p1", null, RoutineAction.EDIT))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_NOT_CREATOR);
  }

  @ParameterizedTest
  @EnumSource(RoutineAction.class)
  @DisplayName("연결 안 된 보호자는 어떤 일과 동작도 403 ROUTINE_ACCESS_DENIED")
  void unconnectedGuardian_anyAction_denied(RoutineAction action) {
    assertThatThrownBy(() -> guard.checkRoutine(A, "p1", "A", action))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_ACCESS_DENIED);
  }

  @ParameterizedTest
  @EnumSource(value = RoutineAction.class, names = {"VIEW", "PROGRESS"})
  @DisplayName("이룸이 폰은 연결된 이룸이의 일과를 보고 체크한다 — 누가 만들었든")
  void elumiPhone_linkedProfile_viewAndProgressAllowed(RoutineAction action) {
    phoneLinkedTo("p1");

    assertThatCode(() -> guard.checkRoutine(ELUMI, "p1", "B", action)).doesNotThrowAnyException();
  }

  @Test
  @DisplayName("이룸이 폰은 다른 이룸이의 일과를 보지 못한다")
  void elumiPhone_otherProfile_denied() {
    phoneLinkedTo("p1");

    assertThatThrownBy(() -> guard.checkRoutine(ELUMI, "p2", "A", RoutineAction.VIEW))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_ACCESS_DENIED);
  }

  @ParameterizedTest
  @EnumSource(value = RoutineAction.class, names = {"COPY", "EDIT"})
  @DisplayName("이룸이 폰은 일과를 고치거나 복제할 수 없다")
  void elumiPhone_editOrCopy_forbidden(RoutineAction action) {
    phoneLinkedTo("p1");

    assertThatThrownBy(() -> guard.checkRoutine(ELUMI, "p1", "A", action))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.DEVICE_LINK_FORBIDDEN_FOR_ELUMI);
  }

  @Test
  @DisplayName("관계가 없으면 requireGuardianOf 가 403")
  void requireGuardianOf_notConnected_denied() {
    assertThatThrownBy(() -> guard.requireGuardianOf("A", "p1"))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.PROFILE_ACCESS_DENIED);
  }
}
