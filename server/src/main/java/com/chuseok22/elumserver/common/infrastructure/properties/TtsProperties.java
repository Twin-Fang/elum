package com.chuseok22.elumserver.common.infrastructure.properties;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 단계 음성 미리 만들기 설정 (#675)
 * AI 서버 주소·키는 local-llm 설정을 그대로 씀 (같은 AI 서버, 같은 키)
 *
 * @param enabled           false 면 예약·주기 작업 모두 끔 (없으면 켬)
 * @param speechStoragePath 음성 파일 폴더. 운영은 /app 마운트 아래라 재배포해도 남음
 */
@ConfigurationProperties(prefix = "tts")
public record TtsProperties(Boolean enabled, String speechStoragePath) {

  private static final String DEFAULT_SPEECH_STORAGE_PATH = "data/routine-speech";

  public TtsProperties {
    if (enabled == null) {
      enabled = true;
    }
    if (speechStoragePath == null || speechStoragePath.isBlank()) {
      speechStoragePath = DEFAULT_SPEECH_STORAGE_PATH;
    }
  }

  public boolean isEnabled() {
    return Boolean.TRUE.equals(enabled);
  }
}
