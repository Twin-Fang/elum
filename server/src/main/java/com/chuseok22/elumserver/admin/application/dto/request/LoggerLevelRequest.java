package com.chuseok22.elumserver.admin.application.dto.request;

/** @param level 비우면 처음 바꾸기 전 값으로 되돌린다 */
public record LoggerLevelRequest(
  String logger,
  String level
) {

}
