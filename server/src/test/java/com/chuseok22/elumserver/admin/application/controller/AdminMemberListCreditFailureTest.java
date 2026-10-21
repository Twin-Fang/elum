package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.chuseok22.elumserver.admin.application.service.AdminMemberAccessService;
import com.chuseok22.elumserver.member.application.service.MemberAdminMemoService;
import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberResponse;
import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.list.AdminListRow;
import com.chuseok22.elumserver.admin.application.service.AdminCreditQueryService;
import com.chuseok22.elumserver.admin.application.service.AdminMemberService;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

/**
 * 회원 목록 크레딧 열 조회 실패 (#651): 목록은 그대로, 크레딧 칸만 "-" 와 크레딧 상세 링크
 */
@ExtendWith(OutputCaptureExtension.class)
class AdminMemberListCreditFailureTest {

  @Test
  @DisplayName("크레딧 집계가 터져도 회원 목록은 열리고, 크레딧 칸은 - 로 두되 크레딧 화면 링크는 건다")
  void list_creditLookupFails_stillRendersRows(CapturedOutput output) throws Exception {
    AdminMemberService adminMemberService = mock(AdminMemberService.class);
    AdminCreditQueryService adminCreditQueryService = mock(AdminCreditQueryService.class);
    Member member = new Member();
    member.setId("m1");
    member.setUsername("parent1");
    member.setStatus(MemberStatus.ACTIVE);
    when(adminMemberService.search(any())).thenReturn(new PageImpl<>(List.of(
      AdminMemberResponse.of(member, null, 0, null, null, null, null))));
    when(adminCreditQueryService.currentWeekRemainingByMemberId(anyCollection()))
      .thenThrow(new IllegalStateException("db down"));
    MockMvc mockMvc = MockMvcBuilders.standaloneSetup(
      new AdminMemberController(adminMemberService, new AdminDateFormatter(), adminCreditQueryService,
        mock(AdminMemberAccessService.class), mock(MemberAdminMemoService.class))).build();

    MvcResult result = mockMvc.perform(get("/admin/members")).andExpect(status().isOk()).andReturn();

    @SuppressWarnings("unchecked")
    List<AdminListRow> rows = (List<AdminListRow>) result.getModelAndView().getModel().get("rows");
    assertThat(rows).hasSize(1);
    assertThat(rows.get(0).cells().get("currentWeekCredit")).isEqualTo("-");
    assertThat(rows.get(0).cellLinks().get("currentWeekCredit")).isEqualTo("/admin/credits/members/m1");
    assertThat(output).contains("[admin members] credit summary failed");
  }
}
