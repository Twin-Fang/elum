package com.chuseok22.elumserver.feedback.application.controller;

import com.chuseok22.elumserver.feedback.application.dto.request.FeedbackRequest;
import com.chuseok22.elumserver.feedback.application.dto.response.FeedbackResponse;
import com.chuseok22.elumserver.feedback.application.service.FeedbackService;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.logging.annotation.LogMonitoring;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/// 보호자가 앱에서 의견을 보낸다. 보호자 권한은 SecurityConfig 의 /api/** 기본 규칙(GUARDIAN)이 건다.
@RequestMapping("/api/feedback")
@RestController
@RequiredArgsConstructor
public class FeedbackController implements FeedbackControllerDocs {

  private final FeedbackService feedbackService;

  // 의견 원문과 앱 상태 기록이 서버 로그에 남으면 안 되므로 파라미터·결과를 남기지 않는다.
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping
  public ResponseEntity<FeedbackResponse> submit(Authentication authentication, @RequestBody FeedbackRequest request) {
    return ResponseEntity.ok(new FeedbackResponse(
      feedbackService.submit(Caller.from(authentication).memberId(), request)));
  }
}
