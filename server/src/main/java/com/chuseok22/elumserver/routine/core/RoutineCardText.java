package com.chuseok22.elumserver.routine.core;

import java.util.List;
import java.util.Objects;

/**
 * 카드 한 장의 글 (AI 메모 스냅샷·비교용, #1082). 그림·완료 상태는 들지 않음
 */
public record RoutineCardText(String title, String description) {

  /// 프롬프트에 싣는 한 줄 모양: "제목 / 설명" (설명 없으면 제목만)
  public String toPromptLine() {
    String safeTitle = title == null ? "" : title.trim();
    String safeDescription = description == null ? "" : description.trim();
    return safeDescription.isEmpty() ? safeTitle : safeTitle + " / " + safeDescription;
  }

  /// 처음 AI 카드 <-> 확정 카드가 다른가 (카드 수·순서·제목·설명 중 하나라도)
  public static boolean isEdited(List<RoutineCardText> aiCards, List<RoutineCardText> confirmedCards) {
    if (aiCards.size() != confirmedCards.size()) {
      return true;
    }
    for (int index = 0; index < aiCards.size(); index++) {
      RoutineCardText before = aiCards.get(index);
      RoutineCardText after = confirmedCards.get(index);
      if (!Objects.equals(normalize(before.title()), normalize(after.title()))
        || !Objects.equals(normalize(before.description()), normalize(after.description()))) {
        return true;
      }
    }
    return false;
  }

  private static String normalize(String text) {
    return text == null ? "" : text.trim();
  }
}
