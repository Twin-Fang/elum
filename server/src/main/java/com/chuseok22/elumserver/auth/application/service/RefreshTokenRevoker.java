package com.chuseok22.elumserver.auth.application.service;

import com.chuseok22.elumserver.auth.infrastructure.entity.RevokeReason;
import com.chuseok22.elumserver.auth.infrastructure.repository.RefreshTokenRepository;
import com.chuseok22.elumserver.link.core.ElumiDeviceId;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * 세션 폐기를 <b>바깥 트랜잭션과 분리해</b> 수행한다.
 *
 * <p>리프레시 토큰 재사용을 감지하면 세션을 끊고 예외를 던져야 하는데,
 * 같은 트랜잭션 안에서 하면 <b>예외가 롤백을 일으켜 폐기까지 되돌아간다.</b>
 * 감지는 되는데 세션은 그대로 살아 있어, 탈취자가 계속 쓸 수 있다.
 *
 * <p>별도 빈으로 뺀 이유는 자기 호출(self-invocation)이 프록시를 거치지 않아
 * {@code REQUIRES_NEW}가 적용되지 않기 때문이다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RefreshTokenRevoker {

  private final RefreshTokenRepository refreshTokenRepository;

  /**
   * 보호자 휴대폰 세션만 새 트랜잭션에서 끊고 즉시 커밋한다 (다중 보호자 E34). 호출부가 예외를 던져도 남는다.
   *
   * <p>이룸이 휴대폰 세션은 남긴다 — 보호자 토큰이 새었다고 이룸이가 일과를 못 보게 할 이유가 없다.
   */
  @Transactional(propagation = Propagation.REQUIRES_NEW)
  public int revokeGuardianSessionsInNewTransaction(String memberId, LocalDateTime now) {
    // 회전이 아닌 사유로 남긴다 — 이렇게 끊긴 토큰이 또 와도 다시 전부 끊지 않는다 (#360 D1).
    return refreshTokenRepository.revokeGuardianSessions(
      memberId, ElumiDeviceId.LIKE_PATTERN, now, RevokeReason.REUSE_DETECTED);
  }

  /**
   * 한 기기의 세션만 새 트랜잭션에서 끊는다 (이슈 #359).
   *
   * <p>끊긴 연결의 이룸이 휴대폰이 갱신하러 왔을 때 쓴다. 계정 전체를 끊으면 보호자까지
   * 로그아웃된다.
   *
   * @param reason 연결이 끊겨 거절하면 {@link RevokeReason#DEVICE_UNLINKED}, 재사용이면 {@link RevokeReason#REUSE_DETECTED}
   */
  @Transactional(propagation = Propagation.REQUIRES_NEW)
  public int revokeDeviceInNewTransaction(String memberId, String deviceId, LocalDateTime now, RevokeReason reason) {
    return refreshTokenRepository.revokeByMemberIdAndDeviceId(memberId, deviceId, now, reason);
  }
}
