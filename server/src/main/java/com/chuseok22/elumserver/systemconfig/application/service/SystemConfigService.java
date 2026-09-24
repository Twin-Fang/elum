package com.chuseok22.elumserver.systemconfig.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.GeminiProperties;
import com.chuseok22.elumserver.common.infrastructure.properties.LocalLlmProperties;
import com.chuseok22.elumserver.common.infrastructure.security.SecretCipher;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.chuseok22.elumserver.systemconfig.core.ConfigValueType;
import com.chuseok22.elumserver.systemconfig.core.StoreUrlPolicy;
import com.chuseok22.elumserver.systemconfig.infrastructure.entity.SystemConfig;
import com.chuseok22.elumserver.systemconfig.infrastructure.entity.SystemConfigHistory;
import com.chuseok22.elumserver.systemconfig.infrastructure.repository.SystemConfigHistoryRepository;
import com.chuseok22.elumserver.systemconfig.infrastructure.repository.SystemConfigRepository;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
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
  // 암호문이 Base64로 부풀어도 MAX_VALUE_LENGTH 안에 들어오도록 평문을 더 좁게 제한한다.
  private static final int SECRET_MAX_LENGTH = 300;
  private static final String SECRET_MASK = "••••••••";
  /// 이력에 남기는 비밀값 표시. 평문도 암호문도 남기지 않는다 — 바뀌었다는 사실만 보인다.
  static final String HISTORY_SECRET_MASK = "••••";
  /// 사람이 아니라 코드가 바꿀 때의 변경자.
  static final String SYSTEM_ACTOR = "system";
  private static final int HISTORY_REASON_MAX_LENGTH = 500;

  private final SystemConfigRepository systemConfigRepository;
  private final GeminiProperties geminiProperties;
  private final LocalLlmProperties localLlmProperties;
  private final SecretCipher secretCipher;
  private final SystemConfigHistoryRepository systemConfigHistoryRepository;

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

  // parseBoolean은 "true"가 아닌 값을 조용히 false로 만든다. 값이 손상됐을 때
  // (수동 DB 조작 등) 권한이 슬그머니 꺼지는 대신 기본값으로 돌아가게 한다.
  public boolean getBoolean(ConfigKey key) {
    String value = getString(key).trim();
    if ("true".equalsIgnoreCase(value)) {
      return true;
    }
    if ("false".equalsIgnoreCase(value)) {
      return false;
    }
    log.warn("시스템 설정 불리언 파싱 실패, 기본값 사용: key={}, value={}", key, value);
    return Boolean.parseBoolean(defaultValueFor(key));
  }

  /**
   * 비밀값을 풀어서 돌려준다. 저장돼 있지 않거나 풀 수 없으면 빈 문자열.
   *
   * <p>빈 문자열을 돌려주는 이유는, 부르는 쪽이 "키가 없다"를 예외가 아니라 상태로
   * 다루게 하기 위해서다. 키가 없는 제공자는 고를 수 없게 막으면 되지 서버가 죽을 일이
   * 아니다.
   */
  public String getSecret(ConfigKey key) {
    String stored = storedValue(key);
    if (stored == null || stored.isBlank()) {
      return "";
    }
    String decrypted = secretCipher.decrypt(stored);
    if (decrypted == null) {
      log.warn("비밀값을 풀지 못했습니다. 다시 저장해야 합니다: key={}", key);
      return "";
    }
    return decrypted;
  }

  public boolean hasSecret(ConfigKey key) {
    return !getSecret(key).isBlank();
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
        if (key.getValueType() == ConfigValueType.SECRET) {
          // 암호문을 화면에 그대로 내보내지 않는다. 있는지 없는지만 보이면 된다.
          String stored = storedValue(key);
          boolean set = stored != null && !stored.isBlank();
          return new SystemConfigView(
            key.name(), key.getGroup(), key.getLabel(), key.getDescription(),
            key.getValueType(), key.getAllowedValues(), set ? SECRET_MASK : "", "", set,
            key.getMinValue(), key.getMaxValue()
          );
        }
        return new SystemConfigView(
          key.name(), key.getGroup(), key.getLabel(), key.getDescription(),
          key.getValueType(), key.getAllowedValues(), current, defaultValue,
          !current.equals(defaultValue), key.getMinValue(), key.getMaxValue()
        );
      })
      .toList();
  }

  /// 코드가 바꿀 때. 이력의 변경자는 system 이다.
  @Transactional
  public void update(ConfigKey key, String rawValue) {
    update(key, rawValue, SYSTEM_ACTOR, null);
  }

  /**
   * 설정을 바꾸고 이력을 남긴다 (#407). 값이 그대로면 이력을 남기지 않는다.
   *
   * @param actor  바꾼 관리자 로그인 아이디. 비면 system
   * @param reason 사유(선택)
   */
  @Transactional
  public void update(ConfigKey key, String rawValue, String actor, String reason) {
    String value = validate(key, rawValue);
    boolean secret = key.getValueType() == ConfigValueType.SECRET;
    if (secret) {
      // 비밀값은 화면에 가려서 보여주므로 폼이 빈 값으로 돌아온다. 그걸 "지우기"로
      // 받으면 저장 버튼을 누를 때마다 키가 날아간다. 빈 값은 "그대로 두기"다.
      // 지우려면 기본값 복원을 쓴다.
      if (value.isEmpty()) {
        return;
      }
    }
    SystemConfig config = findOrNew(key);
    // 비교는 사람이 보는 값으로 한다 — 저장값이 없으면 기본값이 지금 값이다. 비밀값은 풀어서 비교한다.
    String before = secret ? currentSecret(config) : effectiveValue(key, config);
    config.setConfigValue(secret ? encryptSecret(value) : value);
    // 저장은 예전처럼 늘 한다(기본값과 같은 값도 행으로 고정된다). 이력만 실제로 바뀐 것을 남긴다.
    systemConfigRepository.save(config);
    if (!Objects.equals(before, value)) {
      recordHistory(key, secret, before, value, actor, reason);
    }
    forceReload();
  }

  @Transactional
  public void resetToDefault(ConfigKey key) {
    resetToDefault(key, SYSTEM_ACTOR, null);
  }

  @Transactional
  public void resetToDefault(ConfigKey key, String actor, String reason) {
    // 비밀값의 기본값은 "없음"이다. update는 빈 값을 무시하므로 여기서 직접 비운다.
    if (key.getValueType() == ConfigValueType.SECRET) {
      SystemConfig config = findOrNew(key);
      String before = currentSecret(config);
      config.setConfigValue("");
      systemConfigRepository.save(config);
      if (!before.isEmpty()) {
        recordHistory(key, true, before, "", actor, reason);
      }
      forceReload();
      return;
    }
    update(key, defaultValueFor(key), actor, reason);
  }

  /// 설정 화면 아래 최근 변경 이력(최신 20건).
  @Transactional(readOnly = true)
  public List<SystemConfigHistory> recentHistory() {
    return systemConfigHistoryRepository.findTop20ByOrderByCreatedAtDesc();
  }

  private SystemConfig findOrNew(ConfigKey key) {
    return systemConfigRepository.findByConfigKey(key)
      .orElseGet(() -> {
        SystemConfig created = new SystemConfig();
        created.setConfigKey(key);
        return created;
      });
  }

  /// 저장값이 비었으면 기본값이 지금 값이다(getString 과 같은 규칙).
  private String effectiveValue(ConfigKey key, SystemConfig config) {
    String stored = config.getConfigValue();
    return (stored == null || stored.isBlank()) ? defaultValueFor(key) : stored;
  }

  /// 저장된 비밀값의 평문. 없거나 풀 수 없으면 빈 문자열 — 풀 수 없으면 다른 값으로 보고 새로 저장한다.
  private String currentSecret(SystemConfig config) {
    String stored = config.getConfigValue();
    if (stored == null || stored.isBlank()) {
      return "";
    }
    String decrypted = secretCipher.decrypt(stored);
    return decrypted == null ? "" : decrypted;
  }

  /**
   * 이력 한 줄. 비밀값은 값 대신 있음(••••)/없음(빈 값)만 적는다 — 이력 표가 새면 키가 새는 일이 없게.
   */
  private void recordHistory(
    ConfigKey key, boolean secret, String before, String after, String actor, String reason
  ) {
    SystemConfigHistory history = new SystemConfigHistory();
    history.setConfigKey(key.name());
    history.setOldValue(secret ? maskSecret(before) : before);
    history.setNewValue(secret ? maskSecret(after) : after);
    history.setChangedBy(actor == null || actor.isBlank() ? SYSTEM_ACTOR : actor);
    history.setReason(trimReason(reason));
    systemConfigHistoryRepository.save(history);
  }

  private static String maskSecret(String plain) {
    return plain == null || plain.isEmpty() ? "" : HISTORY_SECRET_MASK;
  }

  private static String trimReason(String reason) {
    if (reason == null || reason.isBlank()) {
      return null;
    }
    String trimmed = reason.trim();
    return trimmed.length() > HISTORY_REASON_MAX_LENGTH ? trimmed.substring(0, HISTORY_REASON_MAX_LENGTH) : trimmed;
  }

  private String validate(ConfigKey key, String rawValue) {
    // 비밀값만 빈 값을 허용한다 — 화면에서 키를 지울 수 있어야 하기 때문이다.
    // 암호문이 평문보다 길어지므로 평문 길이를 더 좁게 본다.
    if (key.getValueType() == ConfigValueType.SECRET) {
      if (rawValue == null) {
        return "";
      }
      String secret = rawValue.trim();
      if (secret.length() > SECRET_MAX_LENGTH) {
        throw new CustomException(ErrorCode.SYSTEM_CONFIG_INVALID_VALUE);
      }
      return secret;
    }
    if (rawValue == null || rawValue.isBlank() || rawValue.length() > MAX_VALUE_LENGTH) {
      throw new CustomException(ErrorCode.SYSTEM_CONFIG_INVALID_VALUE);
    }
    String value = rawValue.trim();
    try {
      if (key.getValueType() == ConfigValueType.INTEGER) {
        int number = Integer.parseInt(value);
        // 시간값에 0 이나 음수가 들어가면 앱의 요청이 끝없이 기다리게 된다. 범위가 있는 키만 본다.
        if ((key.getMinValue() != null && number < key.getMinValue())
          || (key.getMaxValue() != null && number > key.getMaxValue())) {
          throw new CustomException(ErrorCode.SYSTEM_CONFIG_INVALID_VALUE);
        }
      } else if (key.getValueType() == ConfigValueType.DECIMAL) {
        Double.parseDouble(value);
      } else if (key.getValueType() == ConfigValueType.SELECT && !key.getAllowedValues().contains(value)) {
        throw new CustomException(ErrorCode.SYSTEM_CONFIG_INVALID_VALUE);
      } else if (key.getValueType() == ConfigValueType.BOOLEAN
        && !"true".equalsIgnoreCase(value) && !"false".equalsIgnoreCase(value)) {
        throw new CustomException(ErrorCode.SYSTEM_CONFIG_INVALID_VALUE);
      } else if (StoreUrlPolicy.appliesTo(key) && !StoreUrlPolicy.isAllowed(key, value)) {
        // 막힌 사용자를 엉뚱한 곳으로 보내지 않도록 공식 스토어 주소만 받는다 (#416)
        throw new CustomException(ErrorCode.SYSTEM_CONFIG_INVALID_VALUE);
      }
    } catch (NumberFormatException e) {
      throw new CustomException(ErrorCode.SYSTEM_CONFIG_INVALID_VALUE);
    }
    return value;
  }

  // 빈 값이면 "지우기"이므로 그대로 둔다. 값이 있는데 마스터 키가 없으면 저장을 거부한다 —
  // 평문으로 남기느니 저장을 실패시키는 편이 낫다.
  private String encryptSecret(String plain) {
    if (plain.isEmpty()) {
      return "";
    }
    if (!secretCipher.isAvailable()) {
      throw new CustomException(ErrorCode.SECRET_MASTER_KEY_MISSING);
    }
    String encrypted = secretCipher.encrypt(plain);
    if (encrypted == null) {
      throw new CustomException(ErrorCode.SECRET_ENCRYPT_FAILED);
    }
    return encrypted;
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
