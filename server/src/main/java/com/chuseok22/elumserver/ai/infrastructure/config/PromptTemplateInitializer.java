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
      promptTemplateRepository.save(template);
      log.info("[PromptTemplateInitializer] 프롬프트 기본값 생성 완료: {}", key);
    });
  }
}
