package com.chuseok22.elumserver.ai.application.service;

import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplate;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplateHistory;
import com.chuseok22.elumserver.ai.infrastructure.repository.PromptTemplateHistoryRepository;
import com.chuseok22.elumserver.ai.infrastructure.repository.PromptTemplateRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import java.util.Arrays;
import java.util.Comparator;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 프롬프트 템플릿: (키, 언어) 조회, 대체 순서, 언어별 수정·이력, 언어 준비도
 * 조회는 요청 언어 > en > ko 로 내려가고(ko 요청은 ko 만), 관리자용 조회·수정은 정확히 그 행만 본다
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class PromptTemplateService {

  private final PromptTemplateRepository promptTemplateRepository;
  private final PromptTemplateHistoryRepository promptTemplateHistoryRepository;

  // 지금 일과 언어(AiCallContext)의 행: 호출부가 언어를 몰라도 일과 언어를 따른다
  public String getContent(PromptKey key) {
    return getContent(key, AiCallContext.currentContentLocale());
  }

  public String getContent(PromptKey key, AppLocale locale) {
    return resolve(key, locale).getContent();
  }

  public PromptTemplate getTemplate(PromptKey key) {
    return getTemplate(key, AppLocale.KO);
  }

  // 관리자용: 대체 없이 정확히 그 행
  public PromptTemplate getTemplate(PromptKey key, AppLocale locale) {
    return findExact(key, locale);
  }

  public List<PromptTemplateHistory> getHistory(PromptKey key) {
    return getHistory(key, AppLocale.KO);
  }

  public List<PromptTemplateHistory> getHistory(PromptKey key, AppLocale locale) {
    return promptTemplateHistoryRepository.findTop50ByPromptKeyAndLocaleOrderByCreatedAtDesc(key, locale.code());
  }

  // 현재 적용본을 마지막으로 저장한 관리자 (키별, 이력이 없거나 수정자가 없으면 빠짐)
  public Map<PromptKey, String> getLatestChangerByKey(AppLocale locale) {
    Map<PromptKey, String> changerByKey = new EnumMap<>(PromptKey.class);
    for (PromptTemplateHistory history : promptTemplateHistoryRepository.findLatestPerPromptKey(locale.code())) {
      if (history.getChangedBy() != null) {
        changerByKey.put(history.getPromptKey(), history.getChangedBy());
      }
    }
    return changerByKey;
  }

  public List<PromptTemplate> getAll() {
    return getAll(AppLocale.KO);
  }

  // PromptKey 선언 순서(로컬 LLM -> 텍스트 -> 이미지)대로 관리자 화면에 고정 표시하기 위해 정렬한다.
  // 행이 키 수 × 언어 수(수십 건)라 전부 읽어 언어로 거른다.
  public List<PromptTemplate> getAll(AppLocale locale) {
    return promptTemplateRepository.findAll().stream()
      .filter(template -> locale.code().equals(template.getLocale()))
      .sorted(Comparator.comparing(template -> template.getPromptKey().ordinal()))
      .toList();
  }

  // 그 언어에 있어야 하는데 없는 행: ko 는 모든 키, 그 밖은 언어별 행이 필요한 키만 (그림 지시문은 ko 행 하나)
  public List<PromptKey> missingKeys(AppLocale locale) {
    return Arrays.stream(PromptKey.values())
      .filter(key -> locale == AppLocale.KO || key.isLocalized())
      .filter(key -> promptTemplateRepository.findByPromptKeyAndLocale(key, locale.code()).isEmpty())
      .toList();
  }

  @Transactional
  public void update(PromptKey key, String content) {
    update(key, AppLocale.KO, content);
  }

  // 덮어쓰기 전에 직전 내용을 그 언어 이력으로 남긴다(같은 트랜잭션 — 이력 없는 덮어쓰기는 불가능).
  // 내용이 같으면 이력을 만들지 않아 무의미한 버전이 쌓이는 것을 막는다.
  // 없는 행은 만들지 않는다(행 만들기는 시더의 일)
  @Transactional
  public void update(PromptKey key, AppLocale locale, String content) {
    update(key, locale, content, null);
  }

  // changedBy: 저장한 관리자 이름, 이력에 함께 남긴다 (알 수 없으면 null)
  @Transactional
  public void update(PromptKey key, AppLocale locale, String content, String changedBy) {
    // 공백만 있는 프롬프트는 받지 않는다. 받아 주면 그 프롬프트를 쓰는 AI 호출이 지시 없이
    // 나가는데, 민감정보 검사 프롬프트라면 무엇을 가려야 하는지도 모른 채 돈다. 요청 DTO에는 검증 어노테이션을
    // 달지 않는 규칙이라 여기서 막는다.
    if (content == null || content.isBlank()) {
      throw new CustomException(ErrorCode.PROMPT_TEMPLATE_BLANK);
    }
    PromptTemplate template = findExact(key, locale);
    // 브라우저 textarea는 줄바꿈을 CRLF로 제출한다 — 정규화하지 않으면 저장만 눌러도
    // 바이트가 달라져 가짜 이력이 쌓이고, 프롬프트에 CR이 섞여 들어간다.
    String normalizedContent = content.replace("\r\n", "\n");
    if (Objects.equals(template.getContent(), normalizedContent)) {
      return;
    }
    PromptTemplateHistory history = new PromptTemplateHistory();
    history.setPromptKey(key);
    history.setLocale(locale.code());
    history.setContent(template.getContent());
    history.setChangedBy(changedBy);
    promptTemplateHistoryRepository.save(history);
    template.setContent(normalizedContent);
  }

  // 대체 순서(요청 > en > ko)로 행 선택, 대체가 일어나면 오류 로그 (키·언어 코드만, 내용 제외)
  private PromptTemplate resolve(PromptKey key, AppLocale requested) {
    // 언어 중립 키는 ko 행 하나
    AppLocale effective = key.isLocalized() ? requested : AppLocale.KO;
    // fallbackChain 은 KO 에서 [KO] 하나라 한국어 사용자에게 영어 지시문이 나가지 않는다
    for (AppLocale candidate : effective.fallbackChain()) {
      Optional<PromptTemplate> row = promptTemplateRepository.findByPromptKeyAndLocale(key, candidate.code());
      if (row.isPresent()) {
        if (candidate != effective) {
          log.error("[PROMPT_LOCALE_FALLBACK] key={} requested={} used={}", key, effective.code(), candidate.code());
        }
        return row.get();
      }
    }
    throw new CustomException(ErrorCode.PROMPT_TEMPLATE_NOT_FOUND);
  }

  private PromptTemplate findExact(PromptKey key, AppLocale locale) {
    return promptTemplateRepository.findByPromptKeyAndLocale(key, locale.code())
      .orElseThrow(() -> new CustomException(ErrorCode.PROMPT_TEMPLATE_NOT_FOUND));
  }
}
