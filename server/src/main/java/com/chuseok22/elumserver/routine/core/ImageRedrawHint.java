package com.chuseok22.elumserver.routine.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 고쳐서 다시 그리기 칩 4개: 더 단순하게 · 배경 빼기 · 사람 빼기 · 더 밝게
 * instruction = 그림 지시문의 보호자 요청에 붙는 영어 한 문장 (앱 문구는 앱 ARB)
 */
@Getter
@AllArgsConstructor
public enum ImageRedrawHint {

  SIMPLER("Make the picture simpler with fewer details."),
  NO_BACKGROUND("Remove the background and use a plain background."),
  NO_PEOPLE("Do not draw any other people besides the main character."),
  BRIGHTER("Use brighter, lighter colors."),
  ;

  private final String instruction;
}
