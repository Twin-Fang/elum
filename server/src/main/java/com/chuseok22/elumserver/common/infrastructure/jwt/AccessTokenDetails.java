package com.chuseok22.elumserver.common.infrastructure.jwt;

/**
 * 인증 객체에 토큰에서 읽은 것을 더 싣는다 (다중 보호자 1단계).
 *
 * <p>이룸이 휴대폰 토큰의 {@code linkId} 는 필터만 읽고 버리고 있었다. 이룸이 휴대폰이 어느 이룸이를
 * 보는지는 이 값({@code device_link.profile_id})으로 정해야 해서 서비스까지 가져간다 (명세 4-5).
 *
 * @param linkId 이룸이 휴대폰 토큰이면 연결 ID, 보호자 토큰이면 null
 */
public record AccessTokenDetails(String linkId) {

}
