package com.chuseok22.elumserver.talk.application.controller;

import com.chuseok22.elumserver.common.locale.CurrentLocale;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage.ImageContent;
import com.chuseok22.elumserver.talk.application.dto.request.TalkImportRequest;
import com.chuseok22.elumserver.talk.application.dto.request.TalkPostCreateRequest;
import com.chuseok22.elumserver.talk.application.dto.request.TalkPostUpdateRequest;
import com.chuseok22.elumserver.talk.application.dto.request.TalkPreviewRequest;
import com.chuseok22.elumserver.talk.application.dto.response.TalkFeedPageResponse;
import com.chuseok22.elumserver.talk.application.dto.response.TalkImportResponse;
import com.chuseok22.elumserver.talk.application.dto.response.TalkPostCreatedResponse;
import com.chuseok22.elumserver.talk.application.dto.response.TalkPostDetailResponse;
import com.chuseok22.elumserver.talk.application.dto.response.TalkPostSummaryResponse;
import com.chuseok22.elumserver.talk.application.dto.response.TalkPreviewResponse;
import com.chuseok22.elumserver.talk.application.service.TalkFeedQueryService;
import com.chuseok22.elumserver.talk.application.service.TalkImportService;
import com.chuseok22.elumserver.talk.application.service.TalkPostService;
import com.chuseok22.logging.annotation.LogMonitoring;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/// 이야기: 보호자끼리 일과를 나누는 글. 보호자 권한은 SecurityConfig 의 /api/** 기본 규칙(GUARDIAN)이 건다.
@RequestMapping("/api/talk")
@RestController
@RequiredArgsConstructor
public class TalkController implements TalkControllerDocs {

  // 글 전용 그림은 글이 지워지기 전엔 바뀌지 않음 (하루, 공유 캐시 없음)
  private static final String IMAGE_CACHE_CONTROL = "private, max-age=86400";

  private final TalkFeedQueryService talkFeedQueryService;
  private final TalkPostService talkPostService;
  private final TalkImportService talkImportService;

  // 글 원문이 서버 로그에 남으면 안 되므로 파라미터·결과를 남기지 않는다.
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping("/posts")
  public ResponseEntity<TalkFeedPageResponse> getFeed(
    Authentication authentication,
    @RequestParam(required = false) String category,
    @RequestParam(required = false) String cursor,
    @RequestParam(required = false) Integer size
  ) {
    return ResponseEntity.ok(talkFeedQueryService.feed(
      Caller.from(authentication), category, cursor, size, CurrentLocale.get()));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping("/posts/popular")
  public ResponseEntity<List<TalkPostSummaryResponse>> getPopular(
    Authentication authentication, @RequestParam(required = false) String category
  ) {
    return ResponseEntity.ok(talkFeedQueryService.popular(
      Caller.from(authentication), category, CurrentLocale.get()));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping("/posts/mine")
  public ResponseEntity<TalkFeedPageResponse> getMyPosts(
    Authentication authentication,
    @RequestParam(required = false) String cursor,
    @RequestParam(required = false) Integer size
  ) {
    return ResponseEntity.ok(talkFeedQueryService.myPosts(Caller.from(authentication), cursor, size));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping("/posts/mine/by-source-routine")
  public ResponseEntity<Map<String, String>> getMySharedPosts(Authentication authentication) {
    return ResponseEntity.ok(talkFeedQueryService.mySharedPosts(Caller.from(authentication)));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping("/posts/{postId}")
  public ResponseEntity<TalkPostDetailResponse> getDetail(Authentication authentication, @PathVariable String postId) {
    return ResponseEntity.ok(talkFeedQueryService.detail(Caller.from(authentication), postId));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping("/posts/{postId}/steps/{stepOrder}/image")
  public ResponseEntity<byte[]> getStepImage(
    Authentication authentication, @PathVariable String postId, @PathVariable int stepOrder
  ) {
    ImageContent content = talkFeedQueryService.stepImage(Caller.from(authentication), postId, stepOrder);
    return ResponseEntity.ok()
      .header(HttpHeaders.CACHE_CONTROL, IMAGE_CACHE_CONTROL)
      .contentType(MediaType.parseMediaType(content.contentType()))
      .body(content.bytes());
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/posts/preview")
  public ResponseEntity<TalkPreviewResponse> preview(
    Authentication authentication, @RequestBody TalkPreviewRequest request
  ) {
    return ResponseEntity.ok(talkPostService.preview(Caller.from(authentication), request));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/posts")
  public ResponseEntity<TalkPostCreatedResponse> create(
    Authentication authentication, @RequestBody TalkPostCreateRequest request
  ) {
    return ResponseEntity.ok(talkPostService.create(Caller.from(authentication), request));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PatchMapping("/posts/{postId}")
  public ResponseEntity<TalkPostDetailResponse> update(
    Authentication authentication, @PathVariable String postId, @RequestBody TalkPostUpdateRequest request
  ) {
    return ResponseEntity.ok(talkPostService.update(Caller.from(authentication), postId, request));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/posts/{postId}/import")
  public ResponseEntity<TalkImportResponse> importToLibrary(
    Authentication authentication, @PathVariable String postId, @RequestBody TalkImportRequest request
  ) {
    return ResponseEntity.ok(talkImportService.importToLibrary(Caller.from(authentication), postId, request));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @DeleteMapping("/posts/{postId}")
  public ResponseEntity<Void> delete(Authentication authentication, @PathVariable String postId) {
    talkPostService.delete(Caller.from(authentication), postId);
    return ResponseEntity.noContent().build();
  }
}
