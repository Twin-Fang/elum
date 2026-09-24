package com.chuseok22.elumserver.member.infrastructure.repository;

import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ProfileRepository extends JpaRepository<Profile, String> {

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

  /**
   * 별을 더하거나 뺀다. <b>별은 이 쿼리로만 바꾼다</b> (다중 보호자 E25).
   *
   * <p>엔티티 값을 읽어 더해 저장하면 두 기기(보호자 폰의 이룸이 화면과 이룸이 폰)가 동시에 체크할 때
   * 하나가 사라진다. 한 문장으로 더하면 DB 가 차례를 맞춘다. 0 아래로는 내려가지 않는다 — 예전
   * {@code Math.max(0, …)} 와 같은 규칙이다.
   *
   * <p>flush·clear 를 켜지 않는다. 이 UPDATE 가 이룸이 행을 먼저 잠그고 단계 변경은 커밋 때 나가야
   * 나가기(이룸이 행 잠금 → 일과 삭제)와 잠금 순서가 같아 교착이 없다.
   */
  @Modifying
  @Query("update Profile p set p.totalStars = case when p.totalStars + :delta < 0 then 0 else p.totalStars + :delta end "
    + "where p.id = :profileId")
  int addStars(@Param("profileId") String profileId, @Param("delta") int delta);
}
