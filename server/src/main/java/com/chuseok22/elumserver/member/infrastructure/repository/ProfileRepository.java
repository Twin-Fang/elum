package com.chuseok22.elumserver.member.infrastructure.repository;

import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

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
}
