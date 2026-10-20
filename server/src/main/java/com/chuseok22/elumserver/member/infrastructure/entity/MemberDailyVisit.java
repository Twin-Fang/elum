package com.chuseok22.elumserver.member.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.LocalDate;
import lombok.Getter;
import lombok.Setter;

/**
 * 회원 하루 방문 1줄: (회원, 날짜) 하나. 관리자 방문 추이의 원천
 * 회원 FK 없음 (V47 과 같은 이유) — 탈퇴할 때 MemberService 가 지움
 */
@Entity
@Getter
@Setter
@Table(name = "member_daily_visit",
  uniqueConstraints = @UniqueConstraint(name = "uk_member_daily_visit_member_date", columnNames = {"member_id", "visit_date"}),
  indexes = @Index(name = "idx_member_daily_visit_date", columnList = "visit_date"))
public class MemberDailyVisit extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(name = "member_id", nullable = false)
  private String memberId;

  @Column(name = "visit_date", nullable = false)
  private LocalDate visitDate;
}
