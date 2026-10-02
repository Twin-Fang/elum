package com.chuseok22.elumserver.routine.infrastructure.guard;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.EnabledLocales;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutinePhrases;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

/**
 * 켜진 언어의 서버 문구 한 벌(폴백 질문·추천 일과)이 비어 있으면 서버를 띄우지 않는다.
 *
 * <p>AI 가 실패하는 바로 그 순간에 보여줄 문구도 없는 일(서비스 원칙 6 위반)을 막는다. 검사 대상은 ko(모든 대체 순서의
 * 끝)와 {@link EnabledLocales#current()} 다 — 관리자 화면 가드를 우회한 DB 직접 수정으로 켜진 언어도 여기서 잡힌다.
 * 기본 설정(ko 만)에서는 다른 언어 파일이 비어 있어도 뜬다.
 *
 * <p>DB 시딩(SystemConfigInitializer) 순서에 의존하지 않아 {@code @Order} 가 필요 없다 — 설정 행이 아직 없으면
 * 기본값 ko 로, 읽기에 실패해도 ko 만으로 검사한다. 행이 이미 있으면 시딩과 무관하게 그 값을 읽는다.
 */
@Slf4j
@Component
public class RoutinePhrasesStartupGuard implements ApplicationRunner {

  private static final int MAX_KEYS_IN_MESSAGE = 5;

  private final EnabledLocales enabledLocales;
  private final RoutinePhrases phrases;

  @Autowired
  public RoutinePhrasesStartupGuard(EnabledLocales enabledLocales) {
    this(enabledLocales, null);
  }

  RoutinePhrasesStartupGuard(EnabledLocales enabledLocales, RoutinePhrases phrases) {
    this.enabledLocales = enabledLocales;
    this.phrases = phrases;
  }

  @Override
  public void run(ApplicationArguments args) {
    verify();
  }

  void verify() {
    // 주입된 것이 없으면 호출 시점의 standard() 를 쓴다 — 클래스 로드나 생성 시점에 값을 굳히지 않는다.
    RoutinePhrases target = phrases != null ? phrases : RoutinePhrases.standard();
    Set<AppLocale> locales = new LinkedHashSet<>();
    locales.add(AppLocale.KO);
    locales.addAll(enabledLocales.current());

    List<String> numbering = target.koNumberingProblems();
    Map<AppLocale, List<String>> incomplete = target.incompleteLocales(locales);
    if (numbering.isEmpty() && incomplete.isEmpty()) {
      log.info("[RoutinePhrasesStartupGuard] 서버 문구 확인 완료: {}", locales);
      return;
    }

    StringBuilder message = new StringBuilder("서버 문구 파일(i18n/routine-phrases_*.properties)에 문제가 있어 기동을 멈춥니다.");
    if (!numbering.isEmpty()) {
      message.append(" [ko 번호 구멍: ").append(summarize(numbering)).append("]");
    }
    incomplete.forEach((locale, keys) -> message
      .append(" [").append(locale.code()).append(" 빈 키: ").append(summarize(keys)).append("]"));
    message.append(" 파일을 채우거나 시스템 설정 ENABLED_CONTENT_LOCALES 에서 그 언어를 끈다.");
    throw new IllegalStateException(message.toString());
  }

  private static String summarize(List<String> keys) {
    String head = keys.stream().limit(MAX_KEYS_IN_MESSAGE).toList().toString();
    return keys.size() > MAX_KEYS_IN_MESSAGE ? head + " 외 " + (keys.size() - MAX_KEYS_IN_MESSAGE) + "개" : head;
  }
}
