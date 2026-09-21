package com.chuseok22.elumserver.consent.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

/**
 * 앱이 동의 화면을 그릴 때 받는 것 (이슈 #278).
 */
@Schema(description = "약관 전체")
public record ConsentDocumentsResponse(

  @Schema(description = """
    동의를 기록할 때 되돌려 보낼 버전. **필수 항목 중 가장 최근 버전**이다.
    선택 항목이 바뀌었다고 재동의를 요구하지 않기 위해 선택 항목은 세지 않는다.
    """, example = "2026-09-18")
  String version,

  @Schema(description = "동의 항목 목록. 배열 순서가 화면에 보여줄 순서다")
  List<ConsentDocumentResponse> documents
) {}
