package com.chuseok22.elumserver.common.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;

/**
 * 앱이 시작할 때 서버에 묻는 것 (이슈 #279).
 *
 * <p>지금 서버가 점검 중인지, 이 앱 버전으로 계속 써도 되는지를 한 번에 돌려준다.
 */
@Schema(description = "앱 시작 시 확인하는 서버 상태")
public record AppStatusResponse(
  @Schema(description = "점검 중인가. true면 앱은 점검 안내만 보여준다", example = "false")
  boolean maintenance,

  @Schema(description = "점검 안내 문구", example = "잠시 점검하고 있어요. 조금 뒤에 다시 열어주세요")
  String maintenanceMessage,

  @Schema(description = "iOS 버전 요구")
  VersionRequirement ios,

  @Schema(description = "Android 버전 요구")
  VersionRequirement android
) {

  /**
   * 버전 조건. 비어 있으면 그 조건은 없는 것이다.
   *
   * <p>비교는 앱이 semver로 한다 — 문자열로 견주면 {@code 1.10.0} 이 {@code 1.9.0} 보다
   * 낮다고 나온다.
   */
  @Schema(description = "플랫폼별 버전 요구")
  public record VersionRequirement(
    @Schema(description = "이 버전 미만이면 업데이트해야 쓸 수 있다. 비면 막지 않는다", example = "1.2.0")
    String minVersion,

    @Schema(description = "이 버전 미만이면 업데이트를 권한다. 건너뛸 수 있다", example = "1.21.0")
    String latestVersion
  ) {}
}
