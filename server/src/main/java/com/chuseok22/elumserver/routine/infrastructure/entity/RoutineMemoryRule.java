package com.chuseok22.elumserver.routine.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleSource;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleStatus;
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

/**
 * AI 메모리 규칙 (V71): 보호자 한 사람 x 이룸이 한 명의 카드 만들기 규칙 하나
 * 다른 보호자에게 보이지도 쓰이지도 않음. 이룸이·보호자 삭제 시 DB 가 함께 지움
 */
@Entity
@Getter
@Setter
@Table(name = "routine_memory_rule")
public class RoutineMemoryRule extends BaseEntity {

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

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private RoutineMemoryRuleStatus status;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private RoutineMemoryRuleSource source;

  /// 일과 만들 때 AI 에 넣는 한 줄 (WORD 는 "before 대신 after")
  @Column(nullable = false)
  private String summary;

  @Column(name = "before_text")
  private String beforeText;

  @Column(name = "after_text")
  private String afterText;

  /// 서로 다른 일과에서 관찰된 수 (근거 표 행 수와 같음)
  @Column(name = "evidence_count", nullable = false)
  private int evidenceCount;
}
