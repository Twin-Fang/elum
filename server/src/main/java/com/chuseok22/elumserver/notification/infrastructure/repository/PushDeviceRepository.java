package com.chuseok22.elumserver.notification.infrastructure.repository;

import com.chuseok22.elumserver.notification.infrastructure.entity.PushDevice;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PushDeviceRepository extends JpaRepository<PushDevice, String> {

  Optional<PushDevice> findByToken(String token);

  List<PushDevice> findAllByMemberIdIn(Collection<String> memberIds);

  /// 푸시 서버가 무효 토큰이라고 답한 기기 정리
  void deleteByToken(String token);

  /// 탈퇴·완전 삭제: 회원의 기기 전부
  int deleteAllByMemberId(String memberId);
}
