package com.chuseok22.elumserver.notice.application.controller;

import com.chuseok22.elumserver.notice.application.dto.response.AppNoticesResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;

@Tag(
  name = "App Notice",
  description = "보호자 홈 공지 팝업. 관리자가 올린 공지 중 지금 게시 중인 것을 준다 (이슈 #370)."
)
public interface NoticeControllerDocs {

  @Operation(
    summary = "게시 중인 공지 목록",
    description = """
      보호자 홈에 앱 실행 후 처음 들어올 때 한 번 부릅니다. **인증이 없습니다.**

      - 켜져 있고, 게시 기간 안이고(서버 시계·한국 시각), 이 플랫폼에 닿는 공지를
        우선순위 큰 순 → 시작이 늦은 순으로 **최대 5개** 줍니다.
      - 숨김은 기기에 있으므로 서버는 거르지 않습니다. 앱이 숨긴 것(같은 `revision` 이고 기한이
        안 지난 것)을 빼고 남은 것을 한 팝업에 슬라이드로 보여줍니다.
      - `hideDays` 는 "보지 않기"를 체크하고 닫았을 때 숨길 일수입니다. 7 이면 "일주일간 보지 않기".
      - `title` 의 `**…**` 는 강조 표기입니다. 서버는 짝을 검사해 저장하므로 짝이 맞게 옵니다.
      - **실패하면 팝업 없이 지나갑니다.** 공지는 부가 기능이라 앱을 막지 않습니다.
      - 점검 중에는 다른 API 처럼 503 입니다. 앱은 점검 화면만 띄우므로 공지는 뜨지 않습니다.
      - 60초 캐시됩니다(`Cache-Control: max-age=60`).
      """
  )
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "조회 완료",
      content = @Content(schema = @Schema(implementation = AppNoticesResponse.class),
        examples = @ExampleObject(value = """
          {
            "hideDays": 7,
            "notices": [
              {
                "id": "3f1c2a9e-5b7d-4c1e-9a2b-6d8e0f1a2b3c",
                "revision": 2,
                "title": "베타 기간에는 **하루 3개**까지 만들 수 있어요",
                "body": "더 많이 만들 수 있게 준비하고 있어요.\\n조금만 기다려 주세요.",
                "imageUrl": "/api/app/notices/3f1c2a9e-5b7d-4c1e-9a2b-6d8e0f1a2b3c/image?v=9a8b7c6d",
                "button": { "label": "자세히 보기", "url": "https://twin-fang.github.io/elum/" }
              },
              {
                "id": "7d0e1f2a-3b4c-5d6e-7f8a-9b0c1d2e3f4a",
                "revision": 1,
                "title": "추석 연휴에도 이룸은 쉬지 않아요",
                "body": "연휴에도 평소처럼 일과를 만들 수 있어요.",
                "imageUrl": null,
                "button": null
              }
            ]
          }
          """))),
    @ApiResponse(responseCode = "400", description = "모르는 플랫폼 값 (`NOTICE_PLATFORM_INVALID`)")
  })
  ResponseEntity<AppNoticesResponse> notices(
    @Parameter(description = "IOS 또는 ANDROID. 비우면 전체 대상 공지만 준다", example = "IOS")
    String platform
  );

  @Operation(
    summary = "공지 이미지",
    description = """
      목록의 `imageUrl` 이 가리키는 이미지입니다. **인증이 없습니다.**
      게시 중이 아니면 404(`NOTICE_IMAGE_NOT_FOUND`)입니다. 권장 비율은 16:10 입니다.
      이미지를 받지 못하면 앱은 그림 자리 없이 글만 보여줍니다.
      """
  )
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "png, jpeg, webp 중 하나"),
    @ApiResponse(responseCode = "404", description = "없거나 게시 중이 아님 (`NOTICE_IMAGE_NOT_FOUND`)")
  })
  ResponseEntity<byte[]> image(@Parameter(description = "공지 ID") String id);
}
