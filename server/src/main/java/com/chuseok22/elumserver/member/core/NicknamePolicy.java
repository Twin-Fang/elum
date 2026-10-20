package com.chuseok22.elumserver.member.core;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.text.Normalizer;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

/**
 * 보호자 닉네임 판정: 형식, 예약어, 욕설 (한국어·영어·일본어·중국어·스페인어)
 * 형식 검사 > 비교용 문자열(소문자, 하이픈 제거, 숫자 우회 정리)에 목록 단어 포함 시 거절
 */
@Component
public class NicknamePolicy {

  private static final int MIN_LENGTH = 2;
  private static final int MAX_LENGTH = 16;
  // 한글 완성형, 영문, 숫자, 하이픈만 (자모 단독·공백·이모지·보이지 않는 문자는 여기서 걸림)
  private static final Pattern ALLOWED_CHARACTERS = Pattern.compile("^[가-힣A-Za-z0-9-]+$");
  // 글자(한글·영문) 최소 1자 ("--", "1-" 같은 기호·숫자만 이름 차단)
  private static final Pattern HAS_LETTER = Pattern.compile("[가-힣A-Za-z]");
  // 허용 예외 단어를 지운 자리 (앞뒤가 이어붙어 새 금지어가 되지 않게)
  private static final String ALLOWED_WORD_MASK = "\u0000";

  // 리소스 목록 (한 줄 한 단어, # 주석)
  private static final List<String> PROFANITY_RESOURCES = List.of(
    "nickname/profanity-ko.txt", "nickname/profanity-en.txt", "nickname/profanity-ja.txt",
    "nickname/profanity-zh.txt", "nickname/profanity-es.txt");
  private static final String RESERVED_RESOURCE = "nickname/reserved.txt";
  private static final String ALLOW_RESOURCE = "nickname/profanity-allow.txt";

  // 영문 사이 숫자 > 비슷한 글자 (sh1t, b4d)
  private static final String LEET_DIGITS = "013457";
  private static final String LEET_LETTERS = "oieast";

  private final List<String> blockedKeys;
  private final List<String> allowedKeys;

  public NicknamePolicy() {
    List<String> blocked = new ArrayList<>();
    PROFANITY_RESOURCES.forEach(resource -> blocked.addAll(readRequiredWords(resource)));
    blocked.addAll(readRequiredWords(RESERVED_RESOURCE));
    this.blockedKeys = blocked.stream().map(NicknamePolicy::toComparisonKey).filter(key -> !key.isEmpty()).toList();
    this.allowedKeys = readRequiredWords(ALLOW_RESOURCE).stream().map(NicknamePolicy::toComparisonKey).toList();
  }

  /**
   * 입력 > 저장할 모양 (앞뒤 공백 제거, NFKC). null 이면 빈 문자열
   */
  public String normalize(String rawNickname) {
    if (rawNickname == null) {
      return "";
    }
    return Normalizer.normalize(rawNickname.strip(), Normalizer.Form.NFKC);
  }

  /**
   * 정규화된 닉네임 판정: 형식 > 허용 예외 제거 > 목록 단어 포함 검사
   */
  public NicknameVerdict judge(String normalizedNickname) {
    if (!isValidFormat(normalizedNickname)) {
      return NicknameVerdict.INVALID_FORMAT;
    }
    String comparisonKey = toComparisonKey(normalizedNickname);
    for (String allowedKey : allowedKeys) {
      comparisonKey = comparisonKey.replace(allowedKey, ALLOWED_WORD_MASK);
    }
    for (String blockedKey : blockedKeys) {
      if (comparisonKey.contains(blockedKey)) {
        return NicknameVerdict.NOT_ALLOWED;
      }
    }
    return NicknameVerdict.ALLOWED;
  }

  private boolean isValidFormat(String nickname) {
    int length = nickname.codePointCount(0, nickname.length());
    return length >= MIN_LENGTH && length <= MAX_LENGTH
      && ALLOWED_CHARACTERS.matcher(nickname).matches() && HAS_LETTER.matcher(nickname).find();
  }

  /**
   * 비교용 문자열: NFKC·소문자 > 하이픈·기호 제거 > 숫자 정리(영문 사이 치환, 그 외 제거) > 연속 글자 줄임
   */
  static String toComparisonKey(String word) {
    String lowered = Normalizer.normalize(word, Normalizer.Form.NFKC).toLowerCase(Locale.ROOT);
    StringBuilder withoutSymbols = new StringBuilder();
    lowered.codePoints()
      .filter(codePoint -> Character.isLetterOrDigit(codePoint))
      .forEach(withoutSymbols::appendCodePoint);
    return collapseRepeatedCharacters(resolveDigits(withoutSymbols.toString()));
  }

  // 같은 글자 연속 > 한 글자 (sh11t > shiit > shit, fuuuck > fuck). 목록 단어도 같은 규칙으로 줄여 비교
  private static String collapseRepeatedCharacters(String text) {
    StringBuilder collapsed = new StringBuilder();
    for (int index = 0; index < text.length(); index++) {
      char current = text.charAt(index);
      if (index == 0 || current != text.charAt(index - 1)) {
        collapsed.append(current);
      }
    }
    return collapsed.toString();
  }

  // 숫자 앞뒤가 영문이면 비슷한 글자로, 아니면 지움 (시1발 > 시발, sh1t > shit)
  private static String resolveDigits(String text) {
    StringBuilder resolved = new StringBuilder();
    for (int index = 0; index < text.length(); index++) {
      char current = text.charAt(index);
      if (!Character.isDigit(current)) {
        resolved.append(current);
        continue;
      }
      boolean isBetweenLatinLetters = isLatinLetterAt(text, index - 1) || isLatinLetterAt(text, index + 1);
      int leetIndex = LEET_DIGITS.indexOf(current);
      if (isBetweenLatinLetters && leetIndex >= 0) {
        resolved.append(LEET_LETTERS.charAt(leetIndex));
      }
    }
    return resolved.toString();
  }

  private static boolean isLatinLetterAt(String text, int index) {
    if (index < 0 || index >= text.length()) {
      return false;
    }
    char character = text.charAt(index);
    return character >= 'a' && character <= 'z';
  }

  // 목록 파일 없거나 비면 기동 실패 (조용히 통과시키지 않음)
  private static List<String> readRequiredWords(String resource) {
    InputStream stream = NicknamePolicy.class.getClassLoader().getResourceAsStream(resource);
    if (stream == null) {
      throw new IllegalStateException("[member nickname] word list missing : " + resource);
    }
    List<String> words = new ArrayList<>();
    try (BufferedReader reader = new BufferedReader(new InputStreamReader(stream, StandardCharsets.UTF_8))) {
      reader.lines()
        .map(String::strip)
        .filter(line -> !line.isEmpty() && !line.startsWith("#"))
        .forEach(words::add);
    } catch (IOException e) {
      throw new IllegalStateException("[member nickname] word list unreadable : " + resource, e);
    }
    if (words.isEmpty()) {
      throw new IllegalStateException("[member nickname] word list empty : " + resource);
    }
    return words;
  }
}
