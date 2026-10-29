package com.chuseok22.elumserver.talk.infrastructure.entity;

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
 * 이야기 글의 카드 1장: 글을 올릴 때의 스냅샷 (원본 일과를 고쳐도 글은 그대로)
 * 그림 표시 우선순위는 일과 카드와 같음: 올린 그림(imageKey) > 예시 이미지 > 픽토그램
 */
@Entity
@Getter
@Setter
@Table(
  name = "talk_post_step",
  indexes = @Index(name = "idx_talk_post_step_post_order", columnList = "post_id, step_order")
)
public class TalkPostStep extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(name = "post_id", nullable = false)
  private String postId;

  // 0부터
  @Column(name = "step_order", nullable = false)
  private int stepOrder;

  @Column(columnDefinition = "TEXT")
  private String title;

  @Column(nullable = false, columnDefinition = "TEXT")
  private String description;

  // 글 전용으로 복사해 둔 그림 저장 열쇠. 없으면 null
  @Column(name = "image_key")
  private String imageKey;

  @Column(name = "pictogram_id", length = 100)
  private String pictogramId;

  @Column(name = "example_image_id", length = 100)
  private String exampleImageId;

  // 사람 얼굴이 들어 있어 흐리게 보여줄 그림인가
  @Column(name = "is_blurred", nullable = false)
  private boolean isBlurred;
}
