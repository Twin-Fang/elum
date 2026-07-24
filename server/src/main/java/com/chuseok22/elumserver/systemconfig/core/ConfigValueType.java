package com.chuseok22.elumserver.systemconfig.core;

// 설정 값의 타입. 저장은 전부 문자열로 하되, 수정 시 이 타입으로 검증하고
// 관리자 화면의 입력 위젯(인풋/셀렉트)을 결정한다.
public enum ConfigValueType {
  STRING,
  INTEGER,
  DECIMAL,
  SELECT,
}
