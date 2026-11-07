package com.chuseok22.elumserver.migration.application.controller;

import com.chuseok22.elumserver.admin.application.service.AdminAuditService;
import com.chuseok22.elumserver.admin.core.AdminAuditAction;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorMessages;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.migration.application.service.MigrationSettingsReader;
import com.chuseok22.elumserver.migration.application.service.MigrationSyncStatusService;
import java.security.Principal;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/**
 * 관리자 > 시스템 > 서버 이전 화면 (#1062): 동기화·검사 상태, 이전 설정, 요청 버튼 4개
 * 버튼은 NAS 표식 파일만 만들거나 지움 (실행은 NAS 1분 작업). 성공한 버튼만 관리자 기록 1건
 */
@Controller
@RequiredArgsConstructor
public class AdminMigrationController {

  // 관리자 기록 대상 id (이전 동기화는 대상이 하나뿐)
  static final String MIGRATION_SYNC_TARGET_ID = "migration-sync";
  private static final String REDIRECT_TO_PAGE = "redirect:/admin/migration";

  private final MigrationSyncStatusService migrationSyncStatusService;
  private final MigrationSettingsReader migrationSettingsReader;
  private final AdminAuditService adminAuditService;

  /// 화면: 동기화 상태 > 이전 설정 (각자 실패를 상태로 돌려줘 화면은 늘 뜸)
  @GetMapping("/admin/migration")
  public String page(Model model) {
    model.addAttribute("overview", migrationSyncStatusService.readOverview());
    model.addAttribute("settings", migrationSettingsReader.read());
    return "admin/migration";
  }

  @PostMapping("/admin/migration/sync-request")
  public String requestSync(Principal principal, RedirectAttributes redirectAttributes) {
    try {
      migrationSyncStatusService.requestSync(adminNameOf(principal));
      adminAuditService.record(AdminAuditAction.MIGRATION_SYNC_REQUESTED, MIGRATION_SYNC_TARGET_ID, null);
      redirectAttributes.addFlashAttribute("message", "동기화를 요청했어요. NAS 가 1분 안에 시작해요.");
    } catch (CustomException e) {
      redirectAttributes.addFlashAttribute("errorMessage", failureMessageOf(e));
    }
    return REDIRECT_TO_PAGE;
  }

  @PostMapping("/admin/migration/verify-request")
  public String requestVerify(Principal principal, RedirectAttributes redirectAttributes) {
    try {
      migrationSyncStatusService.requestVerify(adminNameOf(principal));
      adminAuditService.record(AdminAuditAction.MIGRATION_VERIFY_REQUESTED, MIGRATION_SYNC_TARGET_ID, null);
      redirectAttributes.addFlashAttribute("message", "정합성 검사를 요청했어요. NAS 가 1분 안에 시작해요.");
    } catch (CustomException e) {
      redirectAttributes.addFlashAttribute("errorMessage", failureMessageOf(e));
    }
    return REDIRECT_TO_PAGE;
  }

  @PostMapping("/admin/migration/pause")
  public String pause(Principal principal, RedirectAttributes redirectAttributes) {
    try {
      migrationSyncStatusService.pause(adminNameOf(principal));
      adminAuditService.record(AdminAuditAction.MIGRATION_SYNC_PAUSED, MIGRATION_SYNC_TARGET_ID, null);
      redirectAttributes.addFlashAttribute("message", "정기 동기화를 멈췄어요. 재개를 누를 때까지 돌지 않아요.");
    } catch (CustomException e) {
      redirectAttributes.addFlashAttribute("errorMessage", failureMessageOf(e));
    }
    return REDIRECT_TO_PAGE;
  }

  /// 재개: 멈춤 표식이 원래 없었으면 기록 없이 안내만
  @PostMapping("/admin/migration/resume")
  public String resume(RedirectAttributes redirectAttributes) {
    try {
      boolean isResumed = migrationSyncStatusService.resume();
      if (isResumed) {
        adminAuditService.record(AdminAuditAction.MIGRATION_SYNC_RESUMED, MIGRATION_SYNC_TARGET_ID, null);
      }
      redirectAttributes.addFlashAttribute("message",
        isResumed ? "정기 동기화를 다시 시작했어요." : "이미 정기 동기화가 돌고 있어요.");
    } catch (CustomException e) {
      redirectAttributes.addFlashAttribute("errorMessage", failureMessageOf(e));
    }
    return REDIRECT_TO_PAGE;
  }

  // 관리자 화면은 한국어 고정 (오류 코드 포함 문구)
  private static String failureMessageOf(CustomException e) {
    return ErrorMessages.standard().of(e.getErrorCode(), AppLocale.KO);
  }

  /// 표식 내용에 남길 관리자 아이디 (세션이 없으면 null > 서비스가 unknown)
  private static String adminNameOf(Principal principal) {
    return principal == null ? null : principal.getName();
  }
}
