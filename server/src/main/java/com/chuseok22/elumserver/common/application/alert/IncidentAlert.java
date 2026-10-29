package com.chuseok22.elumserver.common.application.alert;

import java.util.List;

/**
 * 장애 알림 1건: 종류 + 원인 키(쿨다운 묶음 단위) + 본문 항목
 * 항목 값은 유형·건수·경로 템플릿·상태 코드·에러 코드만 (개인정보·원문·토큰 금지, 서비스 원칙 5)
 */
public record IncidentAlert(IncidentAlertType type, String causeKey, List<Detail> details) {

  public IncidentAlert {
    causeKey = causeKey == null ? "" : causeKey;
    details = details == null ? List.of() : List.copyOf(details);
  }

  /** 쿨다운 키: {종류}:{원인 키} */
  public String cooldownKey() {
    return type.name() + ":" + causeKey;
  }

  /** 본문 한 줄: {이름}: {값} */
  public record Detail(String name, String value) {
  }
}
