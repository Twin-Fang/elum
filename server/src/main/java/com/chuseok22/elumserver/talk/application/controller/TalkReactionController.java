package com.chuseok22.elumserver.talk.application.controller;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.talk.application.dto.request.TalkCommentRequest;
import com.chuseok22.elumserver.talk.application.dto.response.TalkCommentPageResponse;
import com.chuseok22.elumserver.talk.application.dto.response.TalkCommentResponse;
import com.chuseok22.elumserver.talk.application.service.TalkReactionService;
import com.chuseok22.logging.annotation.LogMonitoring;
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
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/// 이야기 반응: 도움이 됐어요, 댓글. 보호자 권한은 SecurityConfig 의 /api/** 기본 규칙(GUARDIAN)이 건다.
@RequestMapping("/api/talk")
@RestController
@RequiredArgsConstructor
public class TalkReactionController implements TalkReactionControllerDocs {

  private final TalkReactionService talkReactionService;

  // 댓글 원문이 서버 로그에 남으면 안 되므로 파라미터·결과를 남기지 않는다.
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PutMapping("/posts/{postId}/helpful")
  public ResponseEntity<Void> markHelpful(Authentication authentication, @PathVariable String postId) {
    talkReactionService.markHelpful(Caller.from(authentication), postId);
    return ResponseEntity.noContent().build();
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @DeleteMapping("/posts/{postId}/helpful")
  public ResponseEntity<Void> unmarkHelpful(Authentication authentication, @PathVariable String postId) {
    talkReactionService.unmarkHelpful(Caller.from(authentication), postId);
    return ResponseEntity.noContent().build();
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping("/posts/{postId}/comments")
  public ResponseEntity<TalkCommentPageResponse> getComments(
    Authentication authentication,
    @PathVariable String postId,
    @RequestParam(required = false) String cursor,
    @RequestParam(required = false) Integer size
  ) {
    return ResponseEntity.ok(talkReactionService.comments(Caller.from(authentication), postId, cursor, size));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/posts/{postId}/comments")
  public ResponseEntity<TalkCommentResponse> addComment(
    Authentication authentication, @PathVariable String postId, @RequestBody TalkCommentRequest request
  ) {
    return ResponseEntity.ok(talkReactionService.addComment(Caller.from(authentication), postId, request));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @DeleteMapping("/comments/{commentId}")
  public ResponseEntity<Void> deleteComment(Authentication authentication, @PathVariable String commentId) {
    talkReactionService.deleteComment(Caller.from(authentication), commentId);
    return ResponseEntity.noContent().build();
  }
}
