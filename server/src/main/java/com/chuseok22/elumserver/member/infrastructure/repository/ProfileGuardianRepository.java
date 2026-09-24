package com.chuseok22.elumserver.member.infrastructure.repository;

import com.chuseok22.elumserver.member.infrastructure.entity.ProfileGuardian;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ProfileGuardianRepository extends JpaRepository<ProfileGuardian, String> {

  /** 이 보호자가 이 이룸이에 연결돼 있는가. 권한 판단의 바닥이다. */
  boolean existsByProfileIdAndMemberId(String profileId, String memberId);

  Optional<ProfileGuardian> findByProfileIdAndMemberId(String profileId, String memberId);

  /** 이 이룸이를 돌보는 사람들, 먼저 합류한 차례로. 대표 보호자 넘기기가 첫 사람을 쓴다. */
  List<ProfileGuardian> findAllByProfileIdOrderByJoinedAtAsc(String profileId);

  /** 이 보호자가 연결된 이룸이 id 들. 탈퇴가 하나씩 나가기를 부른다. */
  @Query("select g.profile.id from ProfileGuardian g where g.member.id = :memberId")
  List<String> findProfileIdsByMemberId(@Param("memberId") String memberId);

  /** 탈퇴 정리 — 나가기 규칙(Task 5)이 들어오기 전까지만 쓴다. */
  void deleteAllByMemberId(String memberId);
}
