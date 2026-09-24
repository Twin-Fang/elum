package com.chuseok22.elumserver.auth.infrastructure.repository;

import com.chuseok22.elumserver.auth.infrastructure.entity.RefreshToken;
import com.chuseok22.elumserver.auth.infrastructure.entity.RevokeReason;
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

  /** 계정 정지·강제 로그아웃 시 계정의 살아 있는 토큰을 한 번에 끊는다. 사유는 부른 쪽이 정한다. */
  @Modifying
  @Query("update RefreshToken t set t.revokedAt = :now, t.revokeReason = :reason "
    + "where t.memberId = :memberId and t.revokedAt is null")
  int revokeAllByMemberId(@Param("memberId") String memberId,
                          @Param("now") LocalDateTime now,
                          @Param("reason") RevokeReason reason);

  /**
   * 한 기기의 세션만 끊는다 (이슈 #200).
   *
   * <p>이룸이 휴대폰 연결을 끊을 때 쓴다. 계정 전체를 끊으면 보호자까지 로그아웃되므로
   * 기기를 짚어서 끊어야 한다.
   */
  @Modifying
  @Query("update RefreshToken t set t.revokedAt = :now, t.revokeReason = :reason "
    + "where t.memberId = :memberId and t.deviceId = :deviceId and t.revokedAt is null")
  int revokeByMemberIdAndDeviceId(@Param("memberId") String memberId,
                                  @Param("deviceId") String deviceId,
                                  @Param("now") LocalDateTime now,
                                  @Param("reason") RevokeReason reason);

  /**
   * 이 보호자의 <b>보호자 휴대폰</b> 세션만 끊는다 (다중 보호자 E34).
   *
   * <p>재사용이 감지되면 그 보호자의 세션을 끊는데, 그가 붙여 준 이룸이 휴대폰까지 끊으면 이룸이가
   * 일과를 못 본다. 이룸이 휴대폰은 따로 믿는 대상이다. 앱이 기기 값을 안 보내 보호자 세션은
   * {@code device_id} 가 비어 있기 쉬워 NULL 도 보호자로 친다.
   */
  @Modifying
  @Query("update RefreshToken t set t.revokedAt = :now, t.revokeReason = :reason "
    + "where t.memberId = :memberId and t.revokedAt is null "
    + "and (t.deviceId is null or t.deviceId not like :elumiPattern)")
  int revokeGuardianSessions(@Param("memberId") String memberId,
                             @Param("elumiPattern") String elumiPattern,
                             @Param("now") LocalDateTime now,
                             @Param("reason") RevokeReason reason);

  /** 회원 탈퇴 시 남은 세션 기록까지 지운다. */
  void deleteAllByMemberId(String memberId);

  /** 만료된 지 오래된 것을 지운다. 기록을 영원히 쌓을 이유가 없다. */
  @Modifying
  @Query("delete from RefreshToken t where t.expiresAt < :threshold")
  int deleteExpiredBefore(@Param("threshold") LocalDateTime threshold);
}
