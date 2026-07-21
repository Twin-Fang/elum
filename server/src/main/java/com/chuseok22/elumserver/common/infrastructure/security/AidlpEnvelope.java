package com.chuseok22.elumserver.common.infrastructure.security;

// 클라이언트가 보내는 암호문 봉투. 요청 본문은 {"encrypted":{ciphertext,iv,salt}} 형태다.
public record AidlpEnvelope(String ciphertext, String iv, String salt) {

  public boolean isComplete() {
    return ciphertext != null && !ciphertext.isBlank()
      && iv != null && !iv.isBlank()
      && salt != null && !salt.isBlank();
  }
}
