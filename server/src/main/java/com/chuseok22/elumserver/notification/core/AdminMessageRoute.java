package com.chuseok22.elumserver.notification.core;

import java.util.Optional;
import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 운영자 알림을 눌렀을 때 갈 화면 4개: 홈, 요금제, 내 크레딧, 이룸이 기기 연결(#1409)
 * wire 는 푸시 data·알림 목록의 route 값 (앱 admin_message_route.dart 와 같은 값, 모르는 값이면 앱은 홈)
 */
@Getter
@AllArgsConstructor
public enum AdminMessageRoute {

  HOME("home", "홈"),
  PLAN("plan", "요금제"),
  MY_CREDIT("myCredit", "내 크레딧"),
  // 앱이 모르면 홈으로 감 (앱 admin_message_route.dart 에 deviceLink 추가 필요)
  DEVICE_LINK("deviceLink", "이룸이 기기 연결"),
  ;

  private final String wire;
  private final String label;

  /// wire 값 > 화면 (비었거나 모르는 값이면 빈 값)
  public static Optional<AdminMessageRoute> fromWire(String wire) {
    for (AdminMessageRoute route : values()) {
      if (route.wire.equals(wire)) {
        return Optional.of(route);
      }
    }
    return Optional.empty();
  }
}
