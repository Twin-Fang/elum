package com.chuseok22.elumserver.link.infrastructure.repository;

import com.chuseok22.elumserver.link.infrastructure.entity.DeviceLink;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface DeviceLinkRepository extends JpaRepository<DeviceLink, String> {

  Optional<DeviceLink> findByCodeHash(String codeHash);

  /** 이 계정의 살아 있는 연결·발급분. 최신이 앞에 온다. */
  List<DeviceLink> findByMemberIdAndRevokedAtIsNullOrderByCreatedAtDesc(String memberId);

  /** 이 이룸이에 붙은 살아 있는 연결·발급분. 함께 돌보는 보호자가 서로의 휴대폰을 보고 끊는다. */
  List<DeviceLink> findByProfileIdAndRevokedAtIsNullOrderByCreatedAtDesc(String profileId);

  /** 탈퇴 시 정리. member를 외래키로 참조하지 않아 DB가 대신 지워 주지 않는다. */
  void deleteAllByMemberId(String memberId);

  /** 이 보호자가 이 이룸이에 붙인 휴대폰들. 나가면 끊는다 (다중 보호자 E13). */
  List<DeviceLink> findAllByMemberIdAndProfileId(String memberId, String profileId);

  /** 이 이룸이에 붙은 휴대폰 전부. 마지막 보호자가 나가 이룸이를 지울 때 함께 치운다. */
  List<DeviceLink> findAllByProfileId(String profileId);

  /** 관리자 회원 상세: 이룸이들의 연결·발급 기록 전부 (최신순) */
  List<DeviceLink> findAllByProfileIdInOrderByCreatedAtDesc(Collection<String> profileIds);

  /** 리텐션 알림 (#1409): 이 이룸이들 중 이룸이 기기가 지금 연결된(암호를 썼고 안 끊긴) 이룸이 id */
  @Query("""
    select distinct d.profileId from DeviceLink d
    where d.profileId in :profileIds and d.redeemedAt is not null and d.revokedAt is null
    """)
  List<String> findLinkedProfileIdsAmong(@Param("profileIds") Collection<String> profileIds);
}
