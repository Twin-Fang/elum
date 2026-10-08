package com.chuseok22.elumserver.member.infrastructure.repository;

import com.chuseok22.elumserver.member.infrastructure.entity.ProfileGuardian;
import java.util.Collection;
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

  /** 계정 ID 와 이 이룸이 안에서 부르는 이름만 읽는 투영. 엔티티(이룸이·계정)를 불러오지 않는다. */
  interface GuardianName {

    String getMemberId();

    String getDisplayName();
  }

  /**
   * 일과 응답에 만든 사람 이름을 싣는다. 목록의 만든 사람들을 한 번에 묻는다 — 일과마다 묻지 않는다.
   * {@code g.member.id} 는 외래키 값이라 조인하지 않는다.
   */
  @Query("select g.member.id as memberId, g.displayName as displayName "
    + "from ProfileGuardian g where g.profile.id = :profileId and g.member.id in :memberIds")
  List<GuardianName> findNamesByProfileIdAndMemberIdIn(
    @Param("profileId") String profileId, @Param("memberIds") Collection<String> memberIds);

  /** 관리자 회원 목록 —회원마다 따로 묻지 않도록 이룸이까지 한 번에, 합류 순서대로 가져온다. */
  @Query("select g from ProfileGuardian g join fetch g.profile where g.member.id in :memberIds order by g.joinedAt asc")
  List<ProfileGuardian> findAllWithProfileByMemberIdIn(@Param("memberIds") Collection<String> memberIds);
}
