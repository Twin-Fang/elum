package com.chuseok22.elumserver.adreward.application.service;

/// Google 콜백의 서명·형식이 맞지 않는다. 지급하지 않고 400 으로 답한다.
public class SsvInvalidException extends RuntimeException {

  public SsvInvalidException(String message) {
    super(message);
  }
}
