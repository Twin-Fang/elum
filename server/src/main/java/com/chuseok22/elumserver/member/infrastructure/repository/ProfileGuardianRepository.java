package com.chuseok22.elumserver.member.infrastructure.repository;

import com.chuseok22.elumserver.member.infrastructure.entity.ProfileGuardian;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface ProfileGuardianRepository extends JpaRepository<ProfileGuardian, String> {

  /** 이 보호자가 이 이룸이에 연결돼 있는가. 권한 판단의 바닥이다. */
  boolean existsByProfileIdAndMemberId(String profileId, String memberId);

  Optional<ProfileGuardian> findByProfileIdAndMemberId(String profileId, String memberId);

  /** 이 이룸이를 돌보는 사람들, 먼저 합류한 차례로. 대표 보호자 넘기기가 첫 사람을 쓴다. */
  List<ProfileGuardian> findAllByProfileIdOrderByJoinedAtAsc(String profileId);

  /** 이 보호자가 연결된 이룸이 id 들. 탈퇴가 하나씩 나가기를 부른다. */
  @Query("select g.profile.id from ProfileGuardian g where g.member.id = :memberId")
  List<String> findProfileIdsByMemberId(@Param("memberId") String memberId);

  /**
   * 관계가 하나도 없는 프로필에 대표 보호자로 관계를 채운다 — V25 의 채우기와 같은 문장이다.
   *
   * <p>새 서버에서 관계 없는 프로필은 생길 수 없다(가입이 함께 만들고, 마지막 보호자가 나가면 프로필도
   * 지운다). 그러니 관계가 없으면 옛 서버가 만든 것이다. 채울 것이 없으면 0 행이라 부팅마다 돌아도 된다.
   * UUID 는 {@code ::text} 대신 cast 로 만든다 — 네이티브 쿼리에서 {@code :text} 가 파라미터로 읽힌다.
   */
  @Transactional
  @Modifying
  @Query(nativeQuery = true, value = """
    insert into profile_guardian (id, profile_id, member_id, kind, joined_at, created_at, updated_at)
    select cast(gen_random_uuid() as varchar), p.id, p.member_id, 'GUARDIAN', coalesce(p.created_at, now()), now(), now()
    from profile p
    where p.member_id is not null
      and not exists (select 1 from profile_guardian g where g.profile_id = p.id)
    """)
  int backfillFromProfileOwner();
}
