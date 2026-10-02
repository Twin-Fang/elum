package com.chuseok22.elumserver.common.infrastructure.exception;

import com.chuseok22.elumserver.common.locale.AppLocale;
import java.util.ArrayList;
import java.util.List;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

/**
 * 모든 에러 코드에 ko 문구가 있는지 서버가 뜰 때 확인한다.
 *
 * <p>ko 리소스가 깨지거나 빠진 채 빌드되면 사용자 에러가 전부 {@code ROUTINE_NOT_FOUND} 같은 상수명으로 나간다.
 * 운영 배포는 테스트를 건너뛰고 빌드하므로 테스트만으로는 막지 못해, 문구 파일 가드({@code RoutinePhrasesStartupGuard})와
 * 같은 방식으로 기동 단계에서 막는다. 문구는 기동 시점의 {@link ErrorMessages#standard()} 로 읽는다.
 */
@Slf4j
@Component
public class ErrorMessagesStartupGuard implements ApplicationRunner {

  private static final int MAX_CODES_IN_MESSAGE = 5;

  @Override
  public void run(ApplicationArguments args) {
    verify();
  }

  private void verify() {
    ErrorMessages messages = ErrorMessages.standard();
    List<String> broken = new ArrayList<>();
    for (ErrorCode code : ErrorCode.values()) {
      String text = messages.of(code, AppLocale.KO);
      // 키가 없으면 ErrorMessages 가 코드 이름을 그대로 돌려주므로 이름과 같은 것도 누락이다.
      if (text == null || text.isBlank() || text.equals(code.name())) {
        broken.add(code.name());
      }
    }
    if (broken.isEmpty()) {
      log.info("[ErrorMessagesStartupGuard] 에러 문구 확인 완료: {}개", ErrorCode.values().length);
      return;
    }
    String head = broken.stream().limit(MAX_CODES_IN_MESSAGE).toList().toString();
    String summary = broken.size() > MAX_CODES_IN_MESSAGE ? head + " 외 " + (broken.size() - MAX_CODES_IN_MESSAGE) + "개" : head;
    throw new IllegalStateException(
      "에러 문구 파일(i18n/messages_ko.properties)에 ko 문구가 없는 코드가 있어 기동을 멈춥니다: " + summary);
  }
}
