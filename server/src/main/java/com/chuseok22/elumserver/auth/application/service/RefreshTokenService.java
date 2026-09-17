package com.chuseok22.elumserver.auth.application.service;

import com.chuseok22.elumserver.auth.infrastructure.entity.RefreshToken;
import com.chuseok22.elumserver.auth.infrastructure.repository.RefreshTokenRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.JwtProperties;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.HexFormat;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 리프레시 토큰 발급·회전·폐기.
 *
 * <p>액세스 토큰은 1일, 리프레시는 6개월이다. 앱은 액세스가 만료되면 조용히 갱신하므로
 * 사용자는 로그아웃을 겪지 않는다. 인스타그램에서 로그인 상태가 계속 유지되는 것과 같은 방식이다.
 *
 * <p><b>왜 JWT가 아닌가</b> — 리프레시는 서버가 언제든 끊을 수 있어야 한다. JWT는
 * 서명만 맞으면 유효해서 끊을 방법이 없다. 그래서 무작위 문자열을 발급하고 DB에
 * 해시만 남긴다. 해시로 두면 DB가 통째로 새도 토큰 자체는 새지 않는다.
 *
 * <p><b>회전과 재사용 감지</b> — 갱신할 때마다 새 토큰을 주고 쓴 토큰은 즉시 끊는다.
 * 이미 끊긴 토큰이 다시 오면 누군가 복사본을 들고 있다는 뜻이므로 그 계정의 모든 토큰을
 * 끊는다. 정상 사용자는 다시 로그인하면 되지만, 회전이 없으면 탈취를 영영 모른다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RefreshTokenService {

  private static final SecureRandom RANDOM = new SecureRandom();
  private static final int TOKEN_BYTES = 48;

  private final RefreshTokenRepository refreshTokenRepository;
  private final JwtProperties jwtProperties;

  /**
   * 새 리프레시 토큰을 발급한다.
   *
   * @return 클라이언트에 내려줄 <b>원문</b>. 서버는 이 값을 다시 볼 수 없다(해시만 저장).
   */
  @Transactional
  public String issue(String memberId, String deviceId) {
    return save(memberId, deviceId, null).rawToken();
  }

  /**
   * 리프레시 토큰을 검증하고 새 토큰으로 교체한다.
   *
   * @return 계정 ID와 새 리프레시 토큰 원문
   */
  @Transactional
  public RotationResult rotate(String rawToken, String deviceId) {
    if (rawToken == null || rawToken.isBlank()) {
      throw new CustomException(ErrorCode.REFRESH_TOKEN_INVALID);
    }

    RefreshToken current = refreshTokenRepository.findByTokenHash(hash(rawToken))
      .orElseThrow(() -> new CustomException(ErrorCode.REFRESH_TOKEN_INVALID));

    LocalDateTime now = LocalDateTime.now();

    // 이미 끊긴 토큰이 다시 왔다 = 복사본이 돌아다닌다. 계정 전체를 끊는다.
    if (current.getRevokedAt() != null) {
      int revoked = refreshTokenRepository.revokeAllByMemberId(current.getMemberId(), now);
      log.warn("리프레시 토큰이 재사용되어 계정의 세션을 모두 끊었습니다. memberId={}, 끊은 수={}",
        current.getMemberId(), revoked);
      throw new CustomException(ErrorCode.REFRESH_TOKEN_REUSED);
    }

    if (!current.isUsable(now)) {
      throw new CustomException(ErrorCode.REFRESH_TOKEN_INVALID);
    }

    // 기기 정보는 이번 갱신 값으로 이어 준다. 앱 재설치로 기기 ID가 바뀌어도 세션은 유지된다.
    String nextDeviceId = deviceId != null && !deviceId.isBlank() ? deviceId : current.getDeviceId();
    IssuedToken next = save(current.getMemberId(), nextDeviceId, current.getId());

    current.setRevokedAt(now);
    current.setLastUsedAt(now);
    current.setReplacedById(next.entity().getId());

    return new RotationResult(current.getMemberId(), next.rawToken());
  }

  /** 로그아웃. 넘어온 토큰이 속한 계정의 세션을 전부 끊는다. */
  @Transactional
  public void revokeByToken(String rawToken) {
    if (rawToken == null || rawToken.isBlank()) {
      return;
    }
    refreshTokenRepository.findByTokenHash(hash(rawToken))
      .ifPresent(token -> refreshTokenRepository.revokeAllByMemberId(token.getMemberId(), LocalDateTime.now()));
  }

  /** 회원 탈퇴·강제 로그아웃용. */
  @Transactional
  public void revokeAll(String memberId) {
    refreshTokenRepository.revokeAllByMemberId(memberId, LocalDateTime.now());
  }

  private IssuedToken save(String memberId, String deviceId, String previousId) {
    byte[] bytes = new byte[TOKEN_BYTES];
    RANDOM.nextBytes(bytes);
    String rawToken = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);

    RefreshToken token = new RefreshToken();
    token.setMemberId(memberId);
    token.setTokenHash(hash(rawToken));
    token.setDeviceId(deviceId);
    token.setExpiresAt(LocalDateTime.now().plusNanos(jwtProperties.refreshExpMillis() * 1_000_000L));
    if (previousId != null) {
      token.setLastUsedAt(LocalDateTime.now());
    }

    return new IssuedToken(refreshTokenRepository.save(token), rawToken);
  }

  private String hash(String rawToken) {
    try {
      MessageDigest digest = MessageDigest.getInstance("SHA-256");
      return HexFormat.of().formatHex(digest.digest(rawToken.getBytes(StandardCharsets.UTF_8)));
    } catch (NoSuchAlgorithmException e) {
      // SHA-256은 JDK 표준이라 실제로는 발생하지 않는다.
      throw new IllegalStateException("SHA-256을 사용할 수 없습니다", e);
    }
  }

  public record RotationResult(String memberId, String refreshToken) {

  }

  private record IssuedToken(RefreshToken entity, String rawToken) {

  }
}
