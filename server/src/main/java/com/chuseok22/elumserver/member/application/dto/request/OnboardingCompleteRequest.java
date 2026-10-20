package com.chuseok22.elumserver.member.application.dto.request;

import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.ImageStyle;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;
import java.util.Set;

// request DTO 에는 검증 어노테이션을 달지 않는 저장소 규칙(server/CLAUDE.md)이라 검사는 서비스가 한다.
@Schema(description = "온보딩 완료 요청: 이룸이 정보와 예시 일과 분류를 한 번에 저장")
public record OnboardingCompleteRequest(

  @Schema(description = "이룸이 호칭. 필수", example = "하늘이")
  String nickname,

  @Schema(description = "도움 목표 (비어 있어도 된다)")
  Set<SupportGoal> supportGoals,

  @Schema(description = "캐릭터. 없으면 바꾸지 않는다", example = "LULU")
  CharacterType character,

  @Schema(description = "카드 그림 방식. 없으면 바꾸지 않는다", example = "CARTOON")
  ImageStyle imageStyle,

  @Schema(description = "예시 일과 분류 코드 (MORNING_EVENING · SCHOOL_STUDY · HOUSE_SELF · OUTSIDE). 비어 있으면 만들지 않는다",
    example = "[\"SCHOOL_STUDY\", \"HOUSE_SELF\"]")
  List<String> exampleCategories
) {

}
