package com.chuseok22.elumserver.member.infrastructure.entity;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 이룸이(프로필) 단위 카드 그림 방식.
 *
 * <p>캐릭터 카드가 맞는 이룸이가 있고, 실제 물건·장소 사진이 더 잘 통하는 이룸이가 있다.
 * 그래서 카드 그림을 어떻게 만들지를 프로필에 저장하고 생성 경로가 이 값으로 갈린다.
 */
@Getter
@AllArgsConstructor
public enum ImageStyle {

  /// 캐릭터 만화 그림. 기본값이며 이 값의 동작은 그림 방식이 생기기 전과 똑같다.
  CARTOON("만화"),
  /// 캐릭터 없이 물건·장소를 사진처럼 그린다. 캐릭터 참조 이미지·묘사를 쓰지 않는다.
  REALISTIC("실사"),
  /// AI 그림을 만들지 않는다(보호자가 직접 사진을 넣는다). 카드 글 생성은 그대로 AI 가 한다.
  PHOTO_ONLY("직접 사진");

  private final String label;

  /// 저장값이 비어 있으면(옛 행·옛 서버가 쓴 행) 기본 만화로 본다.
  public static ImageStyle orDefault(ImageStyle style) {
    return style == null ? CARTOON : style;
  }
}
