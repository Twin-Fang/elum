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
import lombok.Getter;
import lombok.Setter;

@Entity
@Getter
@Setter
public class PromptTemplate extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, unique = true)
  private PromptKey promptKey;

  @Column(nullable = false, columnDefinition = "TEXT")
  private String content;
}
