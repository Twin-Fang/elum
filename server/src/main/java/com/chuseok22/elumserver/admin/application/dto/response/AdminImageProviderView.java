package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.ai.core.ImageProvider;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageGenerationClient;

/**
 * 관리자 설정 화면에 보여줄 이미지 제공자 상태.
 *
 * @param available          키가 있어 지금 쓸 수 있는가. false면 전환 버튼을 막는다
 * @param characterConsistent 캐릭터 일관성을 지키는가. false면 경고를 띄운다
 * @param pricePerImage      장당 단가(USD). 제공자를 고를 때 가장 먼저 보는 값이다
 */
public record AdminImageProviderView(
  String name,
  String label,
  boolean selected,
  boolean available,
  boolean characterConsistent,
  double pricePerImage
) {

  public static AdminImageProviderView of(
    ImageGenerationClient client, ImageProvider current, double pricePerImage
  ) {
    return new AdminImageProviderView(
      client.provider().name(),
      client.provider().getLabel(),
      client.provider() == current,
      client.available(),
      client.supportsCharacterReference(),
      pricePerImage
    );
  }
}
