package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.core.ImageProvider;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.util.List;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 설정에 적힌 제공자를 골라 준다.
 *
 * <p>부르는 쪽(일과 생성 파이프라인 등)은 이 라우터만 알고 제공자 이름은 모른다.
 * 관리자가 화면에서 제공자를 바꾸면 다음 호출부터 바로 반영된다 — 설정 캐시가
 * 30초 안에 모든 인스턴스로 퍼진다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ImageClientRouter {

  private final List<ImageGenerationClient> clients;
  private final SystemConfigService systemConfigService;

  /**
   * 지금 써야 할 제공자.
   *
   * @throws CustomException 고른 제공자를 쓸 수 없을 때(키 없음 등)
   */
  public ImageGenerationClient current() {
    ImageProvider selected = selected();
    return of(selected)
      .filter(ImageGenerationClient::available)
      .orElseThrow(() -> {
        log.error("이미지 제공자를 쓸 수 없습니다. 키가 설정되지 않았습니다: provider={}", selected);
        return new CustomException(ErrorCode.IMAGE_PROVIDER_UNAVAILABLE);
      });
  }

  public Optional<ImageGenerationClient> of(ImageProvider provider) {
    return clients.stream().filter(client -> client.provider() == provider).findFirst();
  }

  /// 관리자 화면이 제공자별 상태(단가·키 유무·캐릭터 지원)를 나열할 때 쓴다.
  public List<ImageGenerationClient> all() {
    return clients;
  }

  /**
   * 설정에 적힌 제공자 이름을 읽는다.
   *
   * <p>값이 손상됐거나 없어진 이름이어도 기본 제공자로 떨어진다. 설정 하나 때문에
   * 카드 생성 전체가 멈추면 안 된다 — 설정 파싱 실패를 기본값으로 덮는 기존 방침과 같다.
   */
  public ImageProvider selected() {
    String raw = systemConfigService.getString(ConfigKey.IMAGE_PROVIDER_SELECTED);
    try {
      return ImageProvider.valueOf(raw.trim());
    } catch (IllegalArgumentException e) {
      log.warn("알 수 없는 이미지 제공자 설정, 기본값을 쓴다: value={}", raw);
      return ImageProvider.GEMINI;
    }
  }
}
