package com.chuseok22.elumserver.notice.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.notice.application.dto.response.AppNoticeResponse;
import com.chuseok22.elumserver.notice.application.dto.response.AppNoticesResponse;
import com.chuseok22.elumserver.notice.application.service.NoticeService;
import com.chuseok22.elumserver.notice.infrastructure.storage.NoticeImageStorage.ImageContent;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;

/**
 * 공개 공지 API 의 응답 머리 (이슈 #370, N22).
 *
 * <p>인증 없이 열린 경로라 누가 마구 불러도 가볍게 버텨야 한다. 응답이 작고 60초 캐시된다.
 */
class NoticeControllerTest {

  private final NoticeService noticeService = mock(NoticeService.class);
  private final NoticeController controller = new NoticeController(noticeService);

  @Test
  @DisplayName("목록은 서비스가 준 그대로이고 60초 캐시된다")
  void notices_cacheable() {
    AppNoticesResponse body = new AppNoticesResponse(7, List.of(
      new AppNoticeResponse("n1", 1, "**하루 3개**까지", "본문", null, null)));
    when(noticeService.publishedFor("IOS")).thenReturn(body);

    ResponseEntity<AppNoticesResponse> response = controller.notices("IOS");

    assertThat(response.getStatusCode().value()).isEqualTo(200);
    assertThat(response.getBody()).isEqualTo(body);
    assertThat(response.getHeaders().getFirst(HttpHeaders.CACHE_CONTROL)).isEqualTo("max-age=60");
  }

  @Test
  @DisplayName("이미지는 저장한 형식으로 내보내고, 60초 캐시하며, 형식 추측을 막는다")
  void image_headers() {
    when(noticeService.liveImage("n1")).thenReturn(new ImageContent(new byte[]{1, 2}, "image/webp"));

    ResponseEntity<byte[]> response = controller.image("n1");

    assertThat(response.getBody()).containsExactly(1, 2);
    assertThat(response.getHeaders().getContentType()).isEqualTo(MediaType.parseMediaType("image/webp"));
    assertThat(response.getHeaders().getFirst(HttpHeaders.CACHE_CONTROL)).isEqualTo("max-age=60");
    assertThat(response.getHeaders().getFirst("X-Content-Type-Options")).isEqualTo("nosniff");
  }
}
