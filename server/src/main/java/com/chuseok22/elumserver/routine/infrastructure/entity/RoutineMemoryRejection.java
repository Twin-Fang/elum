package com.chuseok22.elumserver.routine.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/// 보호자가 지운 규칙의 기억 (V71): 같은 (종류, before, after) 를 AI 가 다시 가져와도 되살리지 않음
@Entity
@Getter
@Setter
@Table(name = "routine_memory_rejection")
public class RoutineMemoryRejection extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(name = "profile_id", nullable = false)
  private String profileId;

  @Column(name = "member_id", nullable = false)
  private String memberId;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private RoutineMemoryRuleType type;

  @Column(name = "before_text")
  private String beforeText;

  @Column(name = "after_text")
  private String afterText;
}
