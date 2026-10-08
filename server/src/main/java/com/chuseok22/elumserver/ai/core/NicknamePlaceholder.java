package com.chuseok22.elumserver.ai.core;

import java.util.List;
import lombok.extern.slf4j.Slf4j;

/**
 * 이룸이 이름을 AI 에 보내지 않기 위한 자리표시 처리.
 *
 * <p>AI 에는 이름 대신 {@link #PLACEHOLDER}({@code 이룸이})를 보내고, 응답에 나온 {@code 이룸이}를
 * 서버가 실제 이름으로 되돌린다({@link #restore}). 개인화(제목·질문에 이름이 들어감)는 그대로 둔 채
 * Google·OpenAI 로그에 이름이 남지 않게 하려는 것이다.
 *
 * <p>자리표시가 받침 없는 {@code 이}로 끝나 AI 는 늘 {@code 이룸이가·이룸이는}처럼 한 가지 조사로 쓴다.
 * 되돌릴 때 실제 이름의 마지막 글자 받침에 맞춰 조사를 다시 고른다. 영문·숫자 등 받침을 알 수 없는
 * 끝 글자는 받침 없음으로 본다.
 *
 * <p>반대 방향({@link #mask})은 보호자가 입력한 글에 이름이 그대로 들어 있을 때 AI 로 나가기 전에
 * 자리표시로 바꾼다. 어느 쪽이든 던지지 않고, 이름이 비면 원문을 그대로 돌려준다.
 */
@Slf4j
public final class NicknamePlaceholder {

  /// AI 에 보내는 호칭. 서비스가 당사자를 부르는 말이라 AI 가 문장에 자연스럽게 넣는다.
  public static final String PLACEHOLDER = "이룸이";

  /// 받침에 따라 모양이 바뀌는 조사. 긴 것부터 맞춘다(이에요 가 에요 보다 먼저).
  /// withJong = 받침 있을 때, withoutJong = 없을 때, withRieul = ㄹ받침일 때(null 이면 withJong 과 같다).
  private static final List<Josa> JOSA = List.of(
    new Josa("이에요", "이에요", "예요", null, true),
    new Josa("이라고", "이라고", "라고", null, true),
    new Josa("이라는", "이라는", "라는", null, true),
    new Josa("이라면", "이라면", "라면", null, true),
    new Josa("으로", "으로", "로", "로", true),
    new Josa("에요", "이에요", "예요", null, true),
    new Josa("예요", "이에요", "예요", null, true),
    new Josa("이랑", "이랑", "랑", null, true),
    new Josa("라고", "이라고", "라고", null, true),
    new Josa("라는", "이라는", "라는", null, true),
    new Josa("라면", "이라면", "라면", null, true),
    new Josa("가", "이", "가", null, true),
    new Josa("는", "은", "는", null, true),
    new Josa("를", "을", "를", null, true),
    new Josa("와", "과", "와", null, true),
    new Josa("야", "아", "야", null, true),
    new Josa("아", "아", "야", null, true),
    new Josa("랑", "이랑", "랑", null, true),
    new Josa("로", "으로", "로", "로", true),
    // 이었다·였어요 처럼 뒤에 어미가 붙는 꼴. 다음 글자가 한글이어도 조사로 본다.
    new Josa("였", "이었", "였", null, false)
  );

  /// 받침과 무관한 조사·꼴. 이름만 바꾸고 그대로 둔다 — 여기에 없는 글자가 붙어도(E5) 이름만 바꾼다.
  /// (이 목록은 mask 가 이름 뒤 글자를 조사로 볼지 판단할 때도 쓴다.)
  private static final String NAME_FOLLOWERS = "은는가을를과와랑야아도만의에로으께";

  private NicknamePlaceholder() {

  }

  /// AI 에 실을 닉네임. 이름이 있으면 자리표시, 없으면 null(없을 수 있다는 기존 계약을 지킨다).
  public static String forAi(String nickname) {
    return isBlank(nickname) ? null : PLACEHOLDER;
  }

  /// AI 응답 문장의 {@code 이룸이}를 실제 이름으로 바꾼다. 이름이 비었거나 바꿀 게 없거나 실패하면 원문 그대로.
  public static String restore(String text, String nickname) {
    if (text == null || isBlank(nickname) || !text.contains(PLACEHOLDER)) {
      return text;
    }
    try {
      String name = nickname.trim();
      StringBuilder out = new StringBuilder(text.length() + 8);
      int pos = 0;
      int hit;
      while ((hit = text.indexOf(PLACEHOLDER, pos)) >= 0) {
        out.append(text, pos, hit);
        int after = hit + PLACEHOLDER.length();
        Josa josa = matchJosa(text, after);
        if (josa == null) {
          out.append(name);
          pos = after;
        } else {
          out.append(name).append(josa.pick(name));
          pos = after + josa.token().length();
        }
      }
      out.append(text, pos, text.length());
      return out.toString();
    } catch (RuntimeException e) {
      // 치환만 포기한다 — AI 결과는 그대로 쓴다(자리표시가 보일 뿐 일과 생성은 이어진다).
      log.warn("이룸이 이름 치환 실패, 원문 그대로 둔다", e);
      return text;
    }
  }

  /// 입력 글에 적힌 실제 이름을 자리표시로 바꾼다(AI 로 나가기 전). 이름이 비었거나 한 글자이거나
  /// 자리표시 안에 들어가는 이름이면(자리표시를 깨뜨린다) 건드리지 않는다.
  public static String mask(String text, String nickname) {
    if (text == null || isBlank(nickname)) {
      return text;
    }
    String name = nickname.trim();
    if (name.length() < 2 || PLACEHOLDER.contains(name) || !text.contains(name)) {
      return text;
    }
    try {
      boolean hasJong = jongKind(name.charAt(name.length() - 1)) != 0;
      StringBuilder out = new StringBuilder(text.length());
      int pos = 0;
      int hit;
      while ((hit = text.indexOf(name, pos)) >= 0) {
        int end = hit + name.length();
        // 받침 있는 이름은 "하늘이가" 처럼 이름 뒤에 호칭 '이'를 붙여 쓴다. 뒤가 조사·끝이면 함께 먹는다.
        int consumed = end;
        if (hasJong && end < text.length() && text.charAt(end) == '이' && followsAsParticle(text, end + 1)) {
          consumed = end + 1;
        }
        // 뒤에 다른 한글이 이어지면 더 긴 낱말의 일부다("하늘색"). 건드리지 않는다.
        if (!followsAsParticle(text, consumed)) {
          out.append(text, pos, end);
          pos = end;
          continue;
        }
        out.append(text, pos, hit).append(PLACEHOLDER);
        pos = consumed;
      }
      out.append(text, pos, text.length());
      return out.toString();
    } catch (RuntimeException e) {
      log.warn("이룸이 이름 가리기 실패, 원문 그대로 둔다", e);
      return text;
    }
  }

  /// 문장 끝이거나 한글이 아니거나, 이름 뒤에 올 만한 조사 글자면 true.
  private static boolean followsAsParticle(String text, int idx) {
    if (idx >= text.length()) {
      return true;
    }
    char c = text.charAt(idx);
    if (!isHangulSyllable(c)) {
      return true;
    }
    return NAME_FOLLOWERS.indexOf(c) >= 0 || text.startsWith("한테", idx);
  }

  private static Josa matchJosa(String text, int from) {
    for (Josa josa : JOSA) {
      if (!text.startsWith(josa.token(), from)) {
        continue;
      }
      int next = from + josa.token().length();
      // 조사 뒤에 한글이 더 붙으면 조사가 아니라 다른 낱말의 앞부분이다("이룸이가방").
      if (josa.requireBoundary() && next < text.length() && isHangulSyllable(text.charAt(next))) {
        continue;
      }
      return josa;
    }
    return null;
  }

  /// 0 = 받침 없음(한글이 아니어도 0), 1 = 받침 있음, 2 = ㄹ받침.
  private static int jongKind(char c) {
    if (!isHangulSyllable(c)) {
      return 0;
    }
    int jong = (c - 0xAC00) % 28;
    if (jong == 0) {
      return 0;
    }
    return jong == 8 ? 2 : 1;
  }

  private static boolean isHangulSyllable(char c) {
    return c >= 0xAC00 && c <= 0xD7A3;
  }

  private static boolean isBlank(String s) {
    return s == null || s.isBlank();
  }

  private record Josa(String token, String withJong, String withoutJong, String withRieul, boolean requireBoundary) {

    String pick(String name) {
      int jong = jongKind(name.charAt(name.length() - 1));
      if (jong == 0) {
        return withoutJong;
      }
      if (jong == 2 && withRieul != null) {
        return withRieul;
      }
      return withJong;
    }
  }
}
