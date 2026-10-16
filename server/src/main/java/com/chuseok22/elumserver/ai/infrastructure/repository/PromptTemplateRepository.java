package com.chuseok22.elumserver.ai.infrastructure.repository;

import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplate;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PromptTemplateRepository extends JpaRepository<PromptTemplate, String> {

  // (키, 언어) 한 행. locale 은 AppLocale.code()
  Optional<PromptTemplate> findByPromptKeyAndLocale(PromptKey promptKey, String locale);
}
