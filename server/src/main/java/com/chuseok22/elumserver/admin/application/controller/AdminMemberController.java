package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberAccessInfo;
import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberCreditSummary;
import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberDetailResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberResponse;
import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.format.AdminLogIds;
import com.chuseok22.elumserver.admin.application.list.AdminCsvExporter;
import com.chuseok22.elumserver.admin.application.list.AdminCsvExporter.ExportRows;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminMemberList;
import com.chuseok22.elumserver.admin.application.service.AdminCreditQueryService;
import com.chuseok22.elumserver.admin.application.service.AdminMemberAccessService;
import com.chuseok22.elumserver.admin.application.service.AdminMemberService;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.MemberAdminMemoService;
import com.chuseok22.elumserver.member.core.MemberAdminMemoSaveResult;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.security.Principal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

@Slf4j
@Controller
@RequiredArgsConstructor
public class AdminMemberController {

  private static final String LIST_PATH = "/admin/members";
  /// CSV 파일명 접두어: members_{yyyyMMdd}.csv
  private static final String CSV_FILE_PREFIX = "members";

  private final AdminMemberService adminMemberService;
  private final AdminDateFormatter adminDateFormatter;
  private final AdminCreditQueryService adminCreditQueryService;
  private final AdminMemberAccessService adminMemberAccessService;
  private final MemberAdminMemoService memberAdminMemoService;

  /// 회원 목록: 검색어(q), 필터(AdminMemberList 정의 7개), 정렬(sort), 페이지(page, 1부터). 허용 밖 값은 보정된다
  @GetMapping(LIST_PATH)
  public String list(@RequestParam Map<String, String> parameters, Model model) {
    AdminListQuery query = AdminListQuery.fromParameters(parameters, AdminMemberList.DEFINITION);

    Page<AdminMemberResponse> members = adminMemberService.search(query);
    // 크레딧 열: 이 페이지에 실린 회원만 한 번에 조회
    Map<String, Long> remainingCreditByMemberId = currentWeekRemainingCreditOf(members.getContent());
    model.addAttribute("members", members);
    model.addAttribute("rows", members.getContent().stream()
      .map(member -> AdminMemberList.toRow(member, remainingCreditByMemberId.get(member.id()), adminDateFormatter))
      .toList());
    model.addAttribute("definition", AdminMemberList.DEFINITION);
    model.addAttribute("query", query);
    // 페이저 링크가 검색·필터·정렬을 유지하도록 (page 는 페이저가 붙임)
    model.addAttribute("pagerBaseUrl", LIST_PATH + query.toQueryString(query.sort(), 1));
    model.addAttribute("csvExport", AdminCsvExporter.linkOf(LIST_PATH, query, members.getTotalElements()));
    return "admin/members";
  }

  /// 회원 CSV: 목록과 같은 조건 > 상한 이내면 파일, 넘으면 같은 조건 목록으로 돌아가 안내 (내보낸 관리자·건수 기록)
  @GetMapping(LIST_PATH + AdminCsvExporter.EXPORT_PATH_SUFFIX)
  public ResponseEntity<byte[]> exportCsv(
    @RequestParam Map<String, String> parameters, Principal principal,
    HttpServletRequest request, HttpServletResponse response
  ) {
    AdminListQuery query = AdminListQuery.fromParameters(parameters, AdminMemberList.DEFINITION);
    ExportRows<AdminMemberResponse> export = adminMemberService.searchForExport(query);
    if (export.isOverLimit()) {
      log.info("[admin csv] rejected members : total={} over limit", export.totalCount());
      return AdminCsvExporter.redirectOverLimit(LIST_PATH, query, export.totalCount(), request, response);
    }
    log.info("[admin csv] exported members : rows={}, admin={}", export.rows().size(), actorOf(principal));
    return AdminCsvExporter.toAttachment(CSV_FILE_PREFIX, LocalDate.now(),
      AdminMemberList.csvColumns(adminDateFormatter), export.rows());
  }

  /// 회원 상세 + 크레딧 요약 카드(탈퇴 회원은 없음) + 접속 정보(로그인 방식·마지막 앱 버전/OS) + 운영 메모 상한
  @GetMapping("/admin/members/{id}")
  public String detail(@PathVariable String id, Model model) {
    AdminMemberDetailResponse member = adminMemberService.getDetail(id);
    model.addAttribute("member", member);
    if (member.status() != MemberStatus.WITHDRAWN) {
      model.addAttribute("creditSummary", memberCreditSummaryOf(id));
    }
    model.addAttribute("accessInfo", accessInfoOf(id));
    model.addAttribute("adminMemoMaxLength", MemberAdminMemoService.MAX_ADMIN_MEMO_LENGTH);
    return "admin/member-detail";
  }

  /**
   * 운영 메모 저장: 길이 초과·탈퇴 회원이면 저장 없이 안내 > 저장(빈 값이면 지움) > 상세로
   * 메모 원문은 로그에 남기지 않음 (글자 수만)
   */
  @PostMapping("/admin/members/{id}/memo")
  public String saveMemo(
    @PathVariable String id,
    @RequestParam(name = "adminMemo", required = false) String adminMemo,
    Principal principal,
    RedirectAttributes redirectAttributes
  ) {
    String detailPath = "redirect:/admin/members/" + id;
    int memoLength = adminMemo == null ? 0 : adminMemo.length();
    MemberAdminMemoSaveResult result = memberAdminMemoService.saveAdminMemo(id, adminMemo, actorOf(principal));
    switch (result) {
      case REJECTED_TOO_LONG -> {
        log.info("[admin members] memo rejected : memberId={}, length={} over limit",
          AdminLogIds.toLoggableId(id), memoLength);
        redirectAttributes.addFlashAttribute("errorMessage",
          "메모는 " + MemberAdminMemoService.MAX_ADMIN_MEMO_LENGTH + "자까지 저장할 수 있어요. 줄여서 다시 저장해 주세요.");
      }
      case REJECTED_WITHDRAWN -> {
        log.info("[admin members] memo rejected : memberId={}, withdrawn", AdminLogIds.toLoggableId(id));
        redirectAttributes.addFlashAttribute("errorMessage", "탈퇴한 계정에는 메모를 남길 수 없어요.");
      }
      case SAVED, CLEARED -> {
        log.info("[admin members] memo saved : memberId={}, length={}, admin={}",
          AdminLogIds.toLoggableId(id), memoLength, actorOf(principal));
        redirectAttributes.addFlashAttribute("message",
          result == MemberAdminMemoSaveResult.CLEARED ? "메모를 지웠어요." : "메모를 저장했어요.");
      }
    }
    return detailPath;
  }

  @PostMapping("/admin/members/{id}/suspend")
  public String suspend(@PathVariable String id, RedirectAttributes redirectAttributes) {
    adminMemberService.suspend(id);
    redirectAttributes.addFlashAttribute("message", "계정을 정지했습니다. 로그인과 API 사용이 차단됩니다.");
    return "redirect:/admin/members/" + id;
  }

  @PostMapping("/admin/members/{id}/unsuspend")
  public String unsuspend(@PathVariable String id, RedirectAttributes redirectAttributes) {
    adminMemberService.unsuspend(id);
    redirectAttributes.addFlashAttribute("message", "계정 정지를 해제했습니다.");
    return "redirect:/admin/members/" + id;
  }

  /**
   * Pro 발급. 사유를 반드시 받는다 — 나중에 "이 계정은 왜 Pro지"에 답해야 한다.
   *
   * <p>기간을 비우면 무기한이다. 심사 전이라 인앱결제를 붙일 수 없어, 지금은 이 화면이
   * Pro를 켜는 유일한 방법이다. 변경자는 로그인한 관리자 이름이 요금제 이력에 남는다.
   */
  @PostMapping("/admin/members/{id}/grant-pro")
  public String grantPro(
    @PathVariable String id,
    @RequestParam(name = "days", required = false) Integer days,
    @RequestParam(name = "reason") String reason,
    Principal principal,
    RedirectAttributes redirectAttributes
  ) {
    // 사유가 비었을 때만 상세 화면에 머물러 다시 넣게 한다. 입력 실수라 오류 화면으로 보내면 번거롭다.
    // 나머지(탈퇴 계정·없는 회원)는 잡지 않는다 — 전부 "사유를 입력해주세요"로 바꾸면 상세를 열어 둔
    // 사이 탈퇴한 계정에도 그 안내가 떠 원인이 가려지고 로그에도 남지 않는다.
    // 올려 보내면 AdminViewExceptionHandler 가 정지·강제 로그아웃과 같은 409 안내를 내고 로그에 남긴다.
    try {
      adminMemberService.grantPro(id, days, reason, actorOf(principal));
    } catch (CustomException e) {
      if (e.getErrorCode() != ErrorCode.INVALID_INPUT_VALUE) {
        throw e;
      }
      redirectAttributes.addFlashAttribute("errorMessage",
        "Pro 발급 실패: 사유를 입력해주세요. (E-ADM-001)");
      return "redirect:/admin/members/" + id;
    }
    redirectAttributes.addFlashAttribute("message",
      days == null || days <= 0 ? "Pro를 무기한으로 발급했습니다." : "Pro를 " + days + "일간 발급했습니다.");
    return "redirect:/admin/members/" + id;
  }

  /// Pro 회수. 사유를 비우면 기본 문구("관리자 회수")로 이력에 남는다
  @PostMapping("/admin/members/{id}/revoke-pro")
  public String revokePro(
    @PathVariable String id,
    @RequestParam(name = "reason", required = false) String reason,
    Principal principal,
    RedirectAttributes redirectAttributes
  ) {
    adminMemberService.revokePro(id, reason, actorOf(principal));
    redirectAttributes.addFlashAttribute("message", "Pro를 회수했습니다. 이 계정은 Free로 돌아갑니다.");
    return "redirect:/admin/members/" + id;
  }

  /**
   * 탈퇴 계정을 보관 기간을 기다리지 않고 바로 완전히 지운다.
   *
   * <p>지운 뒤에는 상세 화면이 없으므로 탈퇴 목록으로 돌아간다.
   */
  @PostMapping("/admin/members/{id}/purge")
  public String purge(@PathVariable String id, Principal principal, RedirectAttributes redirectAttributes) {
    adminMemberService.purgeNow(id, principal == null ? null : principal.getName());
    redirectAttributes.addFlashAttribute("message",
      "탈퇴 계정을 완전히 지웠어요. 남아 있던 계정 식별값을 지우고 AI 이용 기록에서 회원을 뗐어요.");
    return "redirect:/admin/members?status=WITHDRAWN";
  }

  @PostMapping("/admin/members/{id}/force-logout")
  public String forceLogout(@PathVariable String id, RedirectAttributes redirectAttributes) {
    adminMemberService.forceLogout(id);
    redirectAttributes.addFlashAttribute("message", "강제 로그아웃했습니다. 기존 토큰이 모두 무효화됩니다.");
    return "redirect:/admin/members/" + id;
  }

  /**
   * 이룸이 기기 연결 해제: 앱의 끊기와 같은 경로 (그 기기 세션만 폐기, 보호자 세션 유지)
   * 이미 끊겼거나 이 회원의 이룸이가 아닌 연결은 상세 화면에 머물러 오류 안내
   */
  @PostMapping("/admin/members/{id}/device-links/{linkId}/unlink")
  public String unlinkDevice(
    @PathVariable String id,
    @PathVariable String linkId,
    Principal principal,
    RedirectAttributes redirectAttributes
  ) {
    // 끊긴 연결만 화면에서 안내 (상세를 열어 둔 사이 보호자가 끊은 경우). 그 밖의 예외는 공통 오류 화면으로
    try {
      adminMemberService.unlinkDevice(id, linkId, actorOf(principal));
    } catch (CustomException e) {
      if (e.getErrorCode() != ErrorCode.DEVICE_LINK_NOT_CONNECTED) {
        throw e;
      }
      // linkId 는 주소에서 온 값이라 UUID 문자(16진수, -) 밖은 ? 로 바꿔 남김
      log.info("[admin device unlink] rejected 404 : not connected, linkId={}", AdminLogIds.toLoggableId(linkId));
      redirectAttributes.addFlashAttribute("errorMessage",
        "연결 해제 실패: 이미 끊겼거나 이 회원의 이룸이 기기가 아니에요. 화면을 새로 고쳐 확인해주세요. (E-ADM-LINK-001)");
      return "redirect:/admin/members/" + id;
    }
    redirectAttributes.addFlashAttribute("message",
      "이룸이 기기 연결을 끊었어요. 그 기기는 다시 연결 암호를 넣어야 일과를 볼 수 있어요.");
    return "redirect:/admin/members/" + id;
  }

  /// 페이지 회원 > 이번 주 남은 크레딧 (실패하면 빈 맵: 목록은 그대로, 크레딧 칸만 "-")
  private Map<String, Long> currentWeekRemainingCreditOf(List<AdminMemberResponse> members) {
    try {
      return adminCreditQueryService.currentWeekRemainingByMemberId(
        members.stream().map(AdminMemberResponse::id).toList());
    } catch (RuntimeException e) {
      log.warn("[admin members] credit summary failed : members={}", members.size(), e);
      return Map.of();
    }
  }

  /// 회원 상세 접속 정보 (실패하면 그 영역에 오류 코드만, 상세는 그대로)
  private AdminMemberAccessInfo accessInfoOf(String memberId) {
    try {
      return adminMemberAccessService.getAccessInfo(memberId);
    } catch (RuntimeException e) {
      log.warn("[admin members] access info failed : memberId={}", AdminLogIds.toLoggableId(memberId), e);
      return AdminMemberAccessInfo.failed();
    }
  }

  /// 회원 상세 크레딧 요약 (실패하면 카드에 안내만, 상세는 그대로)
  private AdminMemberCreditSummary memberCreditSummaryOf(String memberId) {
    try {
      return adminCreditQueryService.memberCreditSummary(memberId);
    } catch (RuntimeException e) {
      // memberId 는 주소에서 온 값이라 UUID 문자(16진수, -) 밖은 ? 로 바꿔 남김
      log.warn("[admin members] credit summary failed : detail, memberId={}",
        AdminLogIds.toLoggableId(memberId), e);
      return AdminMemberCreditSummary.loadFailed();
    }
  }

  // 세션 로그인 이름. 없으면 null 로 넘겨 서비스가 unknown 으로 남긴다
  private String actorOf(Principal principal) {
    return principal == null ? null : principal.getName();
  }
}
