package com.chuseok22.elumserver.routine.infrastructure.constant;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineSuggestionResponse;
import java.util.List;

// 홈 화면 "추천 일과" 카드에 무작위로 노출할 데이터.
// DB에 저장하지 않는 정적 데이터라 엔티티/리포지토리를 두지 않는다.
// 문구의 원본은 i18n/routine-phrases_{언어}.properties 다 (다국어 #526). 항목을 더할 때는 ko 파일에 먼저 더한다.
//
// 항목을 추가할 때 지켜야 할 두 가지 (2026-09-13 서울 ABA연구소 자문):
//  1) 눈으로 "했다/안 했다"를 확인할 수 있는 행동만 넣는다.
//     "마음 다스리기", "진정하기" 같은 내면 조절은 카드로 만들 수 없다 —
//     기분이 나쁘면 폰을 던지지, 속으로 조절하지 않는다.
//  2) 아동·학교 전제를 두지 않는다. 성인 사용자에게 "학교에 가요"가 뜨면 안 된다.
public final class RoutineSuggestionCatalog {

  /** 한국어 기준 전체 목록(기존 이름 유지). 응답은 {@link #forLocale} 로 나가고 이 값은 테스트가 기준으로 쓴다. */
  // 클래스 로드 때 굳는 값이라 테스트 훅(standard())이 아닌 실제 클래스패스 문구로 만든다.
  public static final List<RoutineSuggestionResponse> ALL = RoutinePhrases.classpath().suggestions(AppLocale.KO);

  /** 요청 언어의 목록. 그 언어의 문구 파일이 한 벌 갖춰지지 않았으면 en → ko 순서로 대체한다. */
  public static List<RoutineSuggestionResponse> forLocale(AppLocale locale) {
    return RoutinePhrases.standard().suggestions(locale);
  }

  private RoutineSuggestionCatalog() {
  }
}
