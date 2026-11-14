package com.chuseok22.elumserver.ai.core;

import com.chuseok22.elumserver.common.locale.AppLocale;
import java.util.Optional;
import java.util.Set;

/**
 * 보호자 입력 글자 체계 > 일과 언어: 한글 KO, 가나 JA, 한자만 ZH(화면이 ja 면 JA), 라틴 EN·ES (#1375)
 * 카드 글은 보호자가 쓴 언어로 만든다. 켜지지 않은 언어거나 판정이 안 되면 화면 언어 기준 값(fallback) 그대로
 */
public final class InputLanguageDetector {

  private InputLanguageDetector() {
  }

  /**
   * 입력 > 일과 언어 (켜진 언어만, 아니면 fallback)
   *
   * @param requested 화면 언어 (한자만·라틴 글을 가를 때 씀)
   * @param fallback  판정이 안 되거나 판정 언어가 꺼져 있을 때 쓸 값 (지금의 화면 언어 기준 결정)
   */
  public static AppLocale resolve(String inputText, AppLocale requested, Set<AppLocale> enabled, AppLocale fallback) {
    return detect(inputText, requested).filter(enabled::contains).orElse(fallback);
  }

  /**
   * 글자 체계 판정 (우선순위: 한글 > 가나 > 한자 > 라틴). 글자가 없으면(이모지·숫자만) 비어 있음
   * 한글이 한 글자라도 있으면 KO: 영어를 섞어 쓴 한국어 보호자 입력("brush teeth 양치")을 KO 로 둔다
   */
  public static Optional<AppLocale> detect(String inputText, AppLocale requested) {
    if (inputText == null || inputText.isBlank()) {
      return Optional.empty();
    }
    ScriptCounts counts = ScriptCounts.of(inputText);
    if (counts.hangul() > 0) {
      return Optional.of(AppLocale.KO);
    }
    if (counts.kana() > 0) {
      return Optional.of(AppLocale.JA);
    }
    // 한자만 쓴 글("病院")은 ja·zh 공통: 화면이 ja 면 JA
    if (counts.han() > 0) {
      return Optional.of(requested == AppLocale.JA ? AppLocale.JA : AppLocale.ZH);
    }
    // 라틴: 영어·스페인어를 글자로 가르지 않고 화면 언어가 ES 면 ES, 그 밖은 EN
    if (counts.latin() > 0) {
      return Optional.of(requested == AppLocale.ES ? AppLocale.ES : AppLocale.EN);
    }
    return Optional.empty();
  }

  /// 글자 체계별 글자 수 (라틴은 악센트 글자 포함)
  private record ScriptCounts(int hangul, int kana, int han, int latin) {

    static ScriptCounts of(String text) {
      int hangul = 0;
      int kana = 0;
      int han = 0;
      int latin = 0;
      for (int index = 0; index < text.length(); ) {
        int codePoint = text.codePointAt(index);
        index += Character.charCount(codePoint);
        if (!Character.isLetter(codePoint)) {
          continue;
        }
        switch (Character.UnicodeScript.of(codePoint)) {
          case HANGUL -> hangul++;
          case HIRAGANA, KATAKANA -> kana++;
          case HAN -> han++;
          case LATIN -> latin++;
          default -> {
          }
        }
      }
      return new ScriptCounts(hangul, kana, han, latin);
    }
  }
}
