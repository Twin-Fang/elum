package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.ai.core.TextProvider;
import com.chuseok22.elumserver.ai.infrastructure.client.TextGenerationClient;

/**
 * 관리자 설정 화면에 보여줄 텍스트 제공자 상태.
 *
 * <p>이미지({@link AdminImageProviderView})와 달리 단가가 둘이다 — 텍스트는 장당이
 * 아니라 입력·출력 토큰을 따로 셈하기 때문이다. 그래서 "장당 얼마"처럼 한 줄로
 * 비교되지 않고, 두 값을 나란히 보여준 뒤 판단은 관리자에게 맡긴다.
 *
 * @param available 키가 있어 지금 쓸 수 있는가. false면 전환 버튼을 막는다
 */
public record AdminTextProviderView(
  String name,
  String label,
  boolean selected,
  boolean available,
  double inputPricePer1M,
  double outputPricePer1M
) {

  public static AdminTextProviderView of(
    TextGenerationClient client, TextProvider current, double inputPrice, double outputPrice
  ) {
    return new AdminTextProviderView(
      client.provider().name(),
      client.provider().getLabel(),
      client.provider() == current,
      client.available(),
      inputPrice,
      outputPrice
    );
  }
}
