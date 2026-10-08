package com.chuseok22.elumserver.adreward.application.service;

/**
 * 서명이 확인된 Google 콜백에서 우리가 쓰는 값만.
 *
 * <p>`reward_amount`·`reward_item` 은 일부러 싣지 않는다 — 지급량은 서버 설정이 정한다(클라이언트가 광고를 요청할 때 넣는
 * 값이라 믿을 수 없다).
 *
 * @param adUnit        광고 단위 ID의 숫자 부분
 * @param customData    앱이 광고 요청에 실은 값. 우리가 발급한 세션 nonce
 * @param transactionId Google 이 시청 한 번마다 붙이는 고유 ID
 * @param userId        앱이 광고 요청에 실은 사용자 ID. 참고용이다(회원은 nonce 로 안다)
 */
public record SsvCallback(String adUnit, String customData, String transactionId, String userId) {

}
