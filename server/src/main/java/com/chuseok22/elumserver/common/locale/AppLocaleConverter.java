package com.chuseok22.elumserver.common.locale;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;
import lombok.extern.slf4j.Slf4j;

/**
 * {@link AppLocale} 을 DB 에 소문자 코드({@code ko})로 저장한다.
 *
 * <p>{@code @Enumerated(STRING)} 은 상수 이름({@code KO})을 쓰므로 마이그레이션의 {@code DEFAULT 'ko'} 와 어긋난다.
 * 읽을 때 손상된 값은 ko 로 읽는다 — 한 행 때문에 일과 목록 전체가 죽으면 안 된다.
 */
@Slf4j
@Converter
public class AppLocaleConverter implements AttributeConverter<AppLocale, String> {

  @Override
  public String convertToDatabaseColumn(AppLocale attribute) {
    return attribute == null ? null : attribute.code();
  }

  @Override
  public AppLocale convertToEntityAttribute(String dbData) {
    if (dbData == null || dbData.isBlank()) {
      return AppLocale.KO;
    }
    try {
      return AppLocale.fromCode(dbData);
    } catch (IllegalArgumentException e) {
      log.warn("[AppLocaleConverter] 알 수 없는 언어 코드를 ko 로 읽습니다: {}", dbData);
      return AppLocale.KO;
    }
  }
}
