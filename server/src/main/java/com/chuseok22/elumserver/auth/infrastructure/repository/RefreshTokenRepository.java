package com.chuseok22.elumserver.auth.infrastructure.repository;

import com.chuseok22.elumserver.auth.infrastructure.entity.RefreshToken;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, String> {

  Optional<RefreshToken> findByTokenHash(String tokenHash);

  List<RefreshToken> findAllByMemberIdAndRevokedAtIsNull(String memberId);

  /** 로그아웃·탈취 감지 시 계정의 살아 있는 토큰을 한 번에 끊는다. */
  @Modifying
  @Query("update RefreshToken t set t.revokedAt = :now "
    + "where t.memberId = :memberId and t.revokedAt is null")
  int revokeAllByMemberId(@Param("memberId") String memberId, @Param("now") LocalDateTime now);

  /** 회원 탈퇴 시 남은 세션 기록까지 지운다. */
  void deleteAllByMemberId(String memberId);

  /** 만료된 지 오래된 것을 지운다. 기록을 영원히 쌓을 이유가 없다. */
  @Modifying
  @Query("delete from RefreshToken t where t.expiresAt < :threshold")
  int deleteExpiredBefore(@Param("threshold") LocalDateTime threshold);
}
