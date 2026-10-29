package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.service.AdminAuditService;
import com.chuseok22.elumserver.admin.application.service.AdminCreditQueryService;
import com.chuseok22.elumserver.admin.application.service.AdminMemberAccessService;
import com.chuseok22.elumserver.admin.application.service.AdminMemberService;
import com.chuseok22.elumserver.admin.core.AdminAuditAction;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminAuditLogRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.MemberAdminMemoService;
import com.chuseok22.elumserver.member.core.MemberAdminMemoSaveResult;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.web.servlet.mvc.support.RedirectAttributesModelMap;

/**
 * 관리자 기록 연결 (#653): 기록 실패가 본 동작을 막지 않음, 본 동작 실패면 기록 없음, 메모 원문은 기록에 안 남음
 */
class AdminAuditRecordTest {

  private static final String MEMBER_ID = "3f1c2b9a-0000-4000-8000-000000000001";

  private final AdminMemberService adminMemberService = mock(AdminMemberService.class);
  private final MemberAdminMemoService memberAdminMemoService = mock(MemberAdminMemoService.class);
  private final RedirectAttributesModelMap redirect = new RedirectAttributesModelMap();

  private AdminMemberController controllerWith(AdminAuditService adminAuditService) {
    return new AdminMemberController(adminMemberService, new AdminDateFormatter(), mock(AdminCreditQueryService.class),
      mock(AdminMemberAccessService.class), memberAdminMemoService, adminAuditService);
  }

  @Test
  @DisplayName("기록 저장이 실패해도 정지는 성공으로 끝난다 (관리자가 실패로 알고 다시 누르지 않게)")
  void suspend_succeedsEvenIfAuditSaveFails() {
    AdminAuditLogRepository failingRepository = mock(AdminAuditLogRepository.class);
    when(failingRepository.save(any())).thenThrow(new IllegalStateException("audit table down"));
    AdminAuditService realAuditService = new AdminAuditService(failingRepository, mock(PlatformTransactionManager.class));

    String view = controllerWith(realAuditService).suspend(MEMBER_ID, redirect);

    assertThat(view).isEqualTo("redirect:/admin/members/" + MEMBER_ID);
    assertThat((String) redirect.getFlashAttributes().get("message")).contains("정지했습니다");
    verify(adminMemberService).suspend(MEMBER_ID);
    verify(failingRepository).save(any());
  }

  @Test
  @DisplayName("정지가 실패하면(탈퇴 계정) 기록을 남기지 않는다 (하지 않은 일을 한 것처럼 남지 않게)")
  void suspend_failed_doesNotRecord() {
    AdminAuditService adminAuditService = mock(AdminAuditService.class);
    doThrow(new CustomException(ErrorCode.MEMBER_WITHDRAWN)).when(adminMemberService).suspend(MEMBER_ID);

    assertThatThrownBy(() -> controllerWith(adminAuditService).suspend(MEMBER_ID, redirect))
      .isInstanceOf(CustomException.class);
    verify(adminAuditService, never()).record(any(), any(), any());
  }

  @Test
  @DisplayName("회원 메모 저장 기록에는 원문 없이 글자 수만 남는다")
  void memoSaved_recordsLengthOnly() {
    AdminAuditService adminAuditService = mock(AdminAuditService.class);
    String memo = "보호자 전화 010-1234-5678 진단 관련 문의";
    when(memberAdminMemoService.saveAdminMemo(eq(MEMBER_ID), eq(memo), any()))
      .thenReturn(MemberAdminMemoSaveResult.SAVED);

    controllerWith(adminAuditService).saveMemo(MEMBER_ID, memo, null, redirect);

    ArgumentCaptor<String> detail = ArgumentCaptor.forClass(String.class);
    verify(adminAuditService).record(eq(AdminAuditAction.MEMBER_MEMO_SAVED), eq(MEMBER_ID), detail.capture());
    assertThat(detail.getValue())
      .isEqualTo("메모 " + memo.length() + "자 저장")
      .doesNotContain("010", "진단");
  }
}
