package com.chuseok22.elumserver.notice.application.dto.response;

import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDateTime;

@Schema(description = "공지 탭의 공지 한 건")
public record NoticeHistoryItemResponse(

  @Schema(description = "공지 ID")
  String id,

  @Schema(description = "제목. `**…**` 는 강조 표기", example = "베타 기간에는 **하루 3개**까지 만들 수 있어요")
  String title,

  @Schema(description = "본문. 줄바꿈(LF)을 유지한다")
  String body,

  @Schema(description = "이미지 주소(서버 기준 경로). 없으면 null", example = "/api/app/notices/3f1c.../image?v=9a8b7c")
  String imageUrl,

  @Schema(description = "버튼 문구. 버튼이 없으면 null", example = "자세히 보기")
  String buttonLabel,

  @Schema(description = "버튼 https 링크. 버튼이 없으면 null", example = "https://twin-fang.github.io/elum/")
  String buttonUrl,

  @Schema(description = "공지가 올라온 시각(한국 시각). 다시 보이게 고친 공지는 고친 시각", example = "2026-10-19T09:00:00")
  LocalDateTime visibleSince
) {

  public static NoticeHistoryItemResponse from(AppNotice notice) {
    return new NoticeHistoryItemResponse(
      notice.getId(),
      notice.getTitle(),
      notice.getBody(),
      AppNoticeResponse.imageUrlOf(notice),
      notice.getButtonLabel(),
      notice.getButtonUrl(),
      notice.visibleSince()
    );
  }
}
