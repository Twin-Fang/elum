package com.chuseok22.elumserver.migration.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * NAS 스크립트와 주고받는 표식 파일 3개 (#1062): 멈춤, 동기화 요청, 정합성 검사 요청
 * 있는지만 본다. 내용은 한 줄 "{ISO 시각} {관리자 이름}" (NAS 스크립트와 맞춘 이름이라 바꾸지 않는다)
 */
@Getter
@AllArgsConstructor
public enum MigrationControlFile {

  SYNC_PAUSED("SYNC_PAUSED"),
  SYNC_REQUESTED("SYNC_REQUESTED"),
  VERIFY_REQUESTED("VERIFY_REQUESTED"),
  ;

  private final String fileName;
}
