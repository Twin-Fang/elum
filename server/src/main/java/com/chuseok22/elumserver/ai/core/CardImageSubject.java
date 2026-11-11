package com.chuseok22.elumserver.ai.core;

import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 카드 그림에 그릴 인물: 생김새 지시문 키, 장면 주어 이름
 * 프로필 캐릭터 > 인물 매핑은 forProfileCharacter 한 곳 (캐릭터별·성별 인물은 여기 더한다)
 */
@Getter
@AllArgsConstructor
public enum CardImageSubject {

  CHILD(PromptKey.CARD_IMAGE_SUBJECT_CHILD, "child"),
  ;

  // 영어 생김새 지시문 (DB prompt_template, 관리자 화면에서 수정)
  private final PromptKey appearanceKey;
  // 장면 "The character …" 를 바꿔 넣을 짧은 이름
  private final String subjectEn;

  /**
   * 프로필 캐릭터 > 카드 그림 인물 (지금은 캐릭터와 무관하게 CHILD)
   */
  public static CardImageSubject forProfileCharacter(CharacterType characterType) {
    return CHILD;
  }
}
