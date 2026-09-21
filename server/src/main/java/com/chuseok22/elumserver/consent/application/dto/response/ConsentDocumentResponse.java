package com.chuseok22.elumserver.consent.application.dto.response;

import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;
import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "동의 항목 한 개와 전문")
public record ConsentDocumentResponse(

  @Schema(description = "동의 여부를 보낼 때 쓰는 필드명", example = "termsAgreed")
  String key,

  @Schema(description = "화면에 보여줄 항목 이름", example = "서비스 이용약관")
  String label,

  @Schema(description = "필수 항목인가. 필수는 동의하지 않으면 서비스를 쓸 수 없다", example = "true")
  boolean required,

  @Schema(description = "목록에 보여줄 한 줄 요약", example = "이룸을 어떻게 쓰고, 무엇을 보장하는지")
  String summary,

  @Schema(description = "전문")
  String body,

  @Schema(description = "이 문서의 버전", example = "2026-09-18")
  String version
) {

  public static ConsentDocumentResponse from(ConsentDocument document) {
    return new ConsentDocumentResponse(
      document.getConsentKey().getField(),
      document.getLabel(),
      document.isRequired(),
      document.getSummary(),
      document.getBody(),
      document.getVersion()
    );
  }
}
