package com.chuseok22.elumserver.member.core;

/**
 * 보호자 닉네임 판정 결과 3개: 사용 가능, 형식 오류, 쓸 수 없는 이름(욕설·예약어)
 */
public enum NicknameVerdict {
  ALLOWED,
  INVALID_FORMAT,
  NOT_ALLOWED
}
