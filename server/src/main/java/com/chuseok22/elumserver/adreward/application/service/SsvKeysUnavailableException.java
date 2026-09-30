package com.chuseok22.elumserver.adreward.application.service;

/// 서명을 확인할 공개키를 받지 못했다. **서명이 틀린 것과 다르다** — 지급하지 않되 5xx 로 답해 Google 이 다시 보내게 한다 (#463).
public class SsvKeysUnavailableException extends RuntimeException {

  public SsvKeysUnavailableException(String message) {
    super(message);
  }

  public SsvKeysUnavailableException(String message, Throwable cause) {
    super(message, cause);
  }
}
