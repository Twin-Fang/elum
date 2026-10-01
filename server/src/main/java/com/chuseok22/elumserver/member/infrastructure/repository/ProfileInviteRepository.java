package com.chuseok22.elumserver.member.infrastructure.repository;

import com.chuseok22.elumserver.member.infrastructure.entity.ProfileInvite;
import jakarta.persistence.LockModeType;
import java.time.LocalDateTime;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ProfileInviteRepository extends JpaRepository<ProfileInvite, String> {

  /**
   * 이 해시를 가진 코드들의 이룸이 id — 쓸 수 있는 것을 앞에 둔다.
   *
   * <p><b>행이 아니라 값만 읽는다.</b> 이 조회는 이룸이 행을 잠그기 전이라 값이 옛것일 수 있다. 엔티티로 읽으면
   * 영속성 컨텍스트에 상태가 남아, 잠근 뒤 다시 읽어도 옛 상태를 돌려받는다 — 동시에 같은 코드를 넣은 두 사람이
   * 둘 다 "아직 안 쓴 코드"로 보게 된다 (E3). 값만 읽고, 잠근 뒤에 행을 새로 읽는다.
   */
  @Query("""
    select i.profileId from ProfileInvite i where i.codeHash = :codeHash
    order by case when i.redeemedAt is null and i.revokedAt is null then 0 else 1 end, i.createdAt desc
    """)
  List<String> findProfileIdsByCodeHash(@Param("codeHash") String codeHash);

  /**
   * 이룸이 행을 잠근 뒤 이 코드 행을 잠그고 읽는다 (E3). 같은 해시가 다른 이룸이에 있을 수 있어 이룸이로 좁힌다.
   * 가장 최근 것이 앞에 온다.
   */
  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("select i from ProfileInvite i where i.codeHash = :codeHash and i.profileId = :profileId "
    + "order by i.createdAt desc")
  List<ProfileInvite> findAllByCodeHashAndProfileIdForUpdate(
    @Param("codeHash") String codeHash, @Param("profileId") String profileId);

  /** 이 사람이 이 이룸이에 낸, 아직 쓰이지도 폐기되지도 않은 코드. 새로 내거나 나갈 때 폐기한다. */
  List<ProfileInvite> findAllByProfileIdAndIssuedByAndRedeemedAtIsNullAndRevokedAtIsNull(
    String profileId, String issuedBy);

  /** 이룸이를 지울 때 그 이룸이의 초대 코드를 모두 치운다. 쓰인 기록까지 — 이룸이가 없으면 의미가 없다. */
  void deleteAllByProfileId(String profileId);

  /** 같은 해시의 쓸 수 있는 코드가 이미 있는가. 새 코드가 겹치지 않게 발급 때 본다. */
  boolean existsByCodeHashAndRedeemedAtIsNullAndRevokedAtIsNullAndExpiresAtAfter(
    String codeHash, LocalDateTime now);
}
