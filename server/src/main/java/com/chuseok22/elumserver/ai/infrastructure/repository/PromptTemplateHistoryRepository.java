package com.chuseok22.elumserver.ai.infrastructure.repository;

import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplateHistory;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PromptTemplateHistoryRepository extends JpaRepository<PromptTemplateHistory, String> {

  // 이력은 append-only로 무한히 쌓이므로 화면에는 최근 50건까지만 보여준다.
  List<PromptTemplateHistory> findTop50ByPromptKeyOrderByCreatedAtDesc(PromptKey promptKey);
}
