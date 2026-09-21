package com.chuseok22.elumserver.common.application.controller;

import com.chuseok22.elumserver.common.application.dto.response.AppStatusResponse;
import com.chuseok22.elumserver.common.application.dto.response.AppStatusResponse.VersionRequirement;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.chuseok22.logging.annotation.LogMonitoring;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 앱 시작 시 서버 상태를 알려준다 (이슈 #279).
 *
 * <p><b>이 엔드포인트는 점검 중에도 살아 있어야 한다.</b> 여기까지 막으면 앱이 점검
 * 사실을 받을 방법이 없어 무한 로딩이나 알 수 없는 오류로 보인다.
 */
@RestController
@RequiredArgsConstructor
public class AppStatusController implements AppStatusControllerDocs {

  private final SystemConfigService systemConfigService;

  @Override
  @LogMonitoring(logParameters = true, logResult = true, logExecutionTime = true)
  @GetMapping("/api/app/status")
  public ResponseEntity<AppStatusResponse> status() {
    return ResponseEntity.ok(new AppStatusResponse(
      systemConfigService.getBoolean(ConfigKey.MAINTENANCE_MODE),
      systemConfigService.getString(ConfigKey.MAINTENANCE_MESSAGE),
      new VersionRequirement(
        systemConfigService.getString(ConfigKey.MIN_APP_VERSION_IOS),
        systemConfigService.getString(ConfigKey.LATEST_APP_VERSION_IOS)
      ),
      new VersionRequirement(
        systemConfigService.getString(ConfigKey.MIN_APP_VERSION_ANDROID),
        systemConfigService.getString(ConfigKey.LATEST_APP_VERSION_ANDROID)
      )
    ));
  }
}
