package com.chuseok22.elumserver.member.infrastructure.entity;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public enum CharacterType {

  LULU("루루"),
  POPO("포포");

  private final String label;
}
