package com.chuseok22.elumserver.routine.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(description = "AI 추가 질문 응답")
public record RoutineQuestionResponse(

  @Schema(description = "추가 질문이 필요한지 여부. false면 questions는 무시하고 바로 카드 생성으로 진행", example = "true")
  boolean required,

  @Schema(description = "선택한 도움 목표별 질문 목록(required=false면 빈 배열)")
  List<QuestionItem> questions
) {

  @Schema(description = "개별 질문 항목")
  public record QuestionItem(

    @Schema(description = "질문 문구", example = "하늘이가 비 오는 날 평소와 다르게 챙겨야 하는 물건이 있나요?")
    String question,

    @Schema(description = "선택지 목록. 직접 입력 항목은 포함되지 않으며, 보호자는 반드시 이 중 하나를 선택합니다")
    List<OptionItem> options
  ) {

    @Schema(description = "개별 선택지. emoji/label 쌍으로 구성됩니다")
    public record OptionItem(

      @Schema(description = "선택지를 표현하는 유니코드 이모지", example = "☔")
      String emoji,

      @Schema(description = "선택지 텍스트. POST /api/routines 호출 시 answers 배열에 그대로 담아 전달합니다", example = "우산")
      String label
    ) {

    }
  }
}
