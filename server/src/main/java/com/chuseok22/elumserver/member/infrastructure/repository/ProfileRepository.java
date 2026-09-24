package com.chuseok22.elumserver.member.infrastructure.repository;

import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ProfileRepository extends JpaRepository<Profile, String> {

  /**
   * 계정의 기본 프로필.
   *
   * <p>계정당 프로필이 하나인 동안 기존 API가 "이 요청자의 당사자"를 찾는 통로다.
   * 여럿이 되면 호출부가 프로필을 명시하게 바꾼다.
   */
  Optional<Profile> findFirstByMemberIdOrderByCreatedAtAsc(String memberId);

  List<Profile> findAllByMemberId(String memberId);

  /** 관리자 목록용 배치 조회 — 회원 수만큼 쿼리가 나가지 않게 한다. */
  List<Profile> findAllByMemberIdIn(java.util.Collection<String> memberIds);

  void deleteAllByMemberId(String memberId);

  /**
   * 이룸이 행을 잠그고 읽는다 (다중 보호자 E15 · E17).
   *
   * <p>나가기와 AI 일과 저장이 같은 이룸이를 두고 겹치면 "남은 보호자 수"와 "아직 연결돼 있나"를 서로
   * 옛 값으로 본다. 둘 다 이 행을 먼저 잠가 차례로 줄 세운다.
   */
  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("select p from Profile p where p.id = :id")
  Optional<Profile> findByIdForUpdate(@Param("id") String id);

  /**
   * 이 보호자가 연결된 이룸이들, 먼저 합류한 차례로 (다중 보호자 4-4).
   *
   * <p>첫 번째가 "기본 이룸이"다 — 헤더 없이 부르는 지금 앱이 보는 이룸이. {@code g.profile} 을 바로
   * 고르므로 지연 프록시가 아니라 채워진 엔티티가 온다(트랜잭션 밖 AI 생성 경로가 그대로 쓴다).
   */
  @Query("select g.profile from ProfileGuardian g where g.member.id = :memberId order by g.joinedAt asc, g.profile.id asc")
  List<Profile> findAllGuardedBy(@Param("memberId") String memberId);
}
