package com.chuseok22.elumserver.notice.application.controller;

import com.chuseok22.elumserver.notice.application.dto.response.AppNoticesResponse;
import com.chuseok22.elumserver.notice.application.service.NoticeService;
import com.chuseok22.elumserver.notice.infrastructure.storage.NoticeImageStorage.ImageContent;
import com.chuseok22.logging.annotation.LogMonitoring;
import java.time.Duration;
import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 보호자 홈 공지 팝업 (이슈 #370). 인증 없이 연다 — {@code SecurityConfig} 참고.
 *
 * <p>쓰기 경로가 없고 응답이 작다. 60초 캐시를 붙여 누가 마구 불러도 가볍게 한다(N22).
 * 관리자가 끄거나 지운 공지는 길어도 60초 안에 빠진다.
 */
@RestController
@RequiredArgsConstructor
public class NoticeController implements NoticeControllerDocs {

  private static final CacheControl CACHE = CacheControl.maxAge(Duration.ofSeconds(60));

  private final NoticeService noticeService;

  @Override
  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @GetMapping("/api/app/notices")
  public ResponseEntity<AppNoticesResponse> notices(
    @RequestParam(value = "platform", required = false) String platform
  ) {
    return ResponseEntity.ok().cacheControl(CACHE).body(noticeService.publishedFor(platform));
  }

  @Override
  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @GetMapping("/api/app/notices/{id}/image")
  public ResponseEntity<byte[]> image(@PathVariable("id") String id) {
    ImageContent content = noticeService.liveImage(id);
    return ResponseEntity.ok()
      .cacheControl(CACHE)
      .contentType(MediaType.parseMediaType(content.contentType()))
      // 형식은 저장할 때 서명으로 정했다. 브라우저가 내용을 보고 다른 형식으로 추측하지 못하게 한다.
      .header("X-Content-Type-Options", "nosniff")
      .body(content.bytes());
  }
}
