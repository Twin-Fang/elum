package com.chuseok22.elumserver.systemconfig.infrastructure.config;

import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.chuseok22.elumserver.systemconfig.infrastructure.entity.SystemConfig;
import com.chuseok22.elumserver.systemconfig.infrastructure.repository.SystemConfigRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

// PromptTemplateInitializer와 동일한 패턴 — 없는 키만 기본값으로 시딩하고
// 이미 존재하는 키(관리자가 바꾼 값)는 절대 덮어쓰지 않는다.
@Component
@RequiredArgsConstructor
@Slf4j
public class SystemConfigInitializer implements ApplicationRunner {

  private final SystemConfigRepository systemConfigRepository;
  private final SystemConfigService systemConfigService;

  @Override
  public void run(ApplicationArguments args) {
    for (ConfigKey key : ConfigKey.values()) {
      if (systemConfigRepository.findByConfigKey(key).isPresent()) {
        continue;
      }
      SystemConfig config = new SystemConfig();
      config.setConfigKey(key);
      config.setConfigValue(systemConfigService.defaultValueFor(key));
      systemConfigRepository.save(config);
      log.info("[SystemConfigInitializer] 시스템 설정 기본값 생성: {}={}", key, config.getConfigValue());
    }
  }
}
