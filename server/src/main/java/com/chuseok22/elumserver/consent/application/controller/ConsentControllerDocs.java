package com.chuseok22.elumserver.consent.application.controller;

import com.chuseok22.elumserver.consent.application.dto.response.ConsentDocumentsResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;

@Tag(
  name = "Consent",
  description = "약관·개인정보처리방침 전문을 내려주는 API. 가입 전에 읽으므로 인증이 없습니다."
)
public interface ConsentControllerDocs {

  @Operation(
    summary = "약관 전문 조회",
    description = """
      동의 항목과 전문을 모두 돌려줍니다.

      **인증이 없습니다.** 가입하기 전에 읽는 문서라 로그인을 요구할 수 없습니다.

      **앱이 하는 일**

      - 받은 내용을 **캐시에 저장**하고, 평소에는 캐시를 읽어 화면을 그립니다
      - **이 요청이 실패해도 화면은 그대로 뜹니다** — 캐시가 없으면 앱에 담긴
        기본값을 보여줍니다. 네트워크가 없다고 가입이 막히면 안 됩니다
      - 동의를 보낼 때는 **실제로 화면에 보여준 버전**을 함께 보냅니다.
        캐시가 낡아 옛 문구를 보여줬다면 옛 버전으로 기록해야 합니다 —
        사용자가 보지 않은 문서에 동의한 것으로 남기면 안 됩니다

      `version` 은 **필수 항목 중 가장 최근 버전**입니다. 선택 항목(소식 받기)이
      바뀌었다고 전원에게 재동의를 요구하지 않기 위해 선택 항목은 세지 않습니다.
      """
  )
  @ApiResponses(@ApiResponse(
    responseCode = "200", description = "조회 완료",
    content = @Content(schema = @Schema(implementation = ConsentDocumentsResponse.class),
      examples = @ExampleObject(value = """
        {
          "version": "2026-09-18",
          "documents": [
            {
              "key": "termsAgreed",
              "label": "서비스 이용약관",
              "required": true,
              "summary": "이룸을 어떻게 쓰고, 무엇을 보장하는지",
              "body": "제1조 (목적)\\n이 약관은 ...",
              "version": "2026-09-18"
            }
          ]
        }
        """))
  ))
  ResponseEntity<ConsentDocumentsResponse> documents();
}
