package com.chuseok22.elumserver.ai.core;

import java.util.List;

/**
 * 번역에 보내는 일과 글: 일과 제목, 보상 이름, 카드 글(차례대로) (#1077)
 * 보호자 원문(rawInputText)·이룸이 이름은 담지 않음 (이름은 부르는 쪽이 자리표시로 바꿔 넣음)
 *
 * @param rewardText 보상 이름. 보상이 없으면 null
 */
public record RoutineTranslationDraft(String title, String rewardText, List<StepText> steps) {

  public RoutineTranslationDraft {
    steps = steps == null ? List.of() : List.copyOf(steps);
  }

  /// 카드 한 장의 글. title 은 옛 카드면 null
  public record StepText(String title, String description) {

  }
}
