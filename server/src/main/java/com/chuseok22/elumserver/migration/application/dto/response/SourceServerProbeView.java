package com.chuseok22.elumserver.migration.application.dto.response;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 옛 서버 안내 상태 (#1062): 응답 여부, 점검 여부, 안내하는 새 주소가 맞는지
 * 응답을 읽지 못했으면 점검·안내 칸은 null
 */
public record SourceServerProbeView(
  String sourceBaseUrl,
  String expectedNewServerBaseUrl,
  State state,
  // 응답을 받았을 때의 상태 코드
  Integer httpStatus,
  // 응답 없음·오류·형식 다름의 원인 (예외 이름, "HTTP 503" 등), 정상이면 null
  String failureReason,
  Boolean isMaintenance,
  // 옛 서버가 앱에 안내하는 주소 (server.apiBaseUrl)
  String announcedApiBaseUrl,
  boolean isAnnouncingNewServer
) {

  /// 응답 상태 4개: 정상 응답, 오류 상태 코드, 응답 없음, 응답 형식 다름 (tone: 배지 색 이름, admin-ui.html toneBadge)
  @Getter
  @AllArgsConstructor
  public enum State {
    RESPONDED("응답함", "success"),
    HTTP_ERROR("오류 응답", "error"),
    UNREACHABLE("응답 없음", "error"),
    UNEXPECTED_RESPONSE("응답 형식이 달라요", "warning"),
    ;

    private final String label;
    private final String tone;
  }

  public boolean isResponded() {
    return state == State.RESPONDED;
  }
}
