package com.chuseok22.elumserver.link.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.auth.application.dto.response.TokenResponse;
import com.chuseok22.elumserver.auth.application.service.RefreshTokenService;
import com.chuseok22.elumserver.auth.infrastructure.entity.RevokeReason;
import com.chuseok22.elumserver.auth.infrastructure.repository.RefreshTokenRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.common.infrastructure.properties.JwtProperties;
import com.chuseok22.elumserver.link.application.dto.response.LinkCodeResponse;
import com.chuseok22.elumserver.link.application.dto.response.LinkStatusResponse;
import com.chuseok22.elumserver.link.core.LinkCode;
import com.chuseok22.elumserver.link.core.LinkRole;
import com.chuseok22.elumserver.link.infrastructure.entity.DeviceLink;
import com.chuseok22.elumserver.link.infrastructure.repository.DeviceLinkRepository;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.LocalDateTime;
import java.util.HexFormat;
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
 * 이룸이 휴대폰 연결 (이슈 #200).
 *
 * <p>연결 암호는 계정에 붙는 자격증명이다. **실패 경로를 정상 경로만큼 고정한다** —
 * 만료·재사용·시도 초과가 조용히 통하면 남의 가정 당사자의 일과가 그대로 보인다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class DeviceLinkServiceTest {

  private static final Caller GUARDIAN = Caller.guardian("m1");

  @Mock private DeviceLinkRepository deviceLinkRepository;
  @Mock private MemberRepository memberRepository;
  @Mock private ProfileAccessGuard profileAccessGuard;
  @Mock private RefreshTokenRepository refreshTokenRepository;
  @Mock private RefreshTokenService refreshTokenService;
  @Mock private JwtProvider jwtProvider;
  @Mock private JwtProperties jwtProperties;

  @InjectMocks private DeviceLinkService service;

  private Member member;

  @BeforeEach
  void setUp() {
    member = new Member();
    member.setId("m1");
    member.setUsername("google_1");
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member));
    Profile profile = new Profile();
    profile.setId("p1");
    when(profileAccessGuard.profileFor(GUARDIAN, ProfileAction.MANAGE)).thenReturn(profile);
    when(deviceLinkRepository.findByMemberIdAndRevokedAtIsNullOrderByCreatedAtDesc("m1"))
      .thenReturn(List.of());
    when(jwtProperties.accessExpMillis()).thenReturn(86_400_000L);
    when(jwtProvider.createAccessToken(anyString(), anyString(), any(), anyString())).thenReturn("elumi-access");
    when(refreshTokenService.issue(anyString(), anyString())).thenReturn("elumi-refresh");
  }

  private static String hash(String raw) throws Exception {
    return HexFormat.of().formatHex(
      MessageDigest.getInstance("SHA-256").digest(raw.getBytes(StandardCharsets.UTF_8)));
  }

  private DeviceLink link(String code, LocalDateTime expiresAt) throws Exception {
    DeviceLink l = new DeviceLink();
    l.setId("l1");
    l.setMemberId("m1");
    l.setCodeHash(hash(code));
    l.setExpiresAt(expiresAt);
    return l;
  }

  @Test
  @DisplayName("발급하면 우리가 만들 수 있는 모양의 암호와 10분 만료가 나온다")
  void issue() {
    LinkCodeResponse res = service.issue(GUARDIAN);

    assertThat(LinkCode.hasValidShape(res.code())).isTrue();
    assertThat(res.expiresInSeconds()).isEqualTo(600);
    assertThat(res.expiresAt()).isAfter(LocalDateTime.now().plusMinutes(9));
    verify(deviceLinkRepository).save(any(DeviceLink.class));
  }

  @Test
  @DisplayName("다시 만들면 이전 미사용 암호는 폐기된다 — 화면에 보이는 것만 통해야 한다")
  void issue_revokesPreviousUnusedCode() throws Exception {
    DeviceLink old = link("A7K3M9", LocalDateTime.now().plusMinutes(5));
    when(deviceLinkRepository.findByMemberIdAndRevokedAtIsNullOrderByCreatedAtDesc("m1"))
      .thenReturn(List.of(old));

    service.issue(GUARDIAN);

    assertThat(old.getRevokedAt()).isNotNull();
  }

  @Test
  @DisplayName("이미 연결된 것은 새 암호를 만들어도 끊기지 않는다 — 발급과 끊기는 다른 일이다")
  void issue_keepsLinked() throws Exception {
    DeviceLink linked = link("A7K3M9", LocalDateTime.now().minusMinutes(1));
    linked.setRedeemedAt(LocalDateTime.now().minusMinutes(1));
    when(deviceLinkRepository.findByMemberIdAndRevokedAtIsNullOrderByCreatedAtDesc("m1"))
      .thenReturn(List.of(linked));

    service.issue(GUARDIAN);

    assertThat(linked.getRevokedAt()).isNull();
  }

  @Test
  @DisplayName("소문자로 넣어도 연결된다")
  void redeem_lowercase() throws Exception {
    DeviceLink l = link("A7K3M9", LocalDateTime.now().plusMinutes(5));
    when(deviceLinkRepository.findByCodeHash(hash("A7K3M9"))).thenReturn(Optional.of(l));

    TokenResponse res = service.redeem("a7k3m9");

    assertThat(res.accessToken()).isEqualTo("elumi-access");
    assertThat(l.getRedeemedAt()).isNotNull();
    // 기기 값은 서버가 만든다 — 클라가 안 보내면 끊을 대상이 없어진다.
    assertThat(l.getLinkedDeviceId()).isEqualTo("elumi-l1");
    // 보호자가 아니라 이룸이 역할로 발급돼야 한다.
    // 토큰에 어느 연결인지가 들어가야 끊었을 때 즉시 막을 수 있다.
    verify(jwtProvider).createAccessToken("m1", "google_1", LinkRole.ELUMI, "l1");
    // 리프레시 토큰도 같은 기기 값으로 남아야 끊을 때 짚힌다.
    verify(refreshTokenService).issue("m1", "elumi-l1");
  }

  @Test
  @DisplayName("만료된 암호는 통하지 않는다")
  void redeem_expired() throws Exception {
    DeviceLink l = link("A7K3M9", LocalDateTime.now().minusSeconds(1));
    when(deviceLinkRepository.findByCodeHash(hash("A7K3M9"))).thenReturn(Optional.of(l));

    assertThatThrownBy(() -> service.redeem("A7K3M9"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.DEVICE_LINK_EXPIRED));
  }

  @Test
  @DisplayName("한 번 쓴 암호는 다시 통하지 않는다 — 두 기기가 같은 암호로 붙지 못한다")
  void redeem_alreadyUsed() throws Exception {
    DeviceLink l = link("A7K3M9", LocalDateTime.now().plusMinutes(5));
    l.setRedeemedAt(LocalDateTime.now().minusMinutes(1));
    when(deviceLinkRepository.findByCodeHash(hash("A7K3M9"))).thenReturn(Optional.of(l));

    assertThatThrownBy(() -> service.redeem("A7K3M9"))
      .isInstanceOf(CustomException.class)
      // 이미 썼다는 사실을 알려주지 않는다 — 존재 여부가 새면 추측의 단서가 된다.
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.DEVICE_LINK_NOT_FOUND));
  }

  @Test
  @DisplayName("5회 틀리면 그 암호는 폐기돼 맞는 값도 통하지 않는다")
  void redeem_tooManyAttempts() throws Exception {
    DeviceLink l = link("A7K3M9", LocalDateTime.now().plusMinutes(5));
    l.setFailedAttempts(DeviceLinkService.MAX_FAILED_ATTEMPTS);
    when(deviceLinkRepository.findByCodeHash(hash("A7K3M9"))).thenReturn(Optional.of(l));

    assertThatThrownBy(() -> service.redeem("A7K3M9"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.DEVICE_LINK_TOO_MANY_ATTEMPTS));
  }

  @Test
  @DisplayName("모양부터 틀린 값은 저장소를 뒤지지 않는다")
  void redeem_badShapeDoesNotQuery() {
    assertThatThrownBy(() -> service.redeem("!!!"))
      .isInstanceOf(CustomException.class);

    verify(deviceLinkRepository, never()).findByCodeHash(anyString());
  }

  @Test
  @DisplayName("연결을 끊으면 그 기기 세션만 죽고 보호자 세션은 산다")
  void revoke_killsOnlyLinkedDevice() throws Exception {
    DeviceLink l = link("A7K3M9", LocalDateTime.now().minusMinutes(1));
    l.setRedeemedAt(LocalDateTime.now().minusMinutes(1));
    l.setLinkedDeviceId("elumi-1");
    when(deviceLinkRepository.findById("l1")).thenReturn(Optional.of(l));

    service.revoke("m1", "l1");

    assertThat(l.getRevokedAt()).isNotNull();
    verify(refreshTokenRepository).revokeByMemberIdAndDeviceId(eq("m1"), eq("elumi-1"), any(), eq(RevokeReason.DEVICE_UNLINKED));
    // 계정 전체를 끊으면 보호자까지 로그아웃된다.
    verify(refreshTokenRepository, never()).revokeAllByMemberId(anyString(), any(), any());
  }

  @Test
  @DisplayName("기기 값이 비어 있어도 끊을 대상을 스스로 찾아낸다")
  void revoke_derivesDeviceIdWhenMissing() throws Exception {
    // 옛 데이터에 linkedDeviceId 가 비어 있어도 끊기가 무력해지면 안 된다 —
    // 잃어버린 휴대폰이 계속 일과를 보는 상황이 그대로 남는다.
    DeviceLink l = link("A7K3M9", LocalDateTime.now().minusMinutes(1));
    l.setRedeemedAt(LocalDateTime.now().minusMinutes(1));
    l.setLinkedDeviceId(null);
    when(deviceLinkRepository.findById("l1")).thenReturn(Optional.of(l));

    service.revoke("m1", "l1");

    verify(refreshTokenRepository).revokeByMemberIdAndDeviceId(eq("m1"), eq("elumi-l1"), any(), eq(RevokeReason.DEVICE_UNLINKED));
  }

  @Test
  @DisplayName("연결된 휴대폰이 없으면 끊을 수 없다")
  void revoke_notConnected() {
    assertThatThrownBy(() -> service.revoke("m1", "l1"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.DEVICE_LINK_NOT_CONNECTED));
  }

  @Test
  @DisplayName("상태 — 연결 전에는 비어 있고, 발급하면 만료 시각이, 연결하면 목록이 찬다")
  void status() throws Exception {
    assertThat(service.status(GUARDIAN).devices()).isEmpty();
    assertThat(service.status(GUARDIAN).pendingExpiresAt()).isNull();

    DeviceLink pending = link("A7K3M9", LocalDateTime.now().plusMinutes(5));
    when(deviceLinkRepository.findByMemberIdAndRevokedAtIsNullOrderByCreatedAtDesc("m1"))
      .thenReturn(List.of(pending));
    assertThat(service.status(GUARDIAN).pendingExpiresAt()).isNotNull();
    assertThat(service.status(GUARDIAN).devices()).isEmpty();

    pending.setRedeemedAt(LocalDateTime.now());
    LinkStatusResponse linked = service.status(GUARDIAN);
    assertThat(linked.devices()).hasSize(1);
    assertThat(linked.devices().get(0).linkedAt()).isNotNull();
    assertThat(linked.pendingExpiresAt()).isNull();
  }

  @Test
  @DisplayName("휴대폰은 여러 대 붙을 수 있다 — 새 기기를 붙여도 쓰던 기기가 끊기지 않는다")
  void status_multipleDevices() throws Exception {
    DeviceLink first = link("A7K3M9", LocalDateTime.now().minusHours(2));
    first.setId("l1");
    first.setRedeemedAt(LocalDateTime.now().minusHours(2));
    DeviceLink second = link("B8L4N2", LocalDateTime.now().minusMinutes(5));
    second.setId("l2");
    second.setRedeemedAt(LocalDateTime.now().minusMinutes(5));
    when(deviceLinkRepository.findByMemberIdAndRevokedAtIsNullOrderByCreatedAtDesc("m1"))
      .thenReturn(List.of(second, first));

    assertThat(service.status(GUARDIAN).devices())
      .extracting(d -> d.linkId())
      .containsExactly("l2", "l1");
  }

  @Test
  @DisplayName("한 대를 끊어도 다른 대는 살아 있다")
  void revoke_onlyTargetedDevice() throws Exception {
    DeviceLink first = link("A7K3M9", LocalDateTime.now().minusHours(2));
    first.setId("l1");
    first.setRedeemedAt(LocalDateTime.now().minusHours(2));
    first.setLinkedDeviceId("elumi-l1");
    DeviceLink second = link("B8L4N2", LocalDateTime.now().minusMinutes(5));
    second.setId("l2");
    second.setRedeemedAt(LocalDateTime.now().minusMinutes(5));
    second.setLinkedDeviceId("elumi-l2");
    when(deviceLinkRepository.findById("l1")).thenReturn(Optional.of(first));

    service.revoke("m1", "l1");

    assertThat(first.getRevokedAt()).isNotNull();
    assertThat(second.getRevokedAt()).isNull();
    verify(refreshTokenRepository).revokeByMemberIdAndDeviceId(eq("m1"), eq("elumi-l1"), any(), eq(RevokeReason.DEVICE_UNLINKED));
  }

  @Test
  @DisplayName("남의 연결은 끊을 수 없다 — linkId만 알아도 못 끊는다")
  void revoke_otherMembersLink() throws Exception {
    DeviceLink other = link("A7K3M9", LocalDateTime.now().minusMinutes(1));
    other.setMemberId("someone-else");
    other.setRedeemedAt(LocalDateTime.now().minusMinutes(1));
    when(deviceLinkRepository.findById("l1")).thenReturn(Optional.of(other));

    assertThatThrownBy(() -> service.revoke("m1", "l1"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.DEVICE_LINK_NOT_CONNECTED));

    assertThat(other.getRevokedAt()).isNull();
  }

  @Test
  @DisplayName("E39 연결 암호는 판단자가 고른 이룸이에 묶인다 — 그 휴대폰은 이 이룸이만 본다")
  void e39_issue_bindsLinkToResolvedProfile() {
    service.issue(GUARDIAN);

    verify(deviceLinkRepository).save(org.mockito.ArgumentMatchers.argThat(link -> "p1".equals(link.getProfileId())));
  }

  // --- #363: 함께 돌보는 보호자가 서로 붙인 휴대폰을 보고 끊는다 (명세 4-2 권한 표) ---

  private void stubProfile() {
    Profile p = new Profile();
    p.setId("p1");
    when(profileAccessGuard.profilesOf(GUARDIAN)).thenReturn(List.of(p));
  }

  /** 보호자 a(m1)가 p1 에 붙인, 연결된 휴대폰. */
  private DeviceLink linkedByM1OnP1() throws Exception {
    DeviceLink l = link("A7K3M9", LocalDateTime.now().minusMinutes(1));
    l.setProfileId("p1");
    l.setRedeemedAt(LocalDateTime.now().minusMinutes(1));
    l.setLinkedDeviceId("elumi-1");
    return l;
  }

  @Test
  @DisplayName("#363 같은 이룸이를 돌보는 다른 보호자도 그 휴대폰을 끊는다 — 세션은 붙인 보호자 것을 폐기한다")
  void revoke_byOtherGuardianOfSameProfile() throws Exception {
    DeviceLink l = linkedByM1OnP1();
    when(deviceLinkRepository.findById("l1")).thenReturn(Optional.of(l));
    when(profileAccessGuard.isGuardianOf("m2", "p1")).thenReturn(true);

    service.revoke("m2", "l1");

    assertThat(l.getRevokedAt()).isNotNull();
    // 토큰의 주인(sub)은 붙인 보호자 m1 이다. 끊는 사람(m2)의 세션을 건드리면 엉뚱한 사람이 로그아웃된다.
    verify(refreshTokenRepository).revokeByMemberIdAndDeviceId(eq("m1"), eq("elumi-1"), any(), eq(RevokeReason.DEVICE_UNLINKED));
    verify(refreshTokenRepository, never()).revokeByMemberIdAndDeviceId(eq("m2"), anyString(), any(), any());
  }

  @Test
  @DisplayName("#363 그 이룸이를 돌보지 않는 보호자는 linkId 를 알아도 못 끊고, 있는지도 알 수 없다")
  void revoke_byGuardianOfOtherProfile() throws Exception {
    DeviceLink l = linkedByM1OnP1();
    when(deviceLinkRepository.findById("l1")).thenReturn(Optional.of(l));
    when(profileAccessGuard.isGuardianOf("m3", "p1")).thenReturn(false);

    assertThatThrownBy(() -> service.revoke("m3", "l1"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.DEVICE_LINK_NOT_CONNECTED));

    assertThat(l.getRevokedAt()).isNull();
    verify(refreshTokenRepository, never()).revokeByMemberIdAndDeviceId(anyString(), anyString(), any(), any());
  }

  @Test
  @DisplayName("#363 상태는 이룸이 기준이다 — 다른 보호자가 붙인 휴대폰도 보인다")
  void status_includesLinksOtherGuardiansMade() throws Exception {
    DeviceLink byOther = linkedByM1OnP1();
    byOther.setMemberId("m2");
    byOther.setId("l9");
    stubProfile();
    when(deviceLinkRepository.findByProfileIdAndRevokedAtIsNullOrderByCreatedAtDesc("p1"))
      .thenReturn(List.of(byOther));

    assertThat(service.status(GUARDIAN).devices()).extracting(d -> d.linkId()).containsExactly("l9");
  }

  @Test
  @DisplayName("#363 다른 보호자가 발급한 아직 안 쓴 암호는 내 상태의 '발급 중'으로 보이지 않는다")
  void status_pendingIsOnlyMine() throws Exception {
    DeviceLink othersPending = link("A7K3M9", LocalDateTime.now().plusMinutes(5));
    othersPending.setMemberId("m2");
    othersPending.setProfileId("p1");
    stubProfile();
    when(deviceLinkRepository.findByProfileIdAndRevokedAtIsNullOrderByCreatedAtDesc("p1"))
      .thenReturn(List.of(othersPending));

    assertThat(service.status(GUARDIAN).pendingExpiresAt()).isNull();
  }

  @Test
  @DisplayName("#363 이룸이가 없는 보호자(E29)의 상태는 오류가 아니라 비어 있다 — 설정 화면이 멈추지 않게")
  void status_noProfileIsEmpty() {
    when(profileAccessGuard.profilesOf(GUARDIAN)).thenReturn(List.of());

    assertThat(service.status(GUARDIAN).devices()).isEmpty();
  }

  @Test
  @DisplayName("#363 이룸이 휴대폰이 자기 연결을 끊는다 — 그 휴대폰의 세션만 폐기한다")
  void revokeCurrent_killsOwnDeviceOnly() throws Exception {
    DeviceLink l = linkedByM1OnP1();
    when(deviceLinkRepository.findById("l1")).thenReturn(Optional.of(l));

    service.revokeCurrent(Caller.elumi("m1", "l1"));

    assertThat(l.getRevokedAt()).isNotNull();
    verify(refreshTokenRepository).revokeByMemberIdAndDeviceId(eq("m1"), eq("elumi-1"), any(), eq(RevokeReason.DEVICE_UNLINKED));
    verify(refreshTokenRepository, never()).revokeAllByMemberId(anyString(), any(), any());
  }

  @Test
  @DisplayName("#363 이미 끊긴 연결을 다시 끊으면 404 — 앱은 이미 끊긴 것으로 받아들인다")
  void revokeCurrent_alreadyRevoked() throws Exception {
    DeviceLink l = linkedByM1OnP1();
    l.setRevokedAt(LocalDateTime.now());
    when(deviceLinkRepository.findById("l1")).thenReturn(Optional.of(l));

    assertThatThrownBy(() -> service.revokeCurrent(Caller.elumi("m1", "l1")))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.DEVICE_LINK_NOT_CONNECTED));
  }

  @Test
  @DisplayName("#363 이룸이 토큰의 계정과 연결의 주인이 다르면 끊지 않는다")
  void revokeCurrent_foreignLink() throws Exception {
    DeviceLink l = linkedByM1OnP1();
    l.setMemberId("someone-else");
    when(deviceLinkRepository.findById("l1")).thenReturn(Optional.of(l));

    assertThatThrownBy(() -> service.revokeCurrent(Caller.elumi("m1", "l1")))
      .isInstanceOf(CustomException.class);

    assertThat(l.getRevokedAt()).isNull();
  }

  @Test
  @DisplayName("#363 보호자 토큰(연결 ID 없음)으로는 자기 연결 끊기를 쓸 수 없다")
  void revokeCurrent_guardianRejected() {
    assertThatThrownBy(() -> service.revokeCurrent(GUARDIAN))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.DEVICE_LINK_ONLY_FOR_ELUMI));
  }
}
