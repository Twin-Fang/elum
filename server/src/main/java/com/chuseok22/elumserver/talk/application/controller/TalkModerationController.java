package com.chuseok22.elumserver.talk.application.controller;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.talk.application.dto.request.TalkBlockRequest;
import com.chuseok22.elumserver.talk.application.dto.request.TalkReportRequest;
import com.chuseok22.elumserver.talk.application.dto.response.TalkBlockResponse;
import com.chuseok22.elumserver.talk.application.service.TalkModerationService;
import com.chuseok22.logging.annotation.LogMonitoring;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/// 이야기 신고·차단. 보호자 권한은 SecurityConfig 의 /api/** 기본 규칙(GUARDIAN)이 건다.
@RequestMapping("/api/talk")
@RestController
@RequiredArgsConstructor
public class TalkModerationController implements TalkModerationControllerDocs {

  private final TalkModerationService talkModerationService;

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/reports")
  public ResponseEntity<Void> report(Authentication authentication, @RequestBody TalkReportRequest request) {
    talkModerationService.report(Caller.from(authentication), request);
    return ResponseEntity.noContent().build();
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PutMapping("/blocks")
  public ResponseEntity<Void> block(Authentication authentication, @RequestBody TalkBlockRequest request) {
    talkModerationService.block(Caller.from(authentication), request);
    return ResponseEntity.noContent().build();
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @DeleteMapping("/blocks/{blockId}")
  public ResponseEntity<Void> unblock(Authentication authentication, @PathVariable String blockId) {
    talkModerationService.unblock(Caller.from(authentication), blockId);
    return ResponseEntity.noContent().build();
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping("/blocks")
  public ResponseEntity<List<TalkBlockResponse>> getBlocks(Authentication authentication) {
    return ResponseEntity.ok(talkModerationService.blocks(Caller.from(authentication)));
  }
}
