package com.chuseok22.elumserver.notice.application.dto.response;

import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "공지 팝업의 슬라이드 한 장")
public record AppNoticeResponse(

  @Schema(description = "공지 ID. 앱이 숨김 기록의 열쇠로 쓴다")
  String id,

  @Schema(description = "판. 관리자가 \"다시 보이게\"로 저장하면 오른다. 숨길 때 적어 둔 값과 다르면 다시 보여준다",
    example = "1")
  int revision,

  @Schema(description = "제목. `**…**` 는 강조(브랜드 색)다. 짝이 안 맞으면 강조 없이 표기만 지운다",
    example = "베타 기간에는 **하루 3개**까지 만들 수 있어요")
  String title,

  @Schema(description = "본문. 줄바꿈(LF)을 유지한다", example = "더 많이 만들 수 있게 준비하고 있어요.")
  String body,

  @Schema(description = "이미지 주소(서버 기준 경로). 권장 16:10. 없으면 null",
    example = "/api/app/notices/3f1c.../image?v=9a8b7c")
  String imageUrl,

  @Schema(description = "선택 버튼. 없으면 null")
  Button button
) {

  @Schema(description = "공지 버튼. 누르면 외부 브라우저로 링크를 연다")
  public record Button(
    @Schema(description = "버튼 문구", example = "자세히 보기")
    String label,
    @Schema(description = "https 링크", example = "https://twin-fang.github.io/elum/")
    String url
  ) {

  }

  public static AppNoticeResponse from(AppNotice notice) {
    return new AppNoticeResponse(
      notice.getId(),
      notice.getRevision(),
      notice.getTitle(),
      notice.getBody(),
      imageUrlOf(notice),
      notice.hasButton() ? new Button(notice.getButtonLabel(), notice.getButtonUrl()) : null
    );
  }

  /**
   * 열쇠의 파일 이름을 {@code v} 로 붙인다. 그림을 바꾸면 열쇠가 바뀌므로 주소도 바뀐다 —
   * 같은 주소에 다른 그림을 두면 앱 이미지 캐시가 옛 그림을 계속 보여준다.
   */
  private static String imageUrlOf(AppNotice notice) {
    String key = notice.getImageKey();
    if (key == null || key.isBlank()) {
      return null;
    }
    String fileName = key.substring(key.lastIndexOf('/') + 1);
    int dot = fileName.lastIndexOf('.');
    String version = dot < 0 ? fileName : fileName.substring(0, dot);
    return "/api/app/notices/" + notice.getId() + "/image?v=" + version;
  }
}
