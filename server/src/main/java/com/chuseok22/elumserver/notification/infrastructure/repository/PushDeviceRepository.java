package com.chuseok22.elumserver.notification.infrastructure.repository;

import com.chuseok22.elumserver.notification.infrastructure.entity.PushDevice;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

public interface PushDeviceRepository extends JpaRepository<PushDevice, String> {

  Optional<PushDevice> findByToken(String token);

  List<PushDevice> findAllByMemberId(String memberId);

  /// 푸시 서버가 무효 토큰이라고 답한 기기 정리 (발송 흐름과 분리된 새 트랜잭션: 호출 쪽 트랜잭션이 끝난 뒤여도 커밋)
  @Transactional(propagation = Propagation.REQUIRES_NEW)
  void deleteByToken(String token);

  /// 탈퇴·완전 삭제: 회원의 기기 전부
  int deleteAllByMemberId(String memberId);
}
