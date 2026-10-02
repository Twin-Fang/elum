package com.chuseok22.elumserver.systemconfig.infrastructure.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.chuseok22.elumserver.systemconfig.infrastructure.entity.SystemConfig;
import com.chuseok22.elumserver.systemconfig.infrastructure.repository.SystemConfigRepository;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class SystemConfigInitializerLocaleTest {

  @Test
  @DisplayName("처음 뜰 때 일과 생성 가능 언어를 ko 로 시딩한다")
  void seedsEnabledContentLocales() {
    SystemConfigRepository repository = mock(SystemConfigRepository.class);
    SystemConfigService service = mock(SystemConfigService.class);
    when(repository.findByConfigKey(any())).thenReturn(Optional.empty());
    when(service.defaultValueFor(any())).thenAnswer(invocation -> ((ConfigKey) invocation.getArgument(0)).getDefaultValue());

    new SystemConfigInitializer(repository, service).run(null);

    ArgumentCaptor<SystemConfig> saved = ArgumentCaptor.forClass(SystemConfig.class);
    verify(repository, atLeastOnce()).save(saved.capture());
    assertThat(saved.getAllValues())
      .filteredOn(config -> config.getConfigKey() == ConfigKey.ENABLED_CONTENT_LOCALES)
      .singleElement()
      .satisfies(config -> assertThat(config.getConfigValue()).isEqualTo("ko"));
  }

  @Test
  @DisplayName("관리자가 바꾼 값은 다시 뜰 때 덮어쓰지 않는다")
  void doesNotOverwriteExisting() {
    SystemConfigRepository repository = mock(SystemConfigRepository.class);
    SystemConfigService service = mock(SystemConfigService.class);
    SystemConfig existing = new SystemConfig();
    existing.setConfigKey(ConfigKey.ENABLED_CONTENT_LOCALES);
    existing.setConfigValue("ko,en");
    when(repository.findByConfigKey(any())).thenReturn(Optional.of(existing));

    new SystemConfigInitializer(repository, service).run(null);

    verify(repository, org.mockito.Mockito.never()).save(any());
    assertThat(existing.getConfigValue()).isEqualTo("ko,en");
  }
}
