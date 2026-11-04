package com.chuseok22.elumserver.adreward.infrastructure.client;

import java.net.URI;

/**
 * 이전 잠금 중 광고 보상 콜백을 새 서버로 그대로 보내는 클라이언트 (#1053)
 * 요청에 전달 표식 헤더를 붙여, 새 서버도 잠겨 있으면 되돌려 보내지 않게 한다
 */
public interface AdSsvRelayClient {

  // 전달 표식 헤더 (값 1). 이 헤더가 있는 콜백은 다시 전달하지 않는다
  String RELAYED_HEADER = "X-Elum-Ssv-Relayed";

  /// 새 서버 콜백 주소 > 응답 상태·본문 (4xx·5xx 도 예외 없이 그대로, 연결 실패는 예외)
  RelayResponse forward(URI target);

  record RelayResponse(int status, String body) {
  }
}
