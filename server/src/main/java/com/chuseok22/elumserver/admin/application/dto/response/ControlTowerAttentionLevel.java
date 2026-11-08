package com.chuseok22.elumserver.admin.application.dto.response;

import com.fasterxml.jackson.annotation.JsonValue;
import java.util.Locale;

/** 관제소 확인할 일 수준 4개 (attention v1 level): ok, info, warning, critical */
public enum ControlTowerAttentionLevel {
  OK,
  INFO,
  WARNING,
  CRITICAL;

  @JsonValue
  public String toJsonValue() {
    return name().toLowerCase(Locale.ROOT);
  }
}
