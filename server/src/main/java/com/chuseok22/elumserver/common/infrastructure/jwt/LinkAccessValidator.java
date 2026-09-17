package com.chuseok22.elumserver.common.infrastructure.jwt;

/**
 * 이룸이 휴대폰 토큰이 아직 살아 있는 연결의 것인지 판단한다 (이슈 #200).
 *
 * <p><b>연결을 끊어도 이미 발급된 액세스 토큰은 만료까지 살아 있다.</b> 리프레시 토큰만
 * 폐기하면 최대 하루 동안 그 휴대폰이 계속 일과를 본다 — 잃어버린 휴대폰을 끊는 것이
 * 이 기능의 존재 이유인데 하루를 기다려야 하면 의미가 없다. 그래서 요청마다 확인한다.
 *
 * <p>구현은 link 도메인에 둔다 — common이 link.application을 직접 의존하지 않도록
 * 인터페이스만 여기에 둔다 ({@link TokenAccessValidator}와 같은 패턴).
 */
public interface LinkAccessValidator {

  /** 이 연결이 아직 유효한가. linkId가 없으면(옛 토큰) 거부한다. */
  boolean isLinkActive(String linkId);
}
