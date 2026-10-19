package com.chuseok22.elumserver.notice.application.controller;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.notice.application.dto.response.NoticeHistoryPageResponse;
import com.chuseok22.elumserver.notice.application.service.NoticeHistoryService;
import com.chuseok22.logging.annotation.LogMonitoring;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/// 공지 탭 목록과 읽음 기록. 공개 /api/app/notices 와 경로가 달라 SecurityConfig 기본 규칙(GUARDIAN)이 건다.
@RequestMapping("/api/notices")
@RestController
@RequiredArgsConstructor
public class NoticeHistoryController implements NoticeHistoryControllerDocs {

  private final NoticeHistoryService noticeHistoryService;

  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @GetMapping("/history")
  public ResponseEntity<NoticeHistoryPageResponse> history(
    @RequestParam(value = "platform", required = false) String platform,
    @RequestParam(value = "cursor", required = false) String cursor,
    @RequestParam(value = "size", required = false) Integer size
  ) {
    return ResponseEntity.ok(noticeHistoryService.history(platform, cursor, size));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/seen")
  public ResponseEntity<Void> markSeen(Authentication authentication) {
    noticeHistoryService.markSeen(Caller.from(authentication).memberId());
    return ResponseEntity.noContent().build();
  }
}
