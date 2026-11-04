package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.core.TextProvider;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigValueValidator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 설정에 적힌 텍스트 제공자를 골라 준다.
 *
 * <p>{@link ImageClientRouter}와 같은 모양으로 둔다 — 관리자가 화면에서 이미지와
 * 텍스트를 같은 방식으로 다루므로, 뒤에서도 같은 방식으로 움직이는 편이 낫다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class TextClientRouter {

  private final List<TextGenerationClient> clients;
  private final SystemConfigService systemConfigService;

  /**
   * 지금 써야 할 제공자: 사슬(첫 제공자 + 실패 시 다음 제공자) 중 쓸 수 있는 것
   * 1개면 그 제공자 그대로 (대체 설정이 비어 있으면 #1083 이전과 같은 동작), 2개 이상이면 실패 시 넘기는 묶음
   *
   * @throws CustomException 사슬에 쓸 수 있는 제공자가 하나도 없을 때(키 없음 등)
   */
  public TextGenerationClient current() {
    List<TextGenerationClient> usableChain = chain().stream()
      .map(this::of)
      .flatMap(Optional::stream)
      .filter(TextGenerationClient::available)
      .toList();
    if (usableChain.isEmpty()) {
      log.error("텍스트 제공자를 쓸 수 없습니다. 키가 설정되지 않았습니다: chain={}", chain());
      throw new CustomException(ErrorCode.TEXT_PROVIDER_UNAVAILABLE);
    }
    return usableChain.size() == 1 ? usableChain.get(0) : new FallbackTextGenerationClient(usableChain);
  }

  /**
   * 시도 순서: 첫 제공자(TEXT_PROVIDER_SELECTED) > 실패 시 다음 제공자(TEXT_PROVIDER_FALLBACKS) 순 (중복 제거)
   * 모르는 이름은 건너뜀 (설정 하나 때문에 일과 생성이 멈추지 않게)
   */
  public List<TextProvider> chain() {
    Set<TextProvider> ordered = new LinkedHashSet<>();
    ordered.add(selected());
    String fallbacks = systemConfigService.getString(ConfigKey.TEXT_PROVIDER_FALLBACKS);
    for (String name : SystemConfigValueValidator.splitListItems(fallbacks)) {
      try {
        ordered.add(TextProvider.valueOf(name.toUpperCase(Locale.ROOT)));
      } catch (IllegalArgumentException e) {
        log.warn("알 수 없는 대체 텍스트 제공자 설정, 건너뛴다: value={}", name);
      }
    }
    return List.copyOf(ordered);
  }

  public Optional<TextGenerationClient> of(TextProvider provider) {
    return clients.stream().filter(client -> client.provider() == provider).findFirst();
  }

  /// 관리자 화면이 제공자별 상태(단가·키 유무)를 나열할 때 쓴다.
  public List<TextGenerationClient> all() {
    return clients;
  }

  /**
   * 설정에 적힌 제공자 이름을 읽는다.
   *
   * <p>값이 손상됐거나 없어진 이름이어도 기본 제공자로 떨어진다. 설정 하나 때문에
   * 일과 생성 전체가 멈추면 안 된다 — 이미지 라우터와 같은 방침이다.
   */
  public TextProvider selected() {
    String raw = systemConfigService.getString(ConfigKey.TEXT_PROVIDER_SELECTED);
    try {
      return TextProvider.valueOf(raw.trim());
    } catch (IllegalArgumentException e) {
      log.warn("알 수 없는 텍스트 제공자 설정, 기본값을 쓴다: value={}", raw);
      return TextProvider.GEMINI;
    }
  }
}
