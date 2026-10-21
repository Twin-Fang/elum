package com.chuseok22.elumserver.talk.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDateTime;
import java.util.List;

@Schema(description = "이야기 글 요약(피드·인기 카드 1장). 글쓴이의 회원 id·이메일은 담지 않는다")
public record TalkPostSummaryResponse(
  @Schema(description = "글 id")
  String id,
  @Schema(description = "글쓴이 닉네임. 닉네임이 없는 계정은 null")
  String authorNickname,
  @Schema(description = "내가 올린 글인가")
  boolean isMine,
  @Schema(description = "글 제목(이룸이 이름을 가린 뒤)")
  String title,
  @Schema(description = "분류 6개: SELF_CARE, DAILY_FLOW, HOUSEHOLD, COMMUNITY, LEARNING, FEELINGS")
  String category,
  @Schema(description = "카드 수")
  int stepCount,
  @Schema(description = "앞 4장 카드의 그림 정보")
  List<StepThumb> previewSteps,
  @Schema(description = "글쓴이의 한마디. 없으면 null")
  String note,
  @Schema(description = "도움이 됐어요 수")
  int helpfulCount,
  @Schema(description = "댓글 수")
  int commentCount,
  @Schema(description = "가져간 수")
  int importCount,
  @Schema(description = "올린 시각")
  LocalDateTime createdAt
) {

  @Schema(description = "카드 1장의 그림 정보. 올린 그림(hasImage) > 예시 이미지 > 픽토그램 순으로 그린다")
  public record StepThumb(
    @Schema(description = "카드 순서(0부터)")
    int stepOrder,
    @Schema(description = "글 전용 그림이 있는가. true 면 /api/talk/posts/{id}/steps/{stepOrder}/image 로 받는다")
    boolean hasImage,
    @Schema(description = "픽토그램 id. 없으면 null")
    String pictogramId,
    @Schema(description = "예시 이미지 id. 없으면 null")
    String exampleImageId,
    @Schema(description = "그림을 흐리게 보여줄 것인가")
    boolean isBlurred
  ) {

  }
}
