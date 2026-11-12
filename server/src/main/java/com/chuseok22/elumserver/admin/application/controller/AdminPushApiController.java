package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.request.AdminPushRequest;
import com.chuseok22.elumserver.admin.application.dto.response.AdminPushPreviewResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminPushSendResponse;
import com.chuseok22.elumserver.admin.application.service.AdminPushService;
import com.chuseok22.elumserver.admin.core.AdminPushOutcome;
import com.chuseok22.elumserver.common.application.exception.JsonErrorResponse;
import com.chuseok22.logging.annotation.LogMonitoring;
import jakarta.servlet.http.HttpSession;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/**
 * 알림 보내기 JSON (#1273): 대상 미리 계산(늘 200), 먼저 보내 보기, 보내기(거절 400 + 사유, 보냄 200 + 기기 결과)
 * 화면 컨트롤러와 분리 (@JsonErrorResponse 는 클래스 단위)
 */
@RestController
@JsonErrorResponse
@RequiredArgsConstructor
public class AdminPushApiController {

  // 세션: 먼저 받아 볼 회원 id (관리자 로그인 동안 화면에 다시 채움)
  static final String TEST_MEMBER_SESSION_KEY = "adminPushTestMemberId";

  private final AdminPushService adminPushService;

  /// 미리 계산 (@LogMonitoring 없음: 조건을 바꿀 때마다 불려 로그만 채움)
  @PostMapping("/admin/push/api/preview")
  public AdminPushPreviewResponse preview(@RequestBody AdminPushRequest request) {
    return adminPushService.preview(request);
  }

  /// 먼저 보내 보기: 받을 회원 id 를 세션에 남김 (거절돼도 다음에 다시 채우게)
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/admin/push/api/test")
  public ResponseEntity<AdminPushSendResponse> sendTest(@RequestBody AdminPushRequest request, HttpSession session) {
    if (request.testMemberId() != null && !request.testMemberId().isBlank()) {
      session.setAttribute(TEST_MEMBER_SESSION_KEY, request.testMemberId().strip());
    }
    AdminPushSendResponse response = adminPushService.sendTest(request);
    return statusOf(AdminPushOutcome.valueOf(response.outcome())).body(response);
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/admin/push/api/send")
  public ResponseEntity<AdminPushSendResponse> send(@RequestBody AdminPushRequest request) {
    AdminPushSendResponse response = adminPushService.send(request);
    return statusOf(AdminPushOutcome.valueOf(response.outcome())).body(response);
  }

  private static ResponseEntity.BodyBuilder statusOf(AdminPushOutcome outcome) {
    return outcome.isAccepted() ? ResponseEntity.ok() : ResponseEntity.badRequest();
  }
}
