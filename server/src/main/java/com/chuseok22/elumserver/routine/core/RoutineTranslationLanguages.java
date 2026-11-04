package com.chuseok22.elumserver.routine.core;

import com.chuseok22.elumserver.common.locale.AppLocale;
import java.util.Collections;
import java.util.EnumSet;
import java.util.Set;

/**
 * 다른 언어로 만들기(#1077)의 대상 언어: 앱이 여는 언어(client app_locales.dart openedAppLocales)와 같은 목록
 * 앱이 열지 않은 언어로 만든 일과는 버튼·안내가 그 언어로 안 보임 > 막음. 같은지는 CrossStackContractTest 가 대조
 */
public final class RoutineTranslationLanguages {

  /// 앱 openedAppLocales 와 같은 집합 (언어를 열면 두 곳을 함께 더함)
  public static final Set<AppLocale> TARGETS = Collections.unmodifiableSet(EnumSet.of(AppLocale.KO, AppLocale.EN));

  private RoutineTranslationLanguages() {
  }

  /// 이 일과(원문 언어)를 이 언어로 바꿀 수 있는가: 대상 목록 안 · 원문과 다름
  public static boolean canTranslate(AppLocale sourceLanguage, AppLocale targetLanguage) {
    return targetLanguage != null && TARGETS.contains(targetLanguage) && targetLanguage != sourceLanguage;
  }
}
