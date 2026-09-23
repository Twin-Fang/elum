package com.chuseok22.elumserver.member.infrastructure.repository;

import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface MemberRepository extends JpaRepository<Member, String> {

  boolean existsByUsername(String username);

  Optional<Member> findByUsername(String username);

  Page<Member> findByStatus(MemberStatus status, Pageable pageable);

  // 아이 별명은 Member가 아니라 Profile에 있다. 계정 하나에 프로필이 여럿이 돼도
  // 결과가 중복되지 않도록 join 대신 exists를 쓴다.
  //
  // 별명이 null인 프로필은 like가 null(불일치)로 평가돼 자연스럽게 제외된다.
  @Query("""
    select m from Member m
    where lower(m.username) like lower(concat('%', :keyword, '%'))
       or exists (
         select 1 from Profile p
         where p.member = m
           and lower(p.nickname) like lower(concat('%', :keyword, '%'))
       )
    """)
  Page<Member> searchByKeyword(@Param("keyword") String keyword, Pageable pageable);

  @Query("""
    select m from Member m
    where (lower(m.username) like lower(concat('%', :keyword, '%'))
       or exists (
         select 1 from Profile p
         where p.member = m
           and lower(p.nickname) like lower(concat('%', :keyword, '%'))
       ))
      and m.status = :status
    """)
  Page<Member> searchByKeywordAndStatus(
    @Param("keyword") String keyword, @Param("status") MemberStatus status, Pageable pageable
  );

  long countByStatus(MemberStatus status);

  // --- 탈퇴 계정 (이슈 #372) ---
  // 탈퇴해도 행이 남으므로, 탈퇴 전처럼 "회원"을 세고 보여주려면 WITHDRAWN 을 빼야 한다.

  Page<Member> findByStatusNot(MemberStatus status, Pageable pageable);

  @Query("""
    select m from Member m
    where (lower(m.username) like lower(concat('%', :keyword, '%'))
       or exists (
         select 1 from Profile p
         where p.member = m
           and lower(p.nickname) like lower(concat('%', :keyword, '%'))
       ))
      and m.status <> :status
    """)
  Page<Member> searchByKeywordAndStatusNot(
    @Param("keyword") String keyword, @Param("status") MemberStatus status, Pageable pageable
  );

  long countByStatusNot(MemberStatus status);

  long countByLastActivityAtAfterAndStatusNot(LocalDateTime after, MemberStatus status);

  /**
   * 보관 기간이 지난 탈퇴 계정. 완전 삭제 스케줄러가 쓴다.
   *
   * <p>탈퇴 시각이 비어 있는 탈퇴 계정도 고른다 — 언제 탈퇴했는지 모르면 보관 기간 안이라고
   * 말할 수 없다.
   */
  @Query("""
    select m.id from Member m
    where m.status = :status
      and (m.withdrawnAt is null or m.withdrawnAt <= :threshold)
    """)
  List<String> findWithdrawnIdsUntil(
    @Param("status") MemberStatus status, @Param("threshold") LocalDateTime threshold
  );

  // 최근 활동 회원수(대시보드) — lastActivityAt 기준.
  long countByLastActivityAtAfter(LocalDateTime after);
}
