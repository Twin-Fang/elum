package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import java.util.Collection;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * 일과 생성 가능 언어 게이트: 번역이 필요한 프롬프트 행이 모두 있는 언어만 통과
 * 행의 존재(완결성)만 보며 번역 품질은 보지 않음, 조회만 하고 쓰지 않음
 */
@Component
@RequiredArgsConstructor
public class PromptLocaleGate {

  private final PromptTemplateService promptTemplateService;

  // ko 는 기동 때 행이 만들어지므로 보지 않음
  public void requireReady(Collection<AppLocale> requested) {
    for (AppLocale locale : requested) {
      if (locale != AppLocale.KO && !promptTemplateService.missingKeys(locale).isEmpty()) {
        throw new CustomException(ErrorCode.CONTENT_LOCALE_PROMPT_MISSING);
      }
    }
  }
}
