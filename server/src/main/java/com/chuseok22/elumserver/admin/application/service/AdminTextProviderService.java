package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminClaudeKeyView;
import com.chuseok22.elumserver.admin.application.dto.response.AdminTextProviderView;
import com.chuseok22.elumserver.ai.application.service.ClaudeApiKeyService;
import com.chuseok22.elumserver.ai.application.service.ClaudeKeyHealthTracker;
import com.chuseok22.elumserver.ai.core.ClaudeApiKey;
import com.chuseok22.elumserver.ai.core.TextProvider;
import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.TextGenerationClient;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * 관리자 텍스트 제공자: 사슬(시도 순서) 보기·바꾸기, Claude 키 카드 보기·바꾸기 (#1083)
 * 사슬 저장: 1번 > TEXT_PROVIDER_SELECTED, 나머지 > TEXT_PROVIDER_FALLBACKS (기존 전환 버튼·통계가 그대로 1번을 봄)
 * 막는 것 2개: 키 없는 제공자를 사슬에 넣기, 사슬이 Claude 를 쓰는데 마지막 켜진 키를 끄기·지우기
 */
@Service
@RequiredArgsConstructor
public class AdminTextProviderService {

  private static final String CHAIN_DELIMITER = ",";

  private final TextClientRouter textClientRouter;
  private final SystemConfigService systemConfigService;
  private final ClaudeApiKeyService claudeApiKeyService;
  private final ClaudeKeyHealthTracker claudeKeyHealthTracker;

  /// 제공자 카드: 사슬 순서대로 > 사슬 밖 제공자는 이름순으로 뒤에
  public List<AdminTextProviderView> providerViews() {
    List<TextProvider> chain = textClientRouter.chain();
    return textClientRouter.all().stream()
      .sorted(Comparator.comparingInt((TextGenerationClient client) -> chainOrderOf(chain, client.provider()))
        .thenComparing(client -> client.provider().name()))
      .map(client -> {
        int position = chain.indexOf(client.provider()) + 1;
        return AdminTextProviderView.of(
          client, position, position == chain.size(),
          systemConfigService.getDouble(client.provider().getInputPriceKey()),
          systemConfigService.getDouble(client.provider().getOutputPriceKey()));
      })
      .toList();
  }

  /// Claude 키 카드 (우선순위 순, 키 값 대신 끝 4자리)
  public List<AdminClaudeKeyView> claudeKeyViews() {
    List<ClaudeApiKey> keys = claudeApiKeyService.keys();
    Optional<String> lastServedKeyId = claudeKeyHealthTracker.lastServedKeyId();
    List<AdminClaudeKeyView> views = new ArrayList<>();
    for (int index = 0; index < keys.size(); index++) {
      ClaudeApiKey key = keys.get(index);
      Optional<ClaudeKeyHealthTracker.KeyHealth> health = claudeKeyHealthTracker.healthOf(key.id());
      views.add(new AdminClaudeKeyView(
        key.id(), index + 1, key.nickname(), key.maskedKey(), key.enabled(),
        lastServedKeyId.map(key.id()::equals).orElse(false),
        claudeKeyHealthTracker.isCoolingDown(key.id()),
        health.map(ClaudeKeyHealthTracker.KeyHealth::lastSuccessAt).orElse(null),
        health.map(ClaudeKeyHealthTracker.KeyHealth::lastFailureAt).orElse(null),
        health.map(ClaudeKeyHealthTracker.KeyHealth::lastFailureKind).map(kind -> kind.getLabel()).orElse(null),
        health.map(ClaudeKeyHealthTracker.KeyHealth::cooldownUntil).orElse(null),
        index == 0, index == keys.size() - 1));
    }
    return views;
  }

  // --- 사슬 ---

  /// 사슬 맨 뒤에 추가 (키 없는 제공자는 거부)
  public void addToChain(TextProvider provider, String actor) {
    List<TextProvider> chain = new ArrayList<>(textClientRouter.chain());
    if (chain.contains(provider)) {
      return;
    }
    requireAvailable(provider);
    chain.add(provider);
    saveChain(chain, actor);
  }

  /// 사슬에서 빼기 (마지막 하나는 뺄 수 없음)
  public void removeFromChain(TextProvider provider, String actor) {
    List<TextProvider> chain = new ArrayList<>(textClientRouter.chain());
    if (!chain.contains(provider)) {
      return;
    }
    if (chain.size() == 1) {
      throw invalid("제공자가 하나는 있어야 해요");
    }
    chain.remove(provider);
    // 새 1번 제공자는 쓸 수 있어야 함 (전환 버튼과 같은 규칙)
    requireAvailable(chain.get(0));
    saveChain(chain, actor);
  }

  /// 한 칸 올리기·내리기. 1번이 바뀌면 새 1번은 키가 있어야 함
  public void moveInChain(TextProvider provider, boolean isMovingUp, String actor) {
    List<TextProvider> chain = new ArrayList<>(textClientRouter.chain());
    int index = chain.indexOf(provider);
    int target = isMovingUp ? index - 1 : index + 1;
    if (index < 0 || target < 0 || target >= chain.size()) {
      return;
    }
    chain.remove(index);
    chain.add(target, provider);
    requireAvailable(chain.get(0));
    saveChain(chain, actor);
  }

  /// 대체 목록 직접 저장 전 검사 (설정 표에서 TEXT_PROVIDER_FALLBACKS 를 고칠 때): 키 없는 제공자 거부
  public void requireFallbacksAvailable(String fallbacksValue) {
    for (String name : fallbacksValue == null ? new String[0] : fallbacksValue.split(CHAIN_DELIMITER)) {
      if (name.isBlank()) {
        continue;
      }
      TextProvider provider;
      try {
        provider = TextProvider.valueOf(name.trim().toUpperCase(java.util.Locale.ROOT));
      } catch (IllegalArgumentException e) {
        // 형식 거부는 설정 검사기가 사유와 함께 함
        continue;
      }
      requireAvailable(provider);
    }
  }

  // --- Claude 키 ---

  public void addClaudeKey(String nickname, String apiKey, String actor) {
    claudeApiKeyService.add(nickname, apiKey, actor);
  }

  public void removeClaudeKey(String keyId, String actor) {
    requireNotLastEnabledKeyInUse(keyId);
    claudeApiKeyService.remove(keyId, actor);
  }

  public void moveClaudeKey(String keyId, boolean isMovingUp, String actor) {
    claudeApiKeyService.move(keyId, isMovingUp, actor);
  }

  public void setClaudeKeyEnabled(String keyId, boolean isEnabled, String actor) {
    if (!isEnabled) {
      requireNotLastEnabledKeyInUse(keyId);
    }
    claudeApiKeyService.setEnabled(keyId, isEnabled, actor);
  }

  public void replaceClaudeKey(String keyId, String apiKey, String actor) {
    claudeApiKeyService.replaceApiKey(keyId, apiKey, actor);
  }

  public void renameClaudeKey(String keyId, String nickname, String actor) {
    claudeApiKeyService.rename(keyId, nickname, actor);
  }

  /// 사슬이 Claude 를 쓰는데 이 키가 마지막 켜진 키면 거부 (키가 0개가 되면 Claude 단계가 통째로 실패)
  private void requireNotLastEnabledKeyInUse(String keyId) {
    if (!textClientRouter.chain().contains(TextProvider.CLAUDE)) {
      return;
    }
    List<ClaudeApiKey> enabledKeys = claudeApiKeyService.enabledKeys();
    boolean isLastEnabledKey = enabledKeys.size() == 1 && enabledKeys.get(0).id().equals(keyId);
    if (isLastEnabledKey) {
      throw invalid("Claude 가 제공자 순서에 있어 마지막 키는 끄거나 지울 수 없어요. 먼저 순서에서 Claude 를 빼요");
    }
  }

  private void requireAvailable(TextProvider provider) {
    boolean isUsable = textClientRouter.of(provider).map(TextGenerationClient::available).orElse(false);
    if (!isUsable) {
      throw new CustomException(ErrorCode.TEXT_PROVIDER_UNAVAILABLE);
    }
  }

  // 1번 > 선택값, 나머지 > 대체 목록 (값이 같으면 SystemConfigService 가 이력을 남기지 않음)
  private void saveChain(List<TextProvider> chain, String actor) {
    String reason = "제공자 순서: " + String.join(" > ", chain.stream().map(TextProvider::name).toList());
    systemConfigService.update(ConfigKey.TEXT_PROVIDER_SELECTED, chain.get(0).name(), actor, reason);
    systemConfigService.update(ConfigKey.TEXT_PROVIDER_FALLBACKS,
      String.join(CHAIN_DELIMITER, chain.subList(1, chain.size()).stream().map(TextProvider::name).toList()),
      actor, reason);
  }

  private static int chainOrderOf(List<TextProvider> chain, TextProvider provider) {
    int index = chain.indexOf(provider);
    return index < 0 ? Integer.MAX_VALUE : index;
  }

  private static CustomException invalid(String reason) {
    return new CustomException(ErrorCode.SYSTEM_CONFIG_INVALID_VALUE, reason);
  }
}
