package com.chuseok22.elumserver.ai.infrastructure.config;

import com.chuseok22.elumserver.ai.core.PromptDefaults;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplate;
import com.chuseok22.elumserver.ai.infrastructure.repository.PromptTemplateRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
public class PromptTemplateInitializer implements ApplicationRunner {

  private final PromptTemplateRepository promptTemplateRepository;

  @Override
  public void run(ApplicationArguments args) {
    PromptDefaults.DEFAULTS.forEach((key, defaultContent) -> {
      if (promptTemplateRepository.findByPromptKey(key).isPresent()) {
        log.info("[PromptTemplateInitializer] 이미 존재하는 프롬프트 스킵: {}", key);
        return;
      }

      PromptTemplate template = new PromptTemplate();
      template.setPromptKey(key);
      template.setContent(defaultContent);
      // 키 하나가 실패해도 기동을 막지 않는다. ddl-auto 로 만든 테이블에는 그때의 키 목록으로
      // CHECK 제약이 걸려 있어 새 키가 거절될 수 있다(V24 가 운영에서 이 제약을 걷는다). 예외를
      // 밖으로 내면 서버가 뜨지 않아 이미 돌던 기능까지 멈춘다. 실패한 키를 쓰는 기능만 실패한다.
      try {
        promptTemplateRepository.save(template);
        log.info("[PromptTemplateInitializer] 프롬프트 기본값 생성 완료: {}", key);
      } catch (RuntimeException e) {
        log.error("[PromptTemplateInitializer] 프롬프트 기본값을 넣지 못했습니다 — 이 키를 쓰는 기능은 실패합니다: {}",
          key, e);
      }
    });
  }
}
