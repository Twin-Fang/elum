package com.chuseok22.elumserver.member.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.auth.infrastructure.entity.RevokeReason;
import com.chuseok22.elumserver.auth.infrastructure.repository.RefreshTokenRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.link.core.ElumiDeviceId;
import com.chuseok22.elumserver.link.infrastructure.entity.DeviceLink;
import com.chuseok22.elumserver.link.infrastructure.repository.DeviceLinkRepository;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.GuardianKind;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileGuardian;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileInvite;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileInviteRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.lang.reflect.Method;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InOrder;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.transaction.annotation.Transactional;

// 나가기 장면마다 같은 준비물을 쓰므로 안 쓰는 스텁을 허용한다 (DeviceLinkServiceTest 와 같은 설정).
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class GuardianshipServiceTest {

  @Mock
  private ProfileRepository profileRepository;

  @Mock
  private ProfileGuardianRepository profileGuardianRepository;

  @Mock
  private RoutineRepository routineRepository;

  @Mock
  private DeviceLinkRepository deviceLinkRepository;

  @Mock
  private RefreshTokenRepository refreshTokenRepository;

  @Mock
  private ProfileInviteRepository profileInviteRepository;

  @InjectMocks
  private GuardianshipService guardianshipService;

  private Member member(String id) {
    Member member = new Member();
    member.setId(id);
    member.setUsername("user-" + id);
    return member;
  }

  private Profile profile(String id, Member representative, int stars) {
    Profile profile = new Profile();
    profile.setId(id);
    profile.setMember(representative);
    profile.setTotalStars(stars);
    return profile;
  }

  private ProfileGuardian guardian(Profile profile, Member member, LocalDateTime joinedAt) {
    ProfileGuardian guardian = new ProfileGuardian();
    guardian.setId("g-" + profile.getId() + "-" + member.getId());
    guardian.setProfile(profile);
    guardian.setMember(member);
    guardian.setJoinedAt(joinedAt);
    return guardian;
  }

  private Routine routine(String id, Profile profile, String createdBy, RoutineStatus status) {
    Routine routine = new Routine();
    routine.setId(id);
    routine.setProfile(profile);
    routine.setCreatedBy(createdBy);
    routine.setStatus(status);
    return routine;
  }

  private DeviceLink linkedPhone(String id, String memberId, String profileId) {
    DeviceLink link = new DeviceLink();
    link.setId(id);
    link.setMemberId(memberId);
    link.setProfileId(profileId);
    link.setRedeemedAt(LocalDateTime.now().minusDays(1));
    link.setLinkedDeviceId(ElumiDeviceId.of(id));
    return link;
  }

  /** 이룸이 p1 을 A 와 B 가 함께 돌보고, 이제 A 가 나간다. A 가 먼저 합류했다(대표). */
  private Profile sharedProfileWhereALeaves(List<Routine> routinesByA, List<DeviceLink> phonesByA) {
    Member a = member("A");
    Member b = member("B");
    Profile p1 = profile("p1", a, 7);
    ProfileGuardian mine = guardian(p1, a, LocalDateTime.of(2026, 1, 1, 9, 0));
    ProfileGuardian theirs = guardian(p1, b, LocalDateTime.of(2026, 2, 1, 9, 0));
    when(profileRepository.findByIdForUpdate("p1")).thenReturn(Optional.of(p1));
    when(profileGuardianRepository.findByProfileIdAndMemberId("p1", "A")).thenReturn(Optional.of(mine));
    when(routineRepository.findAllByProfileIdAndCreatedBy("p1", "A")).thenReturn(routinesByA);
    when(deviceLinkRepository.findAllByMemberIdAndProfileId("A", "p1")).thenReturn(phonesByA);
    // 지운 뒤 다시 세면 B 만 남는다 (auto flush). A 가 섞여 와도 걸러야 한다.
    when(profileGuardianRepository.findAllByProfileIdOrderByJoinedAtAsc("p1")).thenReturn(List.of(theirs));
    return p1;
  }

  @Test
  @DisplayName("가입하면 빈 이룸이와 관계 한 줄이 함께 생기고 대표 보호자도 채운다 — V23 전까지 옛 서버가 읽는다")
  void createOwnProfile_createsProfileAndRelation() {
    Member member = member("A");

    Profile created = guardianshipService.createOwnProfile(member);

    assertThat(created.getMember()).isSameAs(member);
    assertThat(created.getCharacter()).isEqualTo(CharacterType.LULU);
    verify(profileRepository).save(created);
    verify(profileGuardianRepository).save(argThat(guardian ->
      guardian.getProfile() == created
        && guardian.getMember() == member
        && guardian.getKind() == GuardianKind.GUARDIAN
        && guardian.getJoinedAt() != null));
  }

  @Test
  @DisplayName("E12 함께 돌보는 이룸이에서 나가면 내가 만든 일과만 — 임시저장까지 — 지우고 이룸이는 남는다")
  void e12_leave_sharedProfile_removesOnlyMyRoutinesIncludingDrafts() {
    Routine mineConfirmed = routine("r1", null, "A", RoutineStatus.CONFIRMED);
    Routine mineDraft = routine("r2", null, "A", RoutineStatus.PENDING_REVIEW);
    Profile p1 = sharedProfileWhereALeaves(List.of(mineConfirmed, mineDraft), List.of());

    guardianshipService.leave("A", "p1");

    verify(routineRepository).deleteAll(List.of(mineConfirmed, mineDraft));
    verify(routineRepository, never()).findAllByProfileId("p1");
    verify(profileRepository, never()).delete(p1);
  }

  @Test
  @DisplayName("E13 내가 붙인 이 이룸이의 휴대폰은 연결을 끊고 그 기기 세션을 폐기한다")
  void e13_leave_revokesMyPhoneLinksAndTheirSessions() {
    DeviceLink myPhone = linkedPhone("l1", "A", "p1");
    sharedProfileWhereALeaves(List.of(), List.of(myPhone));

    guardianshipService.leave("A", "p1");

    assertThat(myPhone.getRevokedAt()).isNotNull();
    verify(refreshTokenRepository).revokeByMemberIdAndDeviceId(
      eq("A"), eq("elumi-l1"), any(LocalDateTime.class), eq(RevokeReason.DEVICE_UNLINKED));
    // 연결 이력은 남긴다 — 끊긴 기록도 보여줘야 한다 (DeviceLink 설계)
    verify(deviceLinkRepository, never()).deleteAll(any());
  }

  @Test
  @DisplayName("E14 대표 보호자가 나가면 남은 사람 중 가장 먼저 합류한 사람으로 바꾼다 — 안 바꾸면 탈퇴가 외래키에 걸린다")
  void e14_leave_representativeLeaves_handsOverToEarliestRemaining() {
    Member a = member("A");
    Member b = member("B");
    Member c = member("C");
    Profile p1 = profile("p1", a, 0);
    when(profileRepository.findByIdForUpdate("p1")).thenReturn(Optional.of(p1));
    when(profileGuardianRepository.findByProfileIdAndMemberId("p1", "A"))
      .thenReturn(Optional.of(guardian(p1, a, LocalDateTime.of(2026, 1, 1, 9, 0))));
    when(profileGuardianRepository.findAllByProfileIdOrderByJoinedAtAsc("p1")).thenReturn(List.of(
      guardian(p1, b, LocalDateTime.of(2026, 2, 1, 9, 0)),
      guardian(p1, c, LocalDateTime.of(2026, 3, 1, 9, 0))));

    guardianshipService.leave("A", "p1");

    assertThat(p1.getMember()).isSameAs(b);
  }

  @Test
  @DisplayName("E15 나가기는 이룸이 행을 잠근 뒤에 남은 보호자를 센다 — 마지막 두 사람이 동시에 나가도 보호자 0명인 이룸이가 남지 않는다")
  void e15_leave_locksProfileBeforeCountingRemaining() {
    sharedProfileWhereALeaves(List.of(), List.of());

    guardianshipService.leave("A", "p1");

    InOrder order = inOrder(profileRepository, profileGuardianRepository);
    order.verify(profileRepository).findByIdForUpdate("p1");
    order.verify(profileGuardianRepository).findAllByProfileIdOrderByJoinedAtAsc("p1");
  }

  @Test
  @DisplayName("마지막 보호자가 나가면 이룸이와 남은 일과·휴대폰 연결·세션까지 지운다")
  void leave_lastGuardian_removesProfileAndEverythingOnIt() {
    Member a = member("A");
    Profile p1 = profile("p1", a, 3);
    when(profileRepository.findByIdForUpdate("p1")).thenReturn(Optional.of(p1));
    when(profileGuardianRepository.findByProfileIdAndMemberId("p1", "A"))
      .thenReturn(Optional.of(guardian(p1, a, LocalDateTime.now())));
    when(profileGuardianRepository.findAllByProfileIdOrderByJoinedAtAsc("p1")).thenReturn(List.of());
    // 옛 서버로 되돌린 동안 만든 일과는 created_by 가 비어 있다 — 그것까지 지워야 프로필을 지울 수 있다
    Routine orphan = routine("r9", p1, null, RoutineStatus.CONFIRMED);
    when(routineRepository.findAllByProfileId("p1")).thenReturn(List.of(orphan));
    DeviceLink phone = linkedPhone("l9", "A", "p1");
    when(deviceLinkRepository.findAllByProfileId("p1")).thenReturn(List.of(phone));

    guardianshipService.leave("A", "p1");

    verify(routineRepository).deleteAll(List.of(orphan));
    verify(refreshTokenRepository).revokeByMemberIdAndDeviceId(
      eq("A"), eq("elumi-l9"), any(LocalDateTime.class), eq(RevokeReason.DEVICE_UNLINKED));
    verify(deviceLinkRepository).deleteAll(List.of(phone));
    verify(profileRepository).delete(p1);
  }

  @Test
  @DisplayName("E22 나가도 별은 그대로다 — 이룸이가 해낸 것이다")
  void e22_leave_keepsStars() {
    Profile p1 = sharedProfileWhereALeaves(List.of(routine("r1", null, "A", RoutineStatus.COMPLETED)), List.of());

    guardianshipService.leave("A", "p1");

    assertThat(p1.getTotalStars()).isEqualTo(7);
    verify(profileRepository, never()).addStars(anyString(), anyInt());
  }

  @Test
  @DisplayName("연결되지 않은 이룸이에서는 나갈 수 없다 — 아무것도 지우지 않는다")
  void leave_notGuardian_throwsProfileAccessDenied() {
    when(profileRepository.findByIdForUpdate("p1")).thenReturn(Optional.of(profile("p1", member("B"), 0)));
    when(profileGuardianRepository.findByProfileIdAndMemberId("p1", "A")).thenReturn(Optional.empty());

    assertThatThrownBy(() -> guardianshipService.leave("A", "p1"))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.PROFILE_ACCESS_DENIED);
    verify(routineRepository, never()).deleteAll(any());
    verify(profileGuardianRepository, never()).delete(any());
  }

  @Test
  @DisplayName("이미 지워진 이룸이에서 나가려 하면 PROFILE_NOT_FOUND")
  void leave_profileGone_throwsProfileNotFound() {
    when(profileRepository.findByIdForUpdate("p1")).thenReturn(Optional.empty());

    assertThatThrownBy(() -> guardianshipService.leave("A", "p1"))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.PROFILE_NOT_FOUND);
  }

  @Test
  @DisplayName("E19 탈퇴: 혼자인 이룸이는 지우고 함께 돌보는 이룸이는 남은 보호자에게 남긴다")
  void e19_leaveAll_soloProfileRemoved_sharedProfileKept() {
    Member a = member("A");
    Member b = member("B");
    Profile solo = profile("p1", a, 0);
    Profile shared = profile("p2", a, 0);
    when(profileGuardianRepository.findProfileIdsByMemberId("A")).thenReturn(List.of("p1", "p2"));
    when(profileRepository.findByIdForUpdate("p1")).thenReturn(Optional.of(solo));
    when(profileRepository.findByIdForUpdate("p2")).thenReturn(Optional.of(shared));
    when(profileGuardianRepository.findByProfileIdAndMemberId("p1", "A"))
      .thenReturn(Optional.of(guardian(solo, a, LocalDateTime.now())));
    when(profileGuardianRepository.findByProfileIdAndMemberId("p2", "A"))
      .thenReturn(Optional.of(guardian(shared, a, LocalDateTime.now())));
    when(profileGuardianRepository.findAllByProfileIdOrderByJoinedAtAsc("p1")).thenReturn(List.of());
    when(profileGuardianRepository.findAllByProfileIdOrderByJoinedAtAsc("p2"))
      .thenReturn(List.of(guardian(shared, b, LocalDateTime.now())));

    guardianshipService.leaveAll("A");

    verify(profileRepository).delete(solo);
    verify(profileRepository, never()).delete(shared);
    assertThat(shared.getMember()).isSameAs(b);
  }

  @Test
  @DisplayName("탈퇴는 이룸이 id 순서로 잠근다 — 두 사람이 다른 순서로 같은 두 이룸이를 잠그면 DB 가 한쪽을 죽인다")
  void leaveAll_locksProfilesInIdOrder() {
    when(profileGuardianRepository.findProfileIdsByMemberId("A")).thenReturn(List.of("p2", "p1"));
    when(profileRepository.findByIdForUpdate(any())).thenReturn(Optional.empty());

    guardianshipService.leaveAll("A");

    InOrder order = inOrder(profileRepository);
    order.verify(profileRepository).findByIdForUpdate("p1");
    order.verify(profileRepository).findByIdForUpdate("p2");
  }

  @Test
  @DisplayName("관계 밖에 남은 내 일과도 지운다 — created_by 외래키가 계정 삭제를 막는다")
  void leaveAll_removesStrayRoutinesCreatedByMe() {
    when(profileGuardianRepository.findProfileIdsByMemberId("A")).thenReturn(List.of());
    Routine stray = routine("r7", null, "A", RoutineStatus.CONFIRMED);
    when(routineRepository.findAllByCreatedBy("A")).thenReturn(List.of(stray));

    guardianshipService.leaveAll("A");

    verify(routineRepository).deleteAll(List.of(stray));
  }

  @Test
  @DisplayName("E20 나가기·탈퇴 정리는 한 트랜잭션이다 — 중간에 실패하면 전부 되돌아간다")
  void e20_leaveAndLeaveAll_runInOneWriteTransaction() throws NoSuchMethodException {
    for (Method method : List.of(
      GuardianshipService.class.getMethod("leave", String.class, String.class),
      GuardianshipService.class.getMethod("leaveAll", String.class),
      MemberService.class.getMethod("withdraw", String.class))) {
      Transactional tx = method.getAnnotation(Transactional.class);
      assertThat(tx).as(method.getName()).isNotNull();
      assertThat(tx.readOnly()).as(method.getName()).isFalse();
    }
  }

  // --- 초대 코드 (#361) ---

  private ProfileInvite openInvite(String id, String profileId, String issuedBy) {
    ProfileInvite invite = new ProfileInvite();
    invite.setId(id);
    invite.setProfileId(profileId);
    invite.setIssuedBy(issuedBy);
    invite.setExpiresAt(LocalDateTime.now().plusMinutes(5));
    return invite;
  }

  @Test
  @DisplayName("E4 나가면 내가 이 이룸이에 낸 미사용 초대 코드는 폐기된다 — 나간 사람의 이름으로 사람이 들어오지 못한다")
  void e4_leave_revokesMyOpenInvites() {
    sharedProfileWhereALeaves(List.of(), List.of());
    ProfileInvite mine = openInvite("i1", "p1", "A");
    when(profileInviteRepository.findAllByProfileIdAndIssuedByAndRedeemedAtIsNullAndRevokedAtIsNull("p1", "A"))
      .thenReturn(List.of(mine));

    guardianshipService.leave("A", "p1");

    assertThat(mine.getRevokedAt()).isNotNull();
    // 다른 사람이 낸 코드는 조회조차 하지 않는다 — 내 것만 폐기한다
    verify(profileInviteRepository, never()).findAllByProfileIdAndIssuedByAndRedeemedAtIsNullAndRevokedAtIsNull(
      eq("p1"), eq("B"));
  }

  @Test
  @DisplayName("E4 탈퇴(leaveAll)도 같은 규칙으로 내 초대 코드를 폐기한다")
  void e4_leaveAll_revokesMyOpenInvites() {
    sharedProfileWhereALeaves(List.of(), List.of());
    when(profileGuardianRepository.findProfileIdsByMemberId("A")).thenReturn(List.of("p1"));
    ProfileInvite mine = openInvite("i1", "p1", "A");
    when(profileInviteRepository.findAllByProfileIdAndIssuedByAndRedeemedAtIsNullAndRevokedAtIsNull("p1", "A"))
      .thenReturn(List.of(mine));

    guardianshipService.leaveAll("A");

    assertThat(mine.getRevokedAt()).isNotNull();
  }

  /** 가입 때 생긴 빈 이룸이: 나 혼자, 이름·목표·일과·휴대폰 없음. */
  private Profile emptyOwnProfile(String id, Member me) {
    Profile profile = profile(id, me, 0);
    when(profileRepository.findByIdForUpdate(id)).thenReturn(Optional.of(profile));
    ProfileGuardian mine = guardian(profile, me, LocalDateTime.of(2026, 1, 1, 9, 0));
    when(profileGuardianRepository.findByProfileIdAndMemberId(id, me.getId())).thenReturn(Optional.of(mine));
    // 지우기 전에는 나 혼자, 지운 뒤(auto flush)에는 아무도 없다
    when(profileGuardianRepository.findAllByProfileIdOrderByJoinedAtAsc(id))
      .thenReturn(List.of(mine))
      .thenReturn(List.of());
    return profile;
  }

  @Test
  @DisplayName("E6 합류한 사람의 빈 이룸이는 지운다 — 혼자 돌보고 이름·목표·일과·휴대폰이 모두 없는 것")
  void e6_removeEmptyOwnProfiles_removesUntouchedProfile() {
    Member joiner = member("J");
    Profile empty = emptyOwnProfile("empty", joiner);
    when(profileGuardianRepository.findProfileIdsByMemberId("J")).thenReturn(List.of("empty", "joined"));

    List<String> removed = guardianshipService.removeEmptyOwnProfiles("J", "joined");

    assertThat(removed).containsExactly("empty");
    verify(profileRepository).delete(empty);
    // 방금 합류한 이룸이는 건드리지 않는다
    verify(profileRepository, never()).findByIdForUpdate("joined");
  }

  @Test
  @DisplayName("E6 이름을 적은 이룸이는 남긴다 — 사용자가 손댄 이룸이다")
  void e6_removeEmptyOwnProfiles_keepsNamedProfile() {
    Member joiner = member("J");
    Profile named = emptyOwnProfile("named", joiner);
    named.setNickname("하늘이");
    when(profileGuardianRepository.findProfileIdsByMemberId("J")).thenReturn(List.of("named"));

    assertThat(guardianshipService.removeEmptyOwnProfiles("J", "joined")).isEmpty();
    verify(profileRepository, never()).delete(any(Profile.class));
  }

  @Test
  @DisplayName("E6 일과가 있는 이룸이는 남긴다")
  void e6_removeEmptyOwnProfiles_keepsProfileWithRoutines() {
    Member joiner = member("J");
    emptyOwnProfile("busy", joiner);
    when(routineRepository.existsByProfileId("busy")).thenReturn(true);
    when(profileGuardianRepository.findProfileIdsByMemberId("J")).thenReturn(List.of("busy"));

    assertThat(guardianshipService.removeEmptyOwnProfiles("J", "joined")).isEmpty();
    verify(profileRepository, never()).delete(any(Profile.class));
  }

  @Test
  @DisplayName("E6 이룸이 휴대폰이 연결된 이룸이는 남긴다")
  void e6_removeEmptyOwnProfiles_keepsProfileWithLinkedPhone() {
    Member joiner = member("J");
    emptyOwnProfile("phone", joiner);
    when(deviceLinkRepository.findAllByProfileId("phone")).thenReturn(List.of(linkedPhone("l1", "J", "phone")));
    when(profileGuardianRepository.findProfileIdsByMemberId("J")).thenReturn(List.of("phone"));

    assertThat(guardianshipService.removeEmptyOwnProfiles("J", "joined")).isEmpty();
    verify(profileRepository, never()).delete(any(Profile.class));
  }

  @Test
  @DisplayName("E6 다른 보호자와 함께 돌보는 이룸이는 비어 보여도 남긴다")
  void e6_removeEmptyOwnProfiles_keepsSharedProfile() {
    Member joiner = member("J");
    Profile shared = profile("shared", joiner, 0);
    when(profileRepository.findByIdForUpdate("shared")).thenReturn(Optional.of(shared));
    when(profileGuardianRepository.findAllByProfileIdOrderByJoinedAtAsc("shared")).thenReturn(List.of(
      guardian(shared, joiner, LocalDateTime.of(2026, 1, 1, 9, 0)),
      guardian(shared, member("B"), LocalDateTime.of(2026, 2, 1, 9, 0))));
    when(profileGuardianRepository.findProfileIdsByMemberId("J")).thenReturn(List.of("shared"));

    assertThat(guardianshipService.removeEmptyOwnProfiles("J", "joined")).isEmpty();
    verify(profileRepository, never()).delete(any(Profile.class));
  }
}
