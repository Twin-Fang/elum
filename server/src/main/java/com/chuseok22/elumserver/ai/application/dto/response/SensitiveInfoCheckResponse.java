package com.chuseok22.elumserver.ai.application.dto.response;

import com.chuseok22.elumserver.ai.core.SensitiveInfoCheckResult;
import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(description = "민감정보 사전 검토 응답")
public record SensitiveInfoCheckResponse(

  @Schema(description = "로컬 LLM 검증이 실제로 수행됐는지 여부. false면 비활성화/장애로 통과 처리된 것.", example = "true")
  boolean checked,

  @Schema(description = "민감정보 포함 여부", example = "true")
  boolean hasSensitiveInfo,

  @Schema(description = "탐지된 민감정보 카테고리 목록", example = "[\"이름\", \"전화번호\"]")
  List<String> categories,

  @Schema(description = "판정 사유", example = "이름과 전화번호가 포함되어 있습니다.")
  String reason,

  @Schema(description = "민감정보를 카테고리 태그로 치환한 텍스트(검증 실패 시 원문 그대로)", example = "<이름>한테 <전화번호>로 연락주세요")
  String sanitizedText
) {

  public static SensitiveInfoCheckResponse from(SensitiveInfoCheckResult result) {
    return new SensitiveInfoCheckResponse(
      result.checked(), result.hasSensitiveInfo(), result.categories(), result.reason(), result.sanitizedText()
    );
  }
}
