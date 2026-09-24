package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

/**
 * FLUX 프롬프트 조립 — 짧은 영어 한 덩어리 (#373).
 *
 * <p>OpenAI·Gemini 와 달리 JSON 장면 정보를 붙이지 않는다. schnell 은 긴 지시문과 JSON 을 그림 속
 * 글자로 찍었다. 2차 시험과 같은 모양 — 화풍 지시문 + "Only one character: {생김새}." + 장면 한 줄.
 *
 * <p>글 AI 는 캐릭터를 모르므로 장면을 "The character …" 로 쓰게 하고, 여기서 캐릭터 이름
 * ("The kitten")으로 바꾼다. 2차 시험에서 쓴 문장 모양이다.
 */
@Component
public class FluxPromptBuilder {

  private static final Pattern SUBJECT_CAPITAL = Pattern.compile("\\bThe character\\b");
  private static final Pattern SUBJECT_LOWER = Pattern.compile("\\bthe character\\b");
  private static final Pattern WHITESPACE = Pattern.compile("\\s+");
  /// 캐릭터를 고르지 않은 회원 — 한국어 지시문의 "나이를 짐작하기 어려운 단순한 인물"과 같다.
  private static final String NO_CHARACTER = "a simple friendly figure whose age is hard to guess";
  private static final String NO_CHARACTER_SUBJECT = "figure";

  public String build(String prefix, String sceneEn, CharacterType characterType) {
    String appearance = characterType == null ? NO_CHARACTER : characterType.getAppearanceEn();
    String subject = characterType == null ? NO_CHARACTER_SUBJECT : characterType.getSubjectEn();
    String scene = WHITESPACE.matcher(sceneEn == null ? "" : sceneEn).replaceAll(" ").trim();
    scene = SUBJECT_CAPITAL.matcher(scene).replaceAll("The " + subject);
    scene = SUBJECT_LOWER.matcher(scene).replaceAll("the " + subject);
    return prefix.trim() + " Only one character: " + appearance + ". " + scene;
  }
}
