package com.chuseok22.elumserver.systemconfig.application.service;

import com.chuseok22.elumserver.systemconfig.core.ConfigFormat;
import com.chuseok22.elumserver.systemconfig.core.ConfigGroup;
import com.chuseok22.elumserver.systemconfig.core.ConfigValueType;
import java.util.List;

// 관리자 시스템 설정 화면 표시용. changed는 현재값이 기본값과 다른지 여부.
public record SystemConfigView(
  String key,
  ConfigGroup group,
  String label,
  String description,
  ConfigValueType valueType,
  List<String> allowedValues,
  String value,
  String defaultValue,
  boolean changed,
  // INTEGER 허용 범위. 화면 입력칸이 먼저 막고, 서버가 다시 막는다.
  Integer minValue,
  Integer maxValue,
  /** 문자열 형식 규칙 (화면 안내·회원 고르기 위젯 구분) */
  ConfigFormat format,
  /** 저장된 값이 지금 규칙에 어긋나면 그 이유, 맞으면 null (저장 시에만 막으므로 옛 값이 남아 있을 수 있음) */
  String validationWarning,
  /** 지금 적용 값의 출처 */
  ConfigValueSource valueSource,
  /** 배포 설정(yml)에 묶인 키의 yml 값. 묶이지 않았거나 비었으면 null */
  String deployPropertyValue
) {

}
