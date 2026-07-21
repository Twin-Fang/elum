package com.chuseok22.elumserver.routine.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.DynamicUpdate;

// description 단독 수정(PATCH .../steps/{stepId})과 completed 단독 수정(complete/cancel)이
// 동시에 들어올 때, DynamicUpdate 없이는 Hibernate가 전체 컬럼을 UPDATE해서 한쪽이 다른
// 쪽의 변경을 덮어쓸 수 있다(fable5 검토에서 발견). 변경된 컬럼만 UPDATE하도록 강제한다.
@DynamicUpdate
@Entity
@Getter
@Setter
public class RoutineStep extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "routine_id", nullable = false)
  private Routine routine;

  @Column(nullable = false)
  private Integer stepOrder;

  @Column(nullable = false, columnDefinition = "TEXT")
  private String description;

  // description과 별개로 카드에 표시할 짧은 라벨. NOT NULL로 만들면 기존에 이미 데이터가
  // 쌓인 routine_step 테이블에 ddl-auto: update가 "ALTER TABLE ... ADD COLUMN title TEXT
  // NOT NULL"을 시도하다 기존 행에 값이 없어 실패한다. 대신 nullable로 두고, 신규 생성
  // 경로는 RoutineAiPipeline.parseDraft()에서 blank 여부를 애플리케이션 레벨로 검증한다.
  // 이 변경 이전에 만들어진 기존 루틴은 title이 null로 남는다.
  @Column(columnDefinition = "TEXT")
  private String title;

  // AI 이미지 생성이 실패한 단계는 imagePath가 null로 남는다(V3 마이그레이션으로 NOT NULL 제거).
  // 이미지 하나가 실패해도 일과 전체 생성을 포기하지 않기 위함(루트 CLAUDE.md 서비스 원칙 6).
  // 조회 시 클라이언트가 null이면 이미지 자리를 비워 렌더링한다.
  private String imagePath;

  @Column(nullable = false, columnDefinition = "boolean not null default false")
  private Boolean completed = false;

  private LocalDateTime completedAt;
}
