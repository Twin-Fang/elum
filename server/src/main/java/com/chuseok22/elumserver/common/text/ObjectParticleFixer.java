package com.chuseok22.elumserver.common.text;

import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * ko AI 문장 목적격 조사 보정 (#1190): 받침 없음 + 을 > 를, 받침 있음 + 를 > 을
 * '을' 로 끝나는 낱말 2종(가을·마을 같은 명사, 지을·부을 같은 ㅅ불규칙 관형형)은 그대로 둠
 */
public final class ObjectParticleFixer {

  // 한글 낱말 + 을/를 + 낱말 끝(뒤에 한글 없음): 1 앞 낱말, 2 조사
  private static final Pattern WORD_WITH_OBJECT_PARTICLE = Pattern.compile("([가-힣]+)([을를])(?![가-힣])");
  private static final String PARTICLE_AFTER_JONGSEONG = "을";
  private static final String PARTICLE_AFTER_VOWEL = "를";
  // '을' 로 끝나는 명사 4개 (끝 맞춤이라 늦가을·시골마을·저녁노을도 포함)
  private static final List<String> NOUNS_ENDING_WITH_EUL = List.of("가을", "마을", "노을", "고을");
  // ㅅ불규칙 관형형 6개: 긋다·낫다·붓다·잇다·젓다·짓다 (낱말 전체가 이 꼴일 때만)
  private static final Set<String> IRREGULAR_ADNOMINAL_FORMS = Set.of("그을", "나을", "부을", "이을", "저을", "지을");

  private ObjectParticleFixer() {
  }

  /**
   * 문장 > 목적격 조사를 앞 글자 받침에 맞춘 문장 (null·빈 글은 그대로)
   */
  public static String fix(String text) {
    if (text == null || text.isEmpty()) {
      return text;
    }
    Matcher matcher = WORD_WITH_OBJECT_PARTICLE.matcher(text);
    StringBuilder fixed = new StringBuilder(text.length());
    while (matcher.find()) {
      String stem = matcher.group(1);
      String particle = matcher.group(2);
      matcher.appendReplacement(fixed, Matcher.quoteReplacement(stem + particleFor(stem, particle)));
    }
    matcher.appendTail(fixed);
    return fixed.toString();
  }

  // 받침에 맞는 조사 (낱말인 '을' 은 원래 조사 유지)
  private static String particleFor(String stem, String particle) {
    if (isWordFinalEul(stem + particle)) {
      return particle;
    }
    boolean hasJongseong = HangulSyllables.hasJongseong(stem.charAt(stem.length() - 1));
    return hasJongseong ? PARTICLE_AFTER_JONGSEONG : PARTICLE_AFTER_VOWEL;
  }

  private static boolean isWordFinalEul(String word) {
    return IRREGULAR_ADNOMINAL_FORMS.contains(word) || NOUNS_ENDING_WITH_EUL.stream().anyMatch(word::endsWith);
  }
}
