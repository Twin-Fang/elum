package com.chuseok22.elumserver.systemconfig.infrastructure.entity;

import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

/**
 * 설정 키 저장값 <-> ConfigKey (이 서버 버전이 모르는 키는 null)
 * 앞선 버전이 같은 DB 에 새 키를 넣어도 설정 전체 읽기가 깨지지 않게 함
 */
@Converter
public class ConfigKeyConverter implements AttributeConverter<ConfigKey, String> {

  @Override
  public String convertToDatabaseColumn(ConfigKey key) {
    return key == null ? null : key.name();
  }

  @Override
  public ConfigKey convertToEntityAttribute(String storedKey) {
    if (storedKey == null) {
      return null;
    }
    try {
      return ConfigKey.valueOf(storedKey);
    } catch (IllegalArgumentException unknownKey) {
      return null;
    }
  }
}
