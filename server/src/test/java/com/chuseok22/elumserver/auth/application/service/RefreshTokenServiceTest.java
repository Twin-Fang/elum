package com.chuseok22.elumserver.auth.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.auth.infrastructure.entity.RefreshToken;
import com.chuseok22.elumserver.auth.infrastructure.entity.RevokeReason;
import com.chuseok22.elumserver.auth.infrastructure.repository.RefreshTokenRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.jwt.LinkAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.properties.JwtProperties;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class RefreshTokenServiceTest {

  @Mock
  private RefreshTokenRepository refreshTokenRepository;

  @Mock
  private RefreshTokenRevoker refreshTokenRevoker;

  @Mock
  private JwtProperties jwtProperties;

  @Mock
  private LinkAccessValidator linkAccessValidator;

  @InjectMocks
  private RefreshTokenService refreshTokenService;

  private final AtomicInteger savedCount = new AtomicInteger();

  @BeforeEach
  void setUp() {
    savedCount.set(0);
  }

  /** 저장된 엔티티에 DB가 채워 줄 id를 흉내 내어 넣어 준다. */
  private void stubSave() {
    when(refreshTokenRepository.save(any(RefreshToken.class))).thenAnswer(invocation -> {
      RefreshToken token = invocation.getArgument(0);
      token.setId("rt-" + savedCount.incrementAndGet());
      return token;
    });
  }

  private RefreshToken livingToken() {
    RefreshToken token = new RefreshToken();
    token.setId("rt-old");
    token.setMemberId("m1");
    token.setTokenHash("hash-old");
    token.setDeviceId("device-1");
    token.setExpiresAt(LocalDateTime.now().plusDays(30));
    return token;
  }

  /** 연결 암호로 붙은 이룸이 휴대폰의 토큰. 기기 값은 연결할 때 서버가 만든다. */
  private RefreshToken elumiToken() {
    RefreshToken token = livingToken();
    token.setDeviceId("elumi-l1");
    return token;
  }

  @Test
  @DisplayName("발급한 원문은 저장하지 않는다 — DB에는 해시만 남는다")
  void issue_storesHashOnly() {
    when(jwtProperties.refreshExpMillis()).thenReturn(15552000000L);
    stubSave();

    String rawToken = refreshTokenService.issue("m1", "device-1");

    assertThat(rawToken).isNotBlank();
    verify(refreshTokenRepository).save(org.mockito.ArgumentMatchers.argThat(saved ->
      !rawToken.equals(saved.getTokenHash())
        && saved.getTokenHash().length() == 64
        && "m1".equals(saved.getMemberId())
        && "device-1".equals(saved.getDeviceId())
    ));
  }

  @Test
  @DisplayName("갱신하면 새 토큰이 나오고 쓴 토큰은 즉시 만료된다")
  void rotate_revokesPreviousAndIssuesNew() {
    RefreshToken previous = livingToken();
    when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.of(previous));
    when(jwtProperties.refreshExpMillis()).thenReturn(15552000000L);
    stubSave();

    RefreshTokenService.RotationResult result = refreshTokenService.rotate("raw-old", "device-1");

    assertThat(result.memberId()).isEqualTo("m1");
    assertThat(result.refreshToken()).isNotBlank();
    assertThat(previous.getRevokedAt()).isNotNull();
    // 회전으로 끊겼다고 적어야 이 토큰이 다시 올 때 복사본(탈취)으로 볼 수 있다 (#360 D1).
    assertThat(previous.getRevokeReason()).isEqualTo(RevokeReason.ROTATED);
    // 체인을 남겨야 재사용이 감지됐을 때 어디서 갈라졌는지 추적할 수 있다.
    assertThat(previous.getReplacedById()).isEqualTo("rt-1");
  }

  @Test
  @DisplayName("E34 보호자 토큰이 재사용되면 그 보호자의 보호자 휴대폰 세션을 끊는다 — 그가 붙인 이룸이 휴대폰은 남긴다")
  void e34_rotate_reusedGuardianToken_revokesGuardianSessionsOnly() {
    RefreshToken used = livingToken();
    used.setRevokedAt(LocalDateTime.now().minusMinutes(5));
    used.setRevokeReason(RevokeReason.ROTATED);
    when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.of(used));

    assertThatThrownBy(() -> refreshTokenService.rotate("raw-used", "device-1"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.REFRESH_TOKEN_REUSED));

    // 폐기는 별도 트랜잭션으로 나가야 한다. 같은 트랜잭션이면 아래 예외에 롤백돼
    // 감지만 하고 세션이 살아남는다.
    verify(refreshTokenRevoker).revokeGuardianSessionsInNewTransaction(eq("m1"), any(LocalDateTime.class));
    verify(refreshTokenRevoker, never()).revokeDeviceInNewTransaction(anyString(), anyString(), any(), any());
    verify(refreshTokenRepository, never()).save(any(RefreshToken.class));
  }

  @Test
  @DisplayName("E34 이룸이 휴대폰 토큰이 재사용되면 그 휴대폰 세션만 끊는다 — 보호자 휴대폰은 따로 믿는다")
  void e34_rotate_reusedElumiToken_revokesThatPhoneOnly() {
    RefreshToken used = elumiToken();
    used.setRevokedAt(LocalDateTime.now().minusMinutes(5));
    used.setRevokeReason(RevokeReason.ROTATED);
    when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.of(used));
    when(linkAccessValidator.isLinkActive("l1")).thenReturn(true);

    assertThatThrownBy(() -> refreshTokenService.rotate("raw-elumi", null))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.REFRESH_TOKEN_REUSED));

    verify(refreshTokenRevoker).revokeDeviceInNewTransaction(
      eq("m1"), eq("elumi-l1"), any(LocalDateTime.class), eq(RevokeReason.REUSE_DETECTED));
    verify(refreshTokenRevoker, never()).revokeGuardianSessionsInNewTransaction(anyString(), any());
  }

  @Test
  @DisplayName("D1 로그아웃으로 끊긴 토큰이 다시 오면 401 만 준다 — 같은 보호자의 다른 휴대폰 세션은 그대로다")
  void d1_rotate_logoutRevokedToken_rejectsWithoutRevokingOthers() {
    RefreshToken loggedOut = livingToken();
    loggedOut.setRevokedAt(LocalDateTime.now().minusMinutes(1));
    loggedOut.setRevokeReason(RevokeReason.LOGOUT);
    when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.of(loggedOut));

    assertThatThrownBy(() -> refreshTokenService.rotate("raw-logged-out", null))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.REFRESH_TOKEN_INVALID));

    // 로그아웃 요청과 자동 갱신이 겹치면 정상 앱도 이 토큰을 한 번 더 보낸다. 탈취 신호가 아니다.
    verify(refreshTokenRevoker, never()).revokeGuardianSessionsInNewTransaction(anyString(), any());
    verify(refreshTokenRevoker, never()).revokeDeviceInNewTransaction(anyString(), anyString(), any(), any());
    verify(refreshTokenRepository, never()).save(any(RefreshToken.class));
  }

  @ParameterizedTest(name = "{0}")
  @EnumSource(value = RevokeReason.class, names = "ROTATED", mode = EnumSource.Mode.EXCLUDE)
  @DisplayName("D1 회전이 아닌 사유로 끊긴 토큰은 재사용으로 보지 않는다 — 401 만 준다")
  void d1_rotate_nonRotationRevokedToken_rejectsOnly(RevokeReason reason) {
    RefreshToken revoked = livingToken();
    revoked.setRevokedAt(LocalDateTime.now().minusMinutes(1));
    revoked.setRevokeReason(reason);
    when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.of(revoked));

    assertThatThrownBy(() -> refreshTokenService.rotate("raw-revoked", null))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.REFRESH_TOKEN_INVALID));

    verify(refreshTokenRevoker, never()).revokeGuardianSessionsInNewTransaction(anyString(), any());
    verify(refreshTokenRevoker, never()).revokeDeviceInNewTransaction(anyString(), anyString(), any(), any());
  }

  @Test
  @DisplayName("D1 사유가 없는 옛 폐기 토큰(V27 이전)은 401 만 준다 — 회전인지 로그아웃인지 몰라 세션을 끊지 않는다")
  void d1_rotate_legacyRevokedTokenWithoutReason_rejectsOnly() {
    RefreshToken legacy = livingToken();
    legacy.setRevokedAt(LocalDateTime.now().minusDays(3));
    legacy.setRevokeReason(null);
    when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.of(legacy));

    assertThatThrownBy(() -> refreshTokenService.rotate("raw-legacy", null))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.REFRESH_TOKEN_INVALID));

    verify(refreshTokenRevoker, never()).revokeGuardianSessionsInNewTransaction(anyString(), any());
    verify(refreshTokenRevoker, never()).revokeDeviceInNewTransaction(anyString(), anyString(), any(), any());
  }

  @Test
  @DisplayName("D1 로그아웃한 이룸이 휴대폰 토큰이 다시 와도 401 만 준다 — 그 휴대폰을 다시 끊으러 가지 않는다")
  void d1_rotate_logoutRevokedElumiToken_rejectsOnly() {
    RefreshToken loggedOut = elumiToken();
    loggedOut.setRevokedAt(LocalDateTime.now().minusMinutes(1));
    loggedOut.setRevokeReason(RevokeReason.LOGOUT);
    when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.of(loggedOut));
    when(linkAccessValidator.isLinkActive("l1")).thenReturn(true);

    assertThatThrownBy(() -> refreshTokenService.rotate("raw-elumi", null))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.REFRESH_TOKEN_INVALID));

    verify(refreshTokenRevoker, never()).revokeDeviceInNewTransaction(anyString(), anyString(), any(), any());
  }

  @Test
  @DisplayName("E33 로그아웃은 넘어온 토큰의 기기 세션만 끊는다 — 계정 전체를 끊지 않는다")
  void e33_revokeSession_revokesOnlyThatDevice() {
    RefreshToken current = livingToken();
    when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.of(current));

    refreshTokenService.revokeSession("raw-old");

    assertThat(current.getRevokedAt()).isNotNull();
    // 로그아웃이라고 적어야 이 토큰이 한 번 더 와도 다른 휴대폰까지 끊지 않는다 (#360 D1).
    assertThat(current.getRevokeReason()).isEqualTo(RevokeReason.LOGOUT);
    verify(refreshTokenRepository, never()).revokeAllByMemberId(anyString(), any(), any());
    verify(refreshTokenRepository, never()).revokeByMemberIdAndDeviceId(anyString(), anyString(), any(), any());
  }

  @Test
  @DisplayName("E33 옛 토큰으로 로그아웃해도 그 기기의 살아 있는 토큰까지 따라가 끊는다 — 앱은 기기 값을 보내지 않는다")
  void e33_revokeSession_staleToken_followsRotationChain() {
    RefreshToken stale = livingToken();
    stale.setRevokedAt(LocalDateTime.now().minusDays(1));
    stale.setRevokeReason(RevokeReason.ROTATED);
    stale.setReplacedById("rt-live");
    RefreshToken live = livingToken();
    live.setId("rt-live");
    when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.of(stale));
    when(refreshTokenRepository.findById("rt-live")).thenReturn(Optional.of(live));

    refreshTokenService.revokeSession("raw-stale");

    assertThat(live.getRevokedAt()).isNotNull();
    assertThat(live.getRevokeReason()).isEqualTo(RevokeReason.LOGOUT);
    // 이미 회전으로 끊긴 앞 토큰은 사유를 덮지 않는다 — 그 복사본이 오면 여전히 탈취 신호다.
    assertThat(stale.getRevokeReason()).isEqualTo(RevokeReason.ROTATED);
  }

  @Test
  @DisplayName("계정 전체를 끊을 때 부른 쪽이 준 사유를 함께 남긴다")
  void revokeAll_recordsGivenReason() {
    refreshTokenService.revokeAll("m1", RevokeReason.FORCE_LOGOUT);

    verify(refreshTokenRepository).revokeAllByMemberId(eq("m1"), any(LocalDateTime.class), eq(RevokeReason.FORCE_LOGOUT));
  }

  @Test
  @DisplayName("모르는 토큰으로 로그아웃하면 아무 일도 없다")
  void revokeSession_unknownToken_noop() {
    when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.empty());

    refreshTokenService.revokeSession("raw-unknown");

    verify(refreshTokenRepository, never()).findById(anyString());
  }

  @Test
  @DisplayName("만료된 토큰으로는 갱신할 수 없다")
  void rotate_expiredToken_throwsInvalid() {
    RefreshToken expired = livingToken();
    expired.setExpiresAt(LocalDateTime.now().minusDays(1));
    when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.of(expired));

    assertThatThrownBy(() -> refreshTokenService.rotate("raw-expired", null))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.REFRESH_TOKEN_INVALID));

    // 만료는 정상적인 수명 종료다. 탈취로 보고 계정을 끊으면 안 된다.
    verify(refreshTokenRevoker, never()).revokeGuardianSessionsInNewTransaction(anyString(), any(LocalDateTime.class));
  }

  @Test
  @DisplayName("존재하지 않는 토큰은 유효하지 않은 토큰으로 처리한다")
  void rotate_unknownToken_throwsInvalid() {
    when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.empty());

    assertThatThrownBy(() -> refreshTokenService.rotate("raw-unknown", null))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.REFRESH_TOKEN_INVALID));
  }

  @Test
  @DisplayName("기기 정보를 안 보내면 이전 기기 값을 이어 쓴다")
  void rotate_withoutDeviceId_keepsPreviousDevice() {
    RefreshToken previous = livingToken();
    when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.of(previous));
    when(jwtProperties.refreshExpMillis()).thenReturn(15552000000L);
    stubSave();

    refreshTokenService.rotate("raw-old", null);

    verify(refreshTokenRepository).save(org.mockito.ArgumentMatchers.argThat(saved ->
      "device-1".equals(saved.getDeviceId())
    ));
  }

  @Test
  @DisplayName("이룸이 휴대폰 세션을 갱신하면 어느 연결인지 돌려준다 — 새 액세스 토큰의 역할이 이 값으로 정해진다")
  void rotate_elumiToken_returnsLinkId() {
    when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.of(elumiToken()));
    when(linkAccessValidator.isLinkActive("l1")).thenReturn(true);
    when(jwtProperties.refreshExpMillis()).thenReturn(15552000000L);
    stubSave();

    RefreshTokenService.RotationResult result = refreshTokenService.rotate("raw-elumi", null);

    assertThat(result.memberId()).isEqualTo("m1");
    assertThat(result.linkId()).isEqualTo("l1");
  }

  @Test
  @DisplayName("이룸이 휴대폰 기기 값은 헤더로 바뀌지 않는다 — elumi- 가 떨어지면 다음 갱신부터 보호자 토큰이 나온다")
  void rotate_elumiToken_ignoresDeviceHeader() {
    when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.of(elumiToken()));
    when(linkAccessValidator.isLinkActive("l1")).thenReturn(true);
    when(jwtProperties.refreshExpMillis()).thenReturn(15552000000L);
    stubSave();

    RefreshTokenService.RotationResult result = refreshTokenService.rotate("raw-elumi", "attacker-device");

    assertThat(result.linkId()).isEqualTo("l1");
    // 기기 값이 그대로여야 보호자가 연결을 끊을 때 이 세션도 짚힌다.
    verify(refreshTokenRepository).save(org.mockito.ArgumentMatchers.argThat(saved ->
      "elumi-l1".equals(saved.getDeviceId())
    ));
  }

  @Test
  @DisplayName("연결이 끊긴 이룸이 휴대폰은 갱신이 거절되고 그 기기 세션이 끊긴다")
  void rotate_elumiTokenOfRevokedLink_revokesDeviceAndRejects() {
    RefreshToken token = elumiToken();
    when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.of(token));
    when(linkAccessValidator.isLinkActive("l1")).thenReturn(false);

    assertThatThrownBy(() -> refreshTokenService.rotate("raw-elumi", null))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.REFRESH_TOKEN_INVALID));

    // 예외에 롤백되지 않도록 별도 트랜잭션으로 끊는다. 기기만 짚는다 — 계정 전체면 보호자까지 로그아웃된다.
    verify(refreshTokenRevoker).revokeDeviceInNewTransaction(
      eq("m1"), eq("elumi-l1"), any(LocalDateTime.class), eq(RevokeReason.DEVICE_UNLINKED));
    verify(refreshTokenRevoker, never()).revokeGuardianSessionsInNewTransaction(anyString(), any(LocalDateTime.class));
    verify(refreshTokenRepository, never()).save(any(RefreshToken.class));
  }

  @Test
  @DisplayName("보호자가 끊은 휴대폰이 갱신하러 와도 재사용으로 잡혀 보호자 세션까지 끊기지 않는다")
  void rotate_revokedElumiTokenOfRevokedLink_keepsGuardianSessions() {
    // 연결을 끊을 때 그 기기의 리프레시 토큰도 함께 폐기된다.
    RefreshToken token = elumiToken();
    token.setRevokedAt(LocalDateTime.now().minusMinutes(5));
    when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.of(token));
    when(linkAccessValidator.isLinkActive("l1")).thenReturn(false);

    assertThatThrownBy(() -> refreshTokenService.rotate("raw-elumi", null))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.REFRESH_TOKEN_INVALID));

    verify(refreshTokenRevoker, never()).revokeGuardianSessionsInNewTransaction(anyString(), any(LocalDateTime.class));
  }

  @Test
  @DisplayName("보호자 세션은 헤더 기기 값을 이어 받고 연결을 묻지 않는다")
  void rotate_guardianToken_followsHeaderWithoutLinkCheck() {
    when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.of(livingToken()));
    when(jwtProperties.refreshExpMillis()).thenReturn(15552000000L);
    stubSave();

    RefreshTokenService.RotationResult result = refreshTokenService.rotate("raw-old", "device-2");

    assertThat(result.linkId()).isNull();
    verify(refreshTokenRepository).save(org.mockito.ArgumentMatchers.argThat(saved ->
      "device-2".equals(saved.getDeviceId())
    ));
    verify(linkAccessValidator, never()).isLinkActive(any());
  }
}
