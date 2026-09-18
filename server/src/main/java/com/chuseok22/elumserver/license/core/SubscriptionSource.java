package com.chuseok22.elumserver.license.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 이 구독이 <b>어떻게</b> 생겼는가. 나중에 결제를 붙일 자리다.
 *
 * <p>지금은 {@link #MANUAL}만 쓴다. 앱 스토어 심사를 아직 받지 않아 인앱결제를 붙일 수
 * 없기 때문이다. 심사가 끝나 영수증 검증이 생기면 그 서비스가 {@code APPLE_IAP} 또는
 * {@code GOOGLE_IAP}로 구독 행을 쓰고, <b>권한을 묻는 코드는 한 줄도 바뀌지 않는다.</b>
 */
@Getter
@AllArgsConstructor
public enum SubscriptionSource {

  /// 회원가입 시 자동으로 생기는 Free 구독.
  SIGNUP("가입 기본"),
  /// 관리자가 직접 켠 것. 데모·베타·내부 테스트용.
  MANUAL("관리자 발급"),
  APPLE_IAP("App Store 결제"),
  GOOGLE_IAP("Google Play 결제"),
  PROMO("프로모션"),
  ;

  private final String label;
}
