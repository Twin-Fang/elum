package com.chuseok22.elumserver.ai.application.service;

import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplate;
import com.chuseok22.elumserver.ai.infrastructure.repository.PromptTemplateRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import java.util.Comparator;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class PromptTemplateService {

  private final PromptTemplateRepository promptTemplateRepository;

  public String getContent(PromptKey key) {
    return findOrThrow(key).getContent();
  }

  // PromptKey 선언 순서(로컬 LLM -> 텍스트 -> 이미지)대로 관리자 화면에 고정 표시하기 위해 정렬한다.
  public List<PromptTemplate> getAll() {
    return promptTemplateRepository.findAll().stream()
      .sorted(Comparator.comparing(template -> template.getPromptKey().ordinal()))
      .toList();
  }

  @Transactional
  public void update(PromptKey key, String content) {
    findOrThrow(key).setContent(content);
  }

  private PromptTemplate findOrThrow(PromptKey key) {
    return promptTemplateRepository.findByPromptKey(key)
      .orElseThrow(() -> new CustomException(ErrorCode.PROMPT_TEMPLATE_NOT_FOUND));
  }
}
