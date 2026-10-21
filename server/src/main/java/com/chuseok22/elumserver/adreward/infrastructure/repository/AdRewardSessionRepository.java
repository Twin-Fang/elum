package com.chuseok22.elumserver.adreward.infrastructure.repository;

import com.chuseok22.elumserver.adreward.core.AdRewardStatus;
import com.chuseok22.elumserver.adreward.infrastructure.entity.AdRewardSession;
import jakarta.persistence.LockModeType;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AdRewardSessionRepository
  extends JpaRepository<AdRewardSession, String>, JpaSpecificationExecutor<AdRewardSession> {

  Optional<AdRewardSession> findByNonce(String nonce);

  /**
   * 콜백이 가리키는 세션을 잠그고 읽는다(SELECT … FOR UPDATE). 같은 시청의 콜백 둘(Google 재시도)이 동시에 와도
   * 한 줄로 서서 두 번째는 이미 지급된 것을 본다.
   */
  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("select s from AdRewardSession s where s.nonce = :nonce")
  Optional<AdRewardSession> findByNonceForUpdate(@Param("nonce") String nonce);

  /// 회원이 지금 기다리는 세션 하나(가장 최근). 새로 만들지 않고 이것을 다시 쓴다.
  Optional<AdRewardSession> findFirstByMemberIdAndStatusAndExpiresAtAfterOrderByCreatedAtDesc(
    String memberId, AdRewardStatus status, LocalDateTime now);


  boolean existsByTransactionId(String transactionId);

  /// 관리자 요약: 기간[from, to) 에 만든 세션의 저장 상태별 건수
  @Query("select s.status as status, count(s) as sessionCount from AdRewardSession s "
    + "where s.createdAt >= :from and s.createdAt < :to group by s.status")
  List<StatusCount> countByStatusCreatedBetween(@Param("from") LocalDateTime from, @Param("to") LocalDateTime to);

  /// 관리자 요약: 기간[from, to) 에 만든 세션 중 콜백 없이 유효 시간이 지난 것 (저장 상태는 PENDING 그대로)
  @Query("select count(s) from AdRewardSession s where s.createdAt >= :from and s.createdAt < :to "
    + "and s.status = com.chuseok22.elumserver.adreward.core.AdRewardStatus.PENDING and s.expiresAt <= :now")
  long countStalePendingCreatedBetween(
    @Param("from") LocalDateTime from, @Param("to") LocalDateTime to, @Param("now") LocalDateTime now);

  /// 관리자 요약: 기간[from, to) 에 만든 세션의 지급 크레딧 합
  @Query("select coalesce(sum(s.grantedCredits), 0L) from AdRewardSession s "
    + "where s.createdAt >= :from and s.createdAt < :to "
    + "and s.status = com.chuseok22.elumserver.adreward.core.AdRewardStatus.GRANTED")
  long sumGrantedCreditsCreatedBetween(@Param("from") LocalDateTime from, @Param("to") LocalDateTime to);

  /// 상태별 건수 투영
  interface StatusCount {

    AdRewardStatus getStatus();

    long getSessionCount();
  }

  /// 탈퇴할 때 회원의 세션을 지운다. 지급의 흔적은 크레딧 묶음·원장에 남으므로 세션까지 남길 이유가 없다.
  void deleteAllByMemberId(String memberId);
}
