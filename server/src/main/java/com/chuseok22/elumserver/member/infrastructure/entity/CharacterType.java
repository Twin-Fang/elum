package com.chuseok22.elumserver.member.infrastructure.entity;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public enum CharacterType {

  LULU(
    "루루",
    "아이보리색(#EFEDE8) 둥근 아기 고양이. 몸이 얼굴만큼 크고 통통하며 다리가 아주 짧다. "
      + "귀는 삼각형이고 안쪽이 연분홍색이다. 눈은 점처럼 작고 동그란 검은색이며 "
      + "코는 작은 분홍색 삼각형, 입은 짧은 곡선 두 개다. 꼬리는 가늘고 길게 옆으로 뻗는다.",
    "a round ivory baby kitten, chubby body as big as its head, very short legs, "
      + "triangle ears with light pink insides, tiny round black dot eyes, small pink triangle nose, "
      + "mouth of two short curves, long thin tail stretched to the side",
    "kitten"
  ),
  POPO(
    "포포",
    "주황색(#FF8B26) 아기 여우. 몸이 둥글고 다리가 아주 짧다. 귀는 뾰족한 삼각형이고 "
      + "안쪽이 크림색이다. 배와 가슴, 꼬리 끝이 크림색이다. 눈은 점처럼 작고 동그란 검은색이며 "
      + "코는 작은 검은 점, 입은 짧은 곡선이다.",
    "a round orange baby fox, very short legs, pointed triangle ears with cream insides, "
      + "cream belly, chest and tail tip, tiny round black dot eyes, small black dot nose, short curved mouth",
    "fox cub"
  );

  private final String label;

  /**
   * 그림에 그려야 할 생김새.
   *
   * <p><b>왜 글로 적어 두는가.</b> 예전에는 캐릭터를 이름(`LULU`)으로만 넘겼다.
   * Gemini는 참조 PNG를 멀티모달 입력으로 함께 보내므로 그림이 곧 설명이어서 그것으로
   * 충분했다. 그러나 참조 이미지를 보낼 수 없는 제공자(OpenAI)는 `LULU`가 무엇인지 알
   * 도리가 없어 <b>사람을 그렸다</b>(이슈 #269).
   *
   * <p>색과 형태만 적고 <b>화풍은 적지 않는다.</b> 화풍은 프롬프트 프리픽스가 정하는데,
   * 두 곳에서 각자 말하면 서로 부딪힌다.
   *
   * <p>값은 {@code static/characters/*.png}를 보고 적었다. 참조 이미지를 바꾸면
   * 이 글도 함께 고친다 — 둘이 어긋나면 그림이 흔들린다.
   */
  private final String appearance;

  /**
   * 같은 생김새의 영어판 (#375 · #373).
   *
   * <p>영어 지시문(OpenAI·Gemini 의 EN 설정)과 FLUX 가 쓴다. FLUX 는 한국어를 거의 못 알아들어
   * 한국어 묘사를 주면 사람을 그렸다. <b>색 코드(#EFEDE8)는 적지 않는다</b> — FLUX 가 그런 문자열을
   * 그림 속 글자로 찍는다. 위 한국어 묘사와 같은 내용이어야 한다. 하나를 고치면 같이 고친다.
   */
  private final String appearanceEn;

  /// FLUX 장면 문장의 주어("The character …")를 바꿔 넣을 짧은 이름.
  private final String subjectEn;
}
