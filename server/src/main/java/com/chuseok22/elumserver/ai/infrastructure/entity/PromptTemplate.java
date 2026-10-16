package com.chuseok22.elumserver.ai.infrastructure.entity;

import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.common.locale.AppLocale;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.Getter;
import lombok.Setter;

@Entity
@Getter
@Setter
@Table(
  name = "prompt_template",
  uniqueConstraints = @UniqueConstraint(name = "ux_prompt_template_key_locale", columnNames = {"prompt_key", "locale"})
)
public class PromptTemplate extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  private PromptKey promptKey;

  // 언어 코드(AppLocale.code()). 키 하나에 언어마다 한 행
  @Column(nullable = false, length = 8)
  private String locale = AppLocale.KO.code();

  @Column(nullable = false, columnDefinition = "TEXT")
  private String content;
}
