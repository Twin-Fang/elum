package com.chuseok22.elumserver.systemconfig.application.service;

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
  boolean changed
) {

}
