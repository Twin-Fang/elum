package com.chuseok22.elumserver.ai.application.service;

import com.chuseok22.elumserver.ai.core.MultilingualPromptDefaults;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplate;
import com.chuseok22.elumserver.ai.infrastructure.repository.PromptTemplateRepository;
import com.chuseok22.elumserver.common.locale.AppLocale;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 프롬프트 기본값 시딩: 한 언어의 기본값을 없는 행에만 넣음
 * 기동 때는 ko 만 호출, 다른 언어는 관리자 화면의 "기본값으로 행 만들기"가 호출
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class PromptTemplateSeeder {

  private final PromptTemplateRepository promptTemplateRepository;

  // created: 새로 넣은 행, skipped: 이미 있어 건드리지 않은 행, failed: 저장 실패
  public record SeedResult(int created, int skipped, int failed) {

  }

  /**
   * 언어별 기본값 시딩: 키별 기본값 조회 > 기존 행 확인 > 없으면 저장 (있는 행은 수정하지 않음)
   */
  public SeedResult seed(AppLocale locale) {
    int created = 0;
    int skipped = 0;
    int failed = 0;
    for (PromptKey key : PromptKey.values()) {
      Optional<String> defaultContent = MultilingualPromptDefaults.forLocale(key, locale);
      if (defaultContent.isEmpty()) {
        continue; // 이 언어에 행이 필요 없는 키
      }
      if (promptTemplateRepository.findByPromptKeyAndLocale(key, locale.code()).isPresent()) {
        log.info("[PromptTemplateSeeder] {} skipped existing : {}", locale.code(), key);
        skipped++;
        continue;
      }

      PromptTemplate template = new PromptTemplate();
      template.setPromptKey(key);
      template.setLocale(locale.code());
      template.setContent(defaultContent.get());
      // 키 하나가 실패해도 기동을 막지 않음 (ddl-auto 로 만든 테이블의 옛 키 목록 CHECK 제약이 새 키를 거절할 수 있음)
      try {
        promptTemplateRepository.save(template);
        created++;
        log.info("[PromptTemplateSeeder] {} created : {}", locale.code(), key);
      } catch (RuntimeException e) {
        failed++;
        log.error("[PromptTemplateSeeder] {} failed to seed : {}", locale.code(), key, e);
      }
    }
    return new SeedResult(created, skipped, failed);
  }
}
