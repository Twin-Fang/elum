package com.chuseok22.elumserver.systemconfig.application.controller;

import com.chuseok22.elumserver.systemconfig.application.dto.response.AppStatusResponse;
import com.chuseok22.elumserver.systemconfig.application.dto.response.AppStatusResponse.ClientTuning;
import com.chuseok22.elumserver.systemconfig.application.dto.response.AppStatusResponse.ServerAddress;
import com.chuseok22.elumserver.systemconfig.application.dto.response.AppStatusResponse.VersionRequirement;
import com.chuseok22.elumserver.systemconfig.application.service.MigrationLock;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.chuseok22.elumserver.systemconfig.core.ServerAddressPolicy;
import com.chuseok22.logging.annotation.LogMonitoring;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 앱 시작 시 서버 상태를 알려준다.
 *
 * <p><b>이 엔드포인트는 점검 중에도 살아 있어야 한다.</b> 여기까지 막으면 앱이 점검
 * 사실을 받을 방법이 없어 무한 로딩이나 알 수 없는 오류로 보인다.
 */
@Slf4j
@RestController
@RequiredArgsConstructor
public class AppStatusController implements AppStatusControllerDocs {

  private final SystemConfigService systemConfigService;
  private final MigrationLock migrationLock;

  @Override
  @LogMonitoring(logParameters = true, logResult = true, logExecutionTime = true)
  @GetMapping("/api/app/status")
  public ResponseEntity<AppStatusResponse> status() {
    return ResponseEntity.ok(new AppStatusResponse(
      systemConfigService.getBoolean(ConfigKey.MAINTENANCE_MODE),
      systemConfigService.getString(ConfigKey.MAINTENANCE_MESSAGE),
      new VersionRequirement(
        systemConfigService.getString(ConfigKey.MIN_APP_VERSION_IOS),
        systemConfigService.getString(ConfigKey.LATEST_APP_VERSION_IOS),
        systemConfigService.getString(ConfigKey.IOS_STORE_URL)
      ),
      new VersionRequirement(
        systemConfigService.getString(ConfigKey.MIN_APP_VERSION_ANDROID),
        systemConfigService.getString(ConfigKey.LATEST_APP_VERSION_ANDROID),
        systemConfigService.getString(ConfigKey.ANDROID_STORE_URL)
      ),
      new ClientTuning(
        systemConfigService.getInt(ConfigKey.APP_CONNECT_TIMEOUT_MS),
        systemConfigService.getInt(ConfigKey.APP_RECEIVE_TIMEOUT_MS),
        systemConfigService.getInt(ConfigKey.APP_LOADING_MAX_WAIT_MS),
        systemConfigService.getInt(ConfigKey.APP_CONSENT_FETCH_TIMEOUT_MS),
        systemConfigService.getInt(ConfigKey.APP_DLP_MIN_DELAY_MS)
      ),
      new ServerAddress(resolveNewApiBaseUrl())
    ));
  }

  /**
   * 새 서버 주소 설정 > 앱에 보낼 값 (빈 값·허용 목록 밖 > null)
   */
  private String resolveNewApiBaseUrl() {
    String newServerBaseUrl = migrationLock.newServerBaseUrl().orElse(null);
    if (newServerBaseUrl == null) {
      return null;
    }
    // 저장 검증을 거치지 않고 DB 에 들어간 값 방어 (앱도 다시 거른다)
    if (!ServerAddressPolicy.isAllowed(newServerBaseUrl)) {
      log.warn("[app status] new server address ignored : not allowed host");
      return null;
    }
    return newServerBaseUrl;
  }
}
