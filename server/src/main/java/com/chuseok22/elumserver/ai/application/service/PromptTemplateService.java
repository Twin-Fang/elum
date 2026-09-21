package com.chuseok22.elumserver.ai.application.service;

import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplate;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplateHistory;
import com.chuseok22.elumserver.ai.infrastructure.repository.PromptTemplateHistoryRepository;
import com.chuseok22.elumserver.ai.infrastructure.repository.PromptTemplateRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class PromptTemplateService {

  private final PromptTemplateRepository promptTemplateRepository;
  private final PromptTemplateHistoryRepository promptTemplateHistoryRepository;

  public String getContent(PromptKey key) {
    return findOrThrow(key).getContent();
  }

  public PromptTemplate getTemplate(PromptKey key) {
    return findOrThrow(key);
  }

  public List<PromptTemplateHistory> getHistory(PromptKey key) {
    return promptTemplateHistoryRepository.findTop50ByPromptKeyOrderByCreatedAtDesc(key);
  }

  // PromptKey 선언 순서(로컬 LLM -> 텍스트 -> 이미지)대로 관리자 화면에 고정 표시하기 위해 정렬한다.
  public List<PromptTemplate> getAll() {
    return promptTemplateRepository.findAll().stream()
      .sorted(Comparator.comparing(template -> template.getPromptKey().ordinal()))
      .toList();
  }

  // 덮어쓰기 전에 직전 내용을 이력으로 남긴다(같은 트랜잭션 — 이력 없는 덮어쓰기는 불가능).
  // 내용이 같으면 이력을 만들지 않아 무의미한 버전이 쌓이는 것을 막는다.
  @Transactional
  public void update(PromptKey key, String content) {
    // 공백만 있는 프롬프트는 받지 않는다. 받아 주면 그 프롬프트를 쓰는 AI 호출이 지시 없이
    // 나가는데, 민감정보 검사 프롬프트라면 무엇을 가려야 하는지도 모른 채 돈다 (#278 QA에서
    // 로컬 민감정보 검사 프롬프트가 공백 3칸으로 저장됐다). 요청 DTO에는 검증 어노테이션을
    // 달지 않는 규칙이라 여기서 막는다.
    if (content == null || content.isBlank()) {
      throw new CustomException(ErrorCode.PROMPT_TEMPLATE_BLANK);
    }
    PromptTemplate template = findOrThrow(key);
    // 브라우저 textarea는 줄바꿈을 CRLF로 제출한다 — 정규화하지 않으면 저장만 눌러도
    // 바이트가 달라져 가짜 이력이 쌓이고, 프롬프트에 CR이 섞여 들어간다.
    content = content == null ? null : content.replace("\r\n", "\n");
    if (Objects.equals(template.getContent(), content)) {
      return;
    }
    PromptTemplateHistory history = new PromptTemplateHistory();
    history.setPromptKey(key);
    history.setContent(template.getContent());
    promptTemplateHistoryRepository.save(history);
    template.setContent(content);
  }

  private PromptTemplate findOrThrow(PromptKey key) {
    return promptTemplateRepository.findByPromptKey(key)
      .orElseThrow(() -> new CustomException(ErrorCode.PROMPT_TEMPLATE_NOT_FOUND));
  }
}
