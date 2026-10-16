package com.chuseok22.elumserver.ai.infrastructure.config;

import com.chuseok22.elumserver.ai.application.service.PromptTemplateSeeder;
import com.chuseok22.elumserver.common.locale.AppLocale;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
public class PromptTemplateInitializer implements ApplicationRunner {

  private final PromptTemplateSeeder promptTemplateSeeder;

  @Override
  public void run(ApplicationArguments args) {
    // ko 만 시딩: 다른 언어 행은 관리자가 만들며, 행 유무가 그 언어를 켤 준비 여부의 기준
    PromptTemplateSeeder.SeedResult result = promptTemplateSeeder.seed(AppLocale.KO);
    log.info("[PromptTemplateInitializer] ko seeding : created={}, skipped={}, failed={}",
      result.created(), result.skipped(), result.failed());
  }
}
