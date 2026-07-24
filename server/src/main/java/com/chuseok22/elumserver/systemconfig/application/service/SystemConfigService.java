package com.chuseok22.elumserver.systemconfig.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.GeminiProperties;
import com.chuseok22.elumserver.common.infrastructure.properties.LocalLlmProperties;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.chuseok22.elumserver.systemconfig.core.ConfigValueType;
import com.chuseok22.elumserver.systemconfig.infrastructure.entity.SystemConfig;
import com.chuseok22.elumserver.systemconfig.infrastructure.repository.SystemConfigRepository;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * system_config 테이블을 단일 진실 공급원으로 하는 동적 설정 서비스.
 * 전체 키를 메모리 캐시에 올려두고 TTL(30초)이 지나면 다음 조회 때 리로드한다 —
 * AI 호출마다 DB를 두드리지 않으면서도, 다중 레플리카 환경에서 다른 인스턴스의
 * 변경이 30초 안에 수렴하도록 하기 위한 절충이다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class SystemConfigService {

  private static final long CACHE_TTL_MILLIS = 30_000;
  private static final int MAX_VALUE_LENGTH = 500;

  private final SystemConfigRepository systemConfigRepository;
  private final GeminiProperties geminiProperties;
  private final LocalLlmProperties localLlmProperties;

  private volatile Map<ConfigKey, String> cache = Map.of();
  private volatile long cacheLoadedAtMillis = 0;

  public String getString(ConfigKey key) {
    String value = storedValue(key);
    return (value == null || value.isBlank()) ? defaultValueFor(key) : value;
  }

  // 저장된 값이 손상돼 파싱에 실패해도(수동 DB 조작 등) AI 호출이 죽지 않도록
  // 기본값으로 폴백한다.
  public int getInt(ConfigKey key) {
    try {
      return Integer.parseInt(getString(key).trim());
    } catch (NumberFormatException e) {
      log.warn("시스템 설정 정수 파싱 실패, 기본값 사용: key={}, value={}", key, storedValue(key));
      return Integer.parseInt(defaultValueFor(key));
    }
  }

  public double getDouble(ConfigKey key) {
    try {
      return Double.parseDouble(getString(key).trim());
    } catch (NumberFormatException e) {
      log.warn("시스템 설정 소수 파싱 실패, 기본값 사용: key={}, value={}", key, storedValue(key));
      return Double.parseDouble(defaultValueFor(key));
    }
  }

  // 배포 환경(yml)에 바인딩된 모델명이 있으면 그것이 사실상의 기본값이다.
  // enum defaultValue는 yml에도 값이 없을 때의 마지막 폴백.
  public String defaultValueFor(ConfigKey key) {
    String propertyValue = switch (key) {
      case GEMINI_TEXT_MODEL -> geminiProperties.textModel();
      case GEMINI_IMAGE_MODEL -> geminiProperties.imageModel();
      case LOCAL_LLM_MODEL -> localLlmProperties.model();
      default -> null;
    };
    if (propertyValue != null && !propertyValue.isBlank()) {
      return propertyValue;
    }
    return key.getDefaultValue();
  }

  // 관리자 화면용 전체 조회. 저장값이 없으면 기본값을 현재값으로 보여준다.
  public List<SystemConfigView> getAllViews() {
    return List.of(ConfigKey.values()).stream()
      .map(key -> {
        String defaultValue = defaultValueFor(key);
        String current = getString(key);
        return new SystemConfigView(
          key.name(), key.getGroup(), key.getLabel(), key.getDescription(),
          key.getValueType(), key.getAllowedValues(), current, defaultValue,
          !current.equals(defaultValue)
        );
      })
      .toList();
  }

  @Transactional
  public void update(ConfigKey key, String rawValue) {
    String value = validate(key, rawValue);
    SystemConfig config = systemConfigRepository.findByConfigKey(key)
      .orElseGet(() -> {
        SystemConfig created = new SystemConfig();
        created.setConfigKey(key);
        return created;
      });
    config.setConfigValue(value);
    systemConfigRepository.save(config);
    forceReload();
  }

  @Transactional
  public void resetToDefault(ConfigKey key) {
    update(key, defaultValueFor(key));
  }

  private String validate(ConfigKey key, String rawValue) {
    if (rawValue == null || rawValue.isBlank() || rawValue.length() > MAX_VALUE_LENGTH) {
      throw new CustomException(ErrorCode.SYSTEM_CONFIG_INVALID_VALUE);
    }
    String value = rawValue.trim();
    try {
      if (key.getValueType() == ConfigValueType.INTEGER) {
        Integer.parseInt(value);
      } else if (key.getValueType() == ConfigValueType.DECIMAL) {
        Double.parseDouble(value);
      } else if (key.getValueType() == ConfigValueType.SELECT && !key.getAllowedValues().contains(value)) {
        throw new CustomException(ErrorCode.SYSTEM_CONFIG_INVALID_VALUE);
      }
    } catch (NumberFormatException e) {
      throw new CustomException(ErrorCode.SYSTEM_CONFIG_INVALID_VALUE);
    }
    return value;
  }

  private String storedValue(ConfigKey key) {
    refreshIfStale();
    return cache.get(key);
  }

  private void refreshIfStale() {
    if (System.currentTimeMillis() - cacheLoadedAtMillis < CACHE_TTL_MILLIS) {
      return;
    }
    forceReload();
  }

  // 리로드 실패 시 기존 캐시를 그대로 유지한다 — 설정 조회 실패가 AI 호출 전체를
  // 실패시키면 안 된다. loadedAt은 갱신해 장애 중 DB를 연타하지 않는다.
  private synchronized void forceReload() {
    try {
      Map<ConfigKey, String> loaded = new EnumMap<>(ConfigKey.class);
      systemConfigRepository.findAll()
        .forEach(config -> loaded.put(config.getConfigKey(), config.getConfigValue()));
      cache = Map.copyOf(loaded);
    } catch (Exception e) {
      log.warn("시스템 설정 캐시 리로드 실패, 기존 캐시 유지", e);
    } finally {
      cacheLoadedAtMillis = System.currentTimeMillis();
    }
  }
}
