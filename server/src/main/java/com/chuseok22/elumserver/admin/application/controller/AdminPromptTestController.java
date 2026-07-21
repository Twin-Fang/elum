package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.request.PromptSampleRequest;
import com.chuseok22.elumserver.admin.application.dto.response.PromptPreviewResponse;
import com.chuseok22.elumserver.admin.application.dto.response.PromptTestResponse;
import com.chuseok22.elumserver.admin.application.service.AdminPromptService;
import com.chuseok22.elumserver.ai.core.PromptKey;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

// AdminPromptController(SSR)와 분리한 이유: GlobalExceptionHandler의 assignableTypes
// 스코핑은 "메서드"가 아니라 "클래스" 단위로 적용된다(fable5 검토에서 spring-web 7.0.8
// 바이트코드로 실측 확인). JSON 에러 응답이 필요한 이 두 엔드포인트만 별도 컨트롤러로
// 분리해야, 목록 조회/저장(SSR) 엔드포인트가 의도치 않게 JSON 에러를 반환하는 것을 막을 수 있다.
@RestController
@RequiredArgsConstructor
public class AdminPromptTestController {

  private final AdminPromptService adminPromptService;

  @PostMapping("/admin/prompts/{key}/preview")
  public PromptPreviewResponse preview(@PathVariable PromptKey key, @RequestBody PromptSampleRequest request) {
    String composed = adminPromptService.preview(key, request.content(), request.sampleInput(), request.character());
    return new PromptPreviewResponse(composed);
  }

  @PostMapping("/admin/prompts/{key}/test")
  public PromptTestResponse test(@PathVariable PromptKey key, @RequestBody PromptSampleRequest request) {
    return adminPromptService.test(key, request.content(), request.sampleInput(), request.character());
  }
}
