package com.chuseok22.elumserver.admin.application.dto.request;

import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;

// content/sampleInput 모두 검증 없이 그대로 전달한다 — 빈 값이어도 AI 호출 자체는
// 가능하고(결과가 유의미하지 않을 뿐), 관리자 전용 테스트 도구이므로 최소한으로 둔다.
// character는 GEMINI_ROUTINE_IMAGE_PREFIX 테스트에서만 쓰이고 다른 키에서는 무시된다.
public record PromptSampleRequest(
  String content,
  String sampleInput,
  CharacterType character
) {

}
