package com.chuseok22.elumserver.link.infrastructure.repository;

import com.chuseok22.elumserver.link.infrastructure.entity.DeviceLink;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface DeviceLinkRepository extends JpaRepository<DeviceLink, String> {

  Optional<DeviceLink> findByCodeHash(String codeHash);

  /** 이 계정의 살아 있는 연결·발급분. 최신이 앞에 온다. */
  List<DeviceLink> findByMemberIdAndRevokedAtIsNullOrderByCreatedAtDesc(String memberId);

  /** 탈퇴 시 정리. member를 외래키로 참조하지 않아 DB가 대신 지워 주지 않는다. */
  void deleteAllByMemberId(String memberId);
}
