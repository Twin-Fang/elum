package com.chuseok22.elumserver.admin.application.dto.response;

import java.time.Instant;

/**
 * @param opposite          직전 배포 색 (local 이면 null)
 * @param oppositeLastWrite 직전 배포 elum.log 의 마지막 기록 시각 (없으면 null)
 */
public record LogInstanceResponse(
  String instance,
  String port,
  String version,
  Instant startedAt,
  String opposite,
  Instant oppositeLastWrite
) {

}
