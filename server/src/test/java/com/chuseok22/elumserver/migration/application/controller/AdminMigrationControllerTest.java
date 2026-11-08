package com.chuseok22.elumserver.migration.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.service.AdminAuditService;
import com.chuseok22.elumserver.admin.application.service.SettingsEditorService;
import com.chuseok22.elumserver.admin.core.AdminAuditAction;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.migration.application.service.MigrationSyncStatusService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.web.servlet.mvc.support.RedirectAttributesModelMap;

/**
 * 서버 이전 버튼 (#1062): 실패는 오류 코드 안내 + 기록 없음, 멈춤 표식이 없던 재개는 기록 없음
 * 깨지면: 요청이 안 남았는데 관리자는 성공으로 알거나, 하지 않은 일이 관리자 기록에 남는다
 */
class AdminMigrationControllerTest {

  private final MigrationSyncStatusService migrationSyncStatusService = mock(MigrationSyncStatusService.class);
  private final AdminAuditService adminAuditService = mock(AdminAuditService.class);
  private final AdminMigrationController controller = new AdminMigrationController(
    migrationSyncStatusService, mock(SettingsEditorService.class), adminAuditService);
  private final RedirectAttributesModelMap redirect = new RedirectAttributesModelMap();

  @Test
  @DisplayName("요청 파일을 못 쓰면 E-MIG-007 오류 안내, 관리자 기록 없음")
  void requestWriteFailure_showsErrorCodeWithoutAudit() {
    doThrow(new CustomException(ErrorCode.MIGRATION_SYNC_REQUEST_FAILED))
      .when(migrationSyncStatusService).requestSync(any());

    String view = controller.requestSync(() -> "admin", redirect);

    assertThat(view).isEqualTo("redirect:/admin/migration");
    assertThat((String) redirect.getFlashAttributes().get("errorMessage")).contains("E-MIG-007");
    verify(adminAuditService, never()).record(any(), any(), any());
  }

  @Test
  @DisplayName("멈춤 표식이 원래 없던 재개는 안내만 하고 기록하지 않는다")
  void resumeWithoutMarker_doesNotRecord() {
    when(migrationSyncStatusService.resume()).thenReturn(false);

    controller.resume(redirect);

    assertThat((String) redirect.getFlashAttributes().get("message")).contains("이미");
    verify(adminAuditService, never()).record(any(), any(), any());
  }

  @Test
  @DisplayName("멈춤이 성공하면 대상 migration-sync 로 관리자 기록 1건")
  void pause_recordsAudit() {
    controller.pause(() -> "admin", redirect);

    verify(adminAuditService).record(AdminAuditAction.MIGRATION_SYNC_PAUSED, "migration-sync", null);
    assertThat((String) redirect.getFlashAttributes().get("message")).contains("멈췄어요");
  }
}
