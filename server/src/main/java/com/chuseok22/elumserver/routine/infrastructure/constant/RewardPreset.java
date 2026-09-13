package com.chuseok22.elumserver.routine.infrastructure.constant;

import java.util.Arrays;

/// 보호자가 고를 수 있는 보상(강화물) 프리셋.
///
/// 자유 입력만 받지 않고 프리셋을 두는 이유는 **아동 화면에 그림을 띄우기 위해서**다.
/// 글자를 못 읽는 사용자에게 텍스트만 보여주면 아무 의미가 없다.
///
/// 프리셋 선택을 강제하지는 않는다. 직접 입력하면 [#CUSTOM]으로 저장되고
/// 아동 화면에는 기본 아이콘과 함께 텍스트가 표시된다.
///
/// 2026-09-13 서울 ABA연구소 자문 — *"한 달 뒤 선물보다 오늘 받을 수 있는 것이 낫다"*
public enum RewardPreset {

  SNACK("좋아하는 간식"),
  VIDEO("유튜브 10분"),
  PLAY("좋아하는 놀이"),
  WALK("산책"),
  CUSTOM("직접 입력");

  private final String label;

  RewardPreset(String label) {
    this.label = label;
  }

  public String getLabel() {
    return label;
  }

  /// 클라이언트가 보낸 키가 유효한지 확인한다. null·빈 값·미정의 키는 전부 null로 떨군다.
  ///
  /// 잘못된 키 때문에 일과 생성 자체가 실패하면 안 된다 — 보상은 선택 항목이다.
  public static String normalize(String key) {
    if (key == null || key.isBlank()) {
      return null;
    }
    return Arrays.stream(values())
      .map(Enum::name)
      .filter(name -> name.equalsIgnoreCase(key))
      .findFirst()
      .orElse(null);
  }
}
