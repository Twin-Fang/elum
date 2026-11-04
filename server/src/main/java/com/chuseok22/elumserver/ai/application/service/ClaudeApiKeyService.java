package com.chuseok22.elumserver.ai.application.service;

import com.chuseok22.elumserver.ai.core.ClaudeApiKey;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.json.DefaultJsonMapper;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * Claude 키 목록 관리: 읽기, 추가·삭제·순서 바꾸기·켜고 끄기·키 교체 (#1083)
 * 저장: 목록 JSON 통째로 CLAUDE_API_KEYS 비밀값 한 칸 (암호화·변경 이력은 SystemConfigService 가 처리, 이력에는 •••• 만)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ClaudeApiKeyService {

  // 별명 최대 길이 (화면 한 줄)
  static final int NICKNAME_MAX_LENGTH = 30;
  // 키 값 길이 범위 (Anthropic 키 약 108자)
  static final int API_KEY_MIN_LENGTH = 20;
  static final int API_KEY_MAX_LENGTH = 300;
  // 키 개수 상한 (비밀값 길이 상한 안에 들어오게)
  static final int MAXIMUM_KEY_COUNT = 10;
  // 키 id 길이 (UUID 앞부분, 화면 요청에만 쓰임)
  private static final int KEY_ID_LENGTH = 8;

  private static final TypeReference<List<ClaudeApiKey>> KEY_LIST_TYPE = new TypeReference<>() {
  };

  private final SystemConfigService systemConfigService;
  private final ObjectMapper objectMapper = DefaultJsonMapper.SHARED;

  /// 저장된 키 전부 (우선순위 순). 없거나 읽을 수 없으면 빈 목록 — 키 없음은 "Claude 못 씀" 상태일 뿐 오류가 아님
  public List<ClaudeApiKey> keys() {
    String stored = systemConfigService.getSecret(ConfigKey.CLAUDE_API_KEYS);
    if (stored.isBlank()) {
      return List.of();
    }
    try {
      List<ClaudeApiKey> parsed = objectMapper.readValue(stored, KEY_LIST_TYPE);
      return parsed == null ? List.of() : parsed.stream()
        .filter(key -> key != null && key.apiKey() != null && !key.apiKey().isBlank())
        .toList();
    } catch (JsonProcessingException e) {
      log.warn("[claude keys] stored key list unreadable, treated as empty. re-save keys in admin");
      return List.of();
    }
  }

  /// 호출에 쓸 키 (켜진 것만, 우선순위 순)
  public List<ClaudeApiKey> enabledKeys() {
    return keys().stream().filter(ClaudeApiKey::enabled).toList();
  }

  public boolean hasEnabledKey() {
    return !enabledKeys().isEmpty();
  }

  /// 맨 뒤(가장 낮은 우선순위)에 추가
  public void add(String nickname, String apiKey, String actor) {
    List<ClaudeApiKey> keys = new ArrayList<>(keys());
    if (keys.size() >= MAXIMUM_KEY_COUNT) {
      throw invalid("키는 " + MAXIMUM_KEY_COUNT + "개까지 둘 수 있어요");
    }
    String cleanNickname = requireNickname(nickname, keys, null);
    String cleanApiKey = requireApiKey(apiKey, keys, null);
    keys.add(new ClaudeApiKey(newKeyId(), cleanNickname, cleanApiKey, true));
    save(keys, actor, "Claude 키 추가: " + cleanNickname);
  }

  public void remove(String keyId, String actor) {
    List<ClaudeApiKey> keys = new ArrayList<>(keys());
    ClaudeApiKey removed = keys.get(indexOf(keys, keyId));
    keys.remove(removed);
    save(keys, actor, "Claude 키 삭제: " + removed.nickname());
  }

  /// 우선순위 한 칸 올리기(up) / 내리기. 끝에서는 그대로
  public void move(String keyId, boolean isMovingUp, String actor) {
    List<ClaudeApiKey> keys = new ArrayList<>(keys());
    int index = indexOf(keys, keyId);
    int target = isMovingUp ? index - 1 : index + 1;
    if (target < 0 || target >= keys.size()) {
      return;
    }
    ClaudeApiKey moved = keys.remove(index);
    keys.add(target, moved);
    save(keys, actor, "Claude 키 순서: " + moved.nickname() + " > " + (target + 1) + "순위");
  }

  public void setEnabled(String keyId, boolean isEnabled, String actor) {
    List<ClaudeApiKey> keys = new ArrayList<>(keys());
    int index = indexOf(keys, keyId);
    ClaudeApiKey changed = keys.get(index).withEnabled(isEnabled);
    keys.set(index, changed);
    save(keys, actor, "Claude 키 " + (isEnabled ? "켜기: " : "끄기: ") + changed.nickname());
  }

  /// 같은 자리·별명에 키 값만 바꾼다 (재발급)
  public void replaceApiKey(String keyId, String apiKey, String actor) {
    List<ClaudeApiKey> keys = new ArrayList<>(keys());
    int index = indexOf(keys, keyId);
    String cleanApiKey = requireApiKey(apiKey, keys, keyId);
    ClaudeApiKey changed = keys.get(index).withApiKey(cleanApiKey);
    keys.set(index, changed);
    save(keys, actor, "Claude 키 교체: " + changed.nickname());
  }

  public void rename(String keyId, String nickname, String actor) {
    List<ClaudeApiKey> keys = new ArrayList<>(keys());
    int index = indexOf(keys, keyId);
    String cleanNickname = requireNickname(nickname, keys, keyId);
    String before = keys.get(index).nickname();
    keys.set(index, keys.get(index).withNickname(cleanNickname));
    save(keys, actor, "Claude 키 별명: " + before + " > " + cleanNickname);
  }

  // 빈 목록은 비밀값 지우기 (update 는 빈 값을 "그대로 두기"로 받음)
  private void save(List<ClaudeApiKey> keys, String actor, String reason) {
    if (keys.isEmpty()) {
      systemConfigService.resetToDefault(ConfigKey.CLAUDE_API_KEYS, actor, reason);
      return;
    }
    try {
      systemConfigService.update(ConfigKey.CLAUDE_API_KEYS, objectMapper.writeValueAsString(keys), actor, reason);
    } catch (JsonProcessingException e) {
      throw new IllegalStateException("Claude 키 목록 직렬화 실패", e);
    }
  }

  private static int indexOf(List<ClaudeApiKey> keys, String keyId) {
    for (int index = 0; index < keys.size(); index++) {
      if (keys.get(index).id().equals(keyId)) {
        return index;
      }
    }
    throw invalid("없는 키예요. 화면을 새로 고쳐요");
  }

  /// 별명 검사 (빈 값, 길이, 다른 키와 중복)
  private static String requireNickname(String nickname, List<ClaudeApiKey> keys, String ownKeyId) {
    String clean = nickname == null ? "" : nickname.trim();
    if (clean.isEmpty() || clean.length() > NICKNAME_MAX_LENGTH) {
      throw invalid("별명은 1~" + NICKNAME_MAX_LENGTH + "자로 적어요");
    }
    boolean isDuplicated = keys.stream()
      .anyMatch(key -> !key.id().equals(ownKeyId) && key.nickname().equals(clean));
    if (isDuplicated) {
      throw invalid("같은 별명의 키가 이미 있어요");
    }
    return clean;
  }

  /// 키 값 검사 (빈 값, 공백, 길이, 다른 키와 중복)
  private static String requireApiKey(String apiKey, List<ClaudeApiKey> keys, String ownKeyId) {
    String clean = apiKey == null ? "" : apiKey.trim();
    if (clean.length() < API_KEY_MIN_LENGTH || clean.length() > API_KEY_MAX_LENGTH || clean.matches(".*\\s.*")) {
      throw invalid("키 값이 올바르지 않아요 (공백 없이 통째로 붙여 넣어요)");
    }
    boolean isDuplicated = keys.stream()
      .anyMatch(key -> !key.id().equals(ownKeyId) && key.apiKey().equals(clean));
    if (isDuplicated) {
      throw invalid("이미 등록한 키예요");
    }
    return clean;
  }

  private static String newKeyId() {
    return UUID.randomUUID().toString().substring(0, KEY_ID_LENGTH);
  }

  private static CustomException invalid(String reason) {
    return new CustomException(ErrorCode.SYSTEM_CONFIG_INVALID_VALUE, reason);
  }
}
