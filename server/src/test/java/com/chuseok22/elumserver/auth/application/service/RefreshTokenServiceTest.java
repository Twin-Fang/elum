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
import com.chuseok22.elumserver.auth.infrastructure.repository.RefreshTokenRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.JwtProperties;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
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
    // 체인을 남겨야 재사용이 감지됐을 때 어디서 갈라졌는지 추적할 수 있다.
    assertThat(previous.getReplacedById()).isEqualTo("rt-1");
  }

  @Test
  @DisplayName("이미 쓴 토큰이 다시 오면 탈취로 보고 그 계정의 세션을 모두 끊는다")
  void rotate_reusedToken_revokesEverySession() {
    RefreshToken used = livingToken();
    used.setRevokedAt(LocalDateTime.now().minusMinutes(5));
    when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.of(used));

    assertThatThrownBy(() -> refreshTokenService.rotate("raw-used", "device-1"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.REFRESH_TOKEN_REUSED));

    // 폐기는 별도 트랜잭션으로 나가야 한다. 같은 트랜잭션이면 아래 예외에 롤백돼
    // 감지만 하고 세션이 살아남는다.
    verify(refreshTokenRevoker).revokeAllInNewTransaction(eq("m1"), any(LocalDateTime.class));
    verify(refreshTokenRepository, never()).save(any(RefreshToken.class));
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
    verify(refreshTokenRevoker, never()).revokeAllInNewTransaction(anyString(), any(LocalDateTime.class));
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
}
