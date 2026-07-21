package com.chuseok22.elumserver.member.infrastructure.entity;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public enum SupportGoal {

  STEP_BY_STEP("해야 할 일을 순서대로 이해하기"),
  PREPARE_ITEMS("필요한 준비물을 스스로 챙기기"),
  PREPARE_NEW("새로운 상황을 미리 준비하기"),
  INDEPENDENT("혼자 끝까지 해내는 경험 만들기");

  private final String label;
}
