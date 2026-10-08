package com.chuseok22.elumserver.admin.application.dto.response;

/**
 * @param configuredLevel 이 로거에 직접 걸린 레벨. 없으면 부모를 따른다(null)
 * @param effectiveLevel  실제로 적용되는 레벨
 * @param changed         화면에서 바꿔 원래 값과 다를 수 있음 — "원래대로" 버튼 노출
 */
public record LoggerLevelResponse(
  String name,
  String configuredLevel,
  String effectiveLevel,
  boolean changed
) {

}
