package com.chuseok22.elumserver.common.infrastructure.properties;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

// AI DLP 요청 암호화용 마스터 시크릿. application-dev.yml의 elum.aidlp.secret에서 온다.
// 값은 클라이언트 .env(ELUM_AIDLP_SECRET)와 동일해야 HKDF 파생 결과가 일치한다.
@Getter
@Setter
@Component
@ConfigurationProperties(prefix = "elum.aidlp")
public class AidlpProperties {

  // 미설정 시 빈 문자열. 필터는 secret이 비면 복호화를 시도하지 않고 통과시켜(데모 안전) 로컬 fallback을 유도한다.
  private String secret = "";
}
