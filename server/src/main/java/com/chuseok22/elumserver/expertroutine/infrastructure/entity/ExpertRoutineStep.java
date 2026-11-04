package com.chuseok22.elumserver.expertroutine.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/**
 * 전문가 일과의 카드 1장: 문장 하나 + 번들 그림 id (픽토그램·예시 이미지)
 * 그림 표시 우선순위는 일과 카드와 같음: 예시 이미지 > 픽토그램
 */
@Entity
@Getter
@Setter
@Table(
  name = "expert_routine_step",
  indexes = @Index(name = "idx_expert_routine_step_routine_order", columnList = "expert_routine_id, step_order")
)
public class ExpertRoutineStep extends BaseEntity {

  /// 카드 문장 최대 글자 수
  public static final int TEXT_MAX_LENGTH = 200;

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(name = "expert_routine_id", nullable = false)
  private String expertRoutineId;

  // 0부터
  @Column(name = "step_order", nullable = false)
  private int stepOrder;

  @Column(nullable = false, length = TEXT_MAX_LENGTH)
  private String text;

  // pictograms/catalog.json 의 id. 없으면 null
  @Column(name = "pictogram_id", length = 100)
  private String pictogramId;

  // 앱 번들 예시 이미지 id. 모르는 앱은 픽토그램으로 대신함. 없으면 null
  @Column(name = "example_image_id", length = 100)
  private String exampleImageId;
}
