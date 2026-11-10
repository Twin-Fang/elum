package com.chuseok22.elumserver.routine.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.routine.core.RoutineMemoryExtractionState;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.Setter;

/// 일과마다 한 줄의 수정 기록 (V71): 카드 수 전·후, 글이 바뀐 카드 수 (AI 없이 서버가 셈) + 규칙 찾기 진행 상태
@Entity
@Getter
@Setter
@Table(name = "routine_memory_edit")
public class RoutineMemoryEdit extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(name = "profile_id", nullable = false)
  private String profileId;

  @Column(name = "member_id", nullable = false)
  private String memberId;

  @Column(name = "routine_id", nullable = false, unique = true)
  private String routineId;

  @Column(name = "routine_title")
  private String routineTitle;

  @Column(name = "edited_at", nullable = false)
  private LocalDateTime editedAt;

  @Column(name = "card_count_before", nullable = false)
  private int cardCountBefore;

  @Column(name = "card_count_after", nullable = false)
  private int cardCountAfter;

  @Column(name = "changed_text_count", nullable = false)
  private int changedTextCount;

  @Enumerated(EnumType.STRING)
  @Column(name = "extraction_state", nullable = false, length = 20)
  private RoutineMemoryExtractionState extractionState = RoutineMemoryExtractionState.PENDING;
}
