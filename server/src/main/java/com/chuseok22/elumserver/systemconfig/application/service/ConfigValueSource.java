package com.chuseok22.elumserver.systemconfig.application.service;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 지금 적용 값의 출처: DB 저장값 > 배포 설정(yml) > 코드 기본값 순으로 앞의 것이 있으면 그것
 * yml 은 DB 값이 비었을 때만 씀 (첫 기동 시 yml 값이 DB 에 시딩되면 이후 yml 변경은 반영 안 됨)
 */
@Getter
@AllArgsConstructor
public enum ConfigValueSource {

  STORED("DB 저장값"),
  DEPLOY_PROPERTY("배포 설정(yml)"),
  CODE_DEFAULT("코드 기본값"),
  ;

  private final String label;
}
