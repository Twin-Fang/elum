package com.chuseok22.elumserver.common.infrastructure.properties;

import jakarta.annotation.PostConstruct;
import lombok.Getter;
import lombok.Setter;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

// AI DLP 요청 암호화용 마스터 시크릿. elum.aidlp.secret에서 온다
// (prod는 환경변수 ELUM_AIDLP_SECRET → application.yml 바인딩).
// 값은 클라이언트 .env(ELUM_AIDLP_SECRET)와 동일해야 HKDF 파생 결과가 일치한다.
@Slf4j
@Getter
@Setter
@Component
@ConfigurationProperties(prefix = "elum.aidlp")
public class AidlpProperties {

  // 미설정 시 빈 문자열. 이때 암호화된 요청이 오면 필터가 명시적으로 거절한다(조용한 통과 금지 — #182).
  private String secret = "";

  // 설정 누락은 요청이 들어온 뒤가 아니라 기동 시점에 드러나야 한다.
  // #182는 이 경고가 없어 "AI가 느린 건가" 하고 18초를 기다리다 E-1001만 보게 된 사고였다.
  @PostConstruct
  void warnIfNotConfigured() {
    if (secret.isBlank()) {
      log.warn("[AI DLP] elum.aidlp.secret 미설정 — 암호화된 요청은 DLP_SECRET_NOT_CONFIGURED로 거절됩니다. "
        + "클라이언트 ELUM_AIDLP_SECRET과 같은 값을 환경변수로 넣으세요.");
    }
  }
}
