package com.chuseok22.elumserver.systemconfig.core;

// 설정 값의 타입. 저장은 전부 문자열로 하되, 수정 시 이 타입으로 검증하고
// 관리자 화면의 입력 위젯(인풋/셀렉트)을 결정한다.
public enum ConfigValueType {
  STRING,
  INTEGER,
  DECIMAL,
  SELECT,
  // 켜짐/꺼짐. 저장값은 "true"/"false" 문자열이고 화면은 토글로 그린다.
  BOOLEAN,
  // 날짜와 시각 (예: 2026-10-19T00:00). 저장은 문자열, 화면은 날짜 선택기로 그린다.
  DATETIME,
  // 외부 API 키 같은 비밀값. DB에는 암호문으로 들어가고 화면에는 가려서 보여준다.
  SECRET,
}
