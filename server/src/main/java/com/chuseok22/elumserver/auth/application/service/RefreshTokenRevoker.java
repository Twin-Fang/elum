package com.chuseok22.elumserver.auth.application.service;

import com.chuseok22.elumserver.auth.infrastructure.repository.RefreshTokenRepository;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * 세션 폐기를 <b>바깥 트랜잭션과 분리해</b> 수행한다.
 *
 * <p>리프레시 토큰 재사용을 감지하면 계정의 모든 세션을 끊고 예외를 던져야 하는데,
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

  /** 새 트랜잭션에서 폐기하고 즉시 커밋한다. 호출부가 예외를 던져도 남는다. */
  @Transactional(propagation = Propagation.REQUIRES_NEW)
  public int revokeAllInNewTransaction(String memberId, LocalDateTime now) {
    return refreshTokenRepository.revokeAllByMemberId(memberId, now);
  }
}
