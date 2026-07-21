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

  @Column(nullable = false)
  private String imagePath;

  @Column(nullable = false, columnDefinition = "boolean not null default false")
  private Boolean completed = false;

  private LocalDateTime completedAt;
}
