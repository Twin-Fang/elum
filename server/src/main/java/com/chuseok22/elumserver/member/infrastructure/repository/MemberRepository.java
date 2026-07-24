package com.chuseok22.elumserver.member.infrastructure.repository;

import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import java.time.LocalDateTime;
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

  // nickname이 null인 회원은 like 결과가 null(불일치)로 평가돼 자연스럽게 제외된다.
  @Query("""
    select m from Member m
    where lower(m.username) like lower(concat('%', :keyword, '%'))
       or lower(m.nickname) like lower(concat('%', :keyword, '%'))
    """)
  Page<Member> searchByKeyword(@Param("keyword") String keyword, Pageable pageable);

  @Query("""
    select m from Member m
    where (lower(m.username) like lower(concat('%', :keyword, '%'))
       or lower(m.nickname) like lower(concat('%', :keyword, '%')))
      and m.status = :status
    """)
  Page<Member> searchByKeywordAndStatus(
    @Param("keyword") String keyword, @Param("status") MemberStatus status, Pageable pageable
  );

  long countByStatus(MemberStatus status);

  // 최근 활동 회원수(대시보드) — lastActivityAt 기준.
  long countByLastActivityAtAfter(LocalDateTime after);
}
