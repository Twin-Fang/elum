package com.chuseok22.elumserver.talk.application.controller;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.talk.application.dto.request.TalkLinkCreateRequest;
import com.chuseok22.elumserver.talk.application.dto.response.TalkLinkResponse;
import com.chuseok22.elumserver.talk.application.service.TalkLinkService;
import com.chuseok22.logging.annotation.LogMonitoring;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/// 일과를 링크로 보내기 (#1002). 끄기는 글 내리기(DELETE /api/talk/posts/{id}). 보호자 권한은 /api/** 기본 규칙(GUARDIAN)
@RequestMapping("/api/talk/links")
@RestController
@RequiredArgsConstructor
public class TalkLinkController implements TalkLinkControllerDocs {

  private final TalkLinkService talkLinkService;

  // 일과 원문이 서버 로그에 남지 않게 파라미터·결과를 남기지 않는다
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping
  public ResponseEntity<TalkLinkResponse> create(
    Authentication authentication, @RequestBody TalkLinkCreateRequest request
  ) {
    return ResponseEntity.ok(talkLinkService.create(Caller.from(authentication), request));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping("/mine/by-source-routine")
  public ResponseEntity<Map<String, String>> getMyLinks(Authentication authentication) {
    return ResponseEntity.ok(talkLinkService.myLinks(Caller.from(authentication)));
  }
}
