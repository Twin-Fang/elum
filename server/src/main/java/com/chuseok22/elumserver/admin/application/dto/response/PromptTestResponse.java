package com.chuseok22.elumserver.admin.application.dto.response;

// result: LOCAL_LLM/텍스트 생성 테스트 결과(구조화 객체), imageDataUri: 이미지 테스트 결과.
// PromptKey별로 둘 중 하나만 채워진다.
public record PromptTestResponse(
  Object result,
  String imageDataUri
) {

}
