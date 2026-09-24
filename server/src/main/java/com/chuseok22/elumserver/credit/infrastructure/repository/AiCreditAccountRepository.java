package com.chuseok22.elumserver.credit.infrastructure.repository;

import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.core.CreditAccountStatus;
import jakarta.persistence.LockModeType;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AiCreditAccountRepository extends JpaRepository<AiCreditAccount, String> {

  Optional<AiCreditAccount> findByMemberId(String memberId);

  Optional<AiCreditAccount> findByIdentityKey(String identityKey);

  /// 회원에 붙은 계정 수. 관리자 정책 미리보기의 대상 회원 수 (#407).
  long countByMemberIdIsNotNull();

  List<AiCreditAccount> findByStatus(CreditAccountStatus status);

  List<AiCreditAccount> findByMemberIdIn(Collection<String> memberIds);

  /**
   * 계정 행을 잠근다(SELECT … FOR UPDATE). 크레딧의 모든 증감이 이 잠금 안에서 일어난다.
   *
   * <p>같은 회원의 동시 요청 둘(잔액 1)이 둘 다 예약에 성공하지 않게 한 줄로 세운다 — 서버가 여러 대여도 DB 가 세운다.
   */
  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("select a from AiCreditAccount a where a.id = :id")
  Optional<AiCreditAccount> findByIdForUpdate(@Param("id") String id);

  /**
   * 회원의 계정 행을 잠가 읽는다. 잠그지 않은 조회를 먼저 하면 그 인스턴스가 1차 캐시에 남아 잠금 뒤에도
   * 잠그기 전 상태(예: 동결 전)를 돌려준다 — 처음 읽기부터 잠근다.
   */
  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("select a from AiCreditAccount a where a.memberId = :memberId")
  Optional<AiCreditAccount> findByMemberIdForUpdate(@Param("memberId") String memberId);

  /**
   * 완전 삭제된 회원의 식별자와 소셜 신원 해시를 뗀다. 행·원장은 운영 지표로 남긴다(ai_call_log 와 같다).
   *
   * <p>해시까지 비우는 이유 — 방침 4조는 탈퇴 정보를 1년 보관한 뒤 파기한다. 1년 안의 재가입은 같은 계정이
   * 복원돼 장부가 member_id 로 이어지므로, 보관 기간이 지난 뒤에 해시를 남길 근거가 없다.
   *
   * <p>member 에 외래키가 없어 DB 가 대신 처리해 주지 않는다.
   */
  @Modifying(clearAutomatically = true, flushAutomatically = true)
  @Query("update AiCreditAccount a set a.memberId = null, a.identityKey = null where a.memberId = :memberId")
  int detachMember(@Param("memberId") String memberId);
}
