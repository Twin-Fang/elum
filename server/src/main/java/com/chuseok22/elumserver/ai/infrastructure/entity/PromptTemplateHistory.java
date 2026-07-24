package com.chuseok22.elumserver.ai.infrastructure.entity;

import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/**
 * 프롬프트 수정 시 교체되기 직전의 content 스냅샷. append-only로만 쌓이며,
 * 현재 적용본은 항상 {@link PromptTemplate}에 있다.
 */
@Entity
@Getter
@Setter
@Table(
  name = "prompt_template_history",
  indexes = @Index(name = "idx_prompt_template_history_key_created", columnList = "prompt_key, created_at")
)
public class PromptTemplateHistory extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  private PromptKey promptKey;

  @Column(nullable = false, columnDefinition = "TEXT")
  private String content;
}
