package com.chuseok22.elumserver.routine.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.Setter;

/// 규칙을 뒷받침한 일과 한 건 (V71): (규칙, 일과) 유일 > 같은 일과는 한 번만 셈. 제목은 화면용 사본이라 AI 로 보내지 않음
@Entity
@Getter
@Setter
@Table(name = "routine_memory_evidence")
public class RoutineMemoryEvidence extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(name = "rule_id", nullable = false)
  private String ruleId;

  @Column(name = "routine_id", nullable = false)
  private String routineId;

  @Column(name = "routine_title")
  private String routineTitle;

  @Column(name = "observed_at", nullable = false)
  private LocalDateTime observedAt;
}
