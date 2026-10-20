package com.chuseok22.elumserver.ai.core;

/**
 * 만화 카드 그림 화면 규격: 흰 배경, 같은 크기, 캐릭터 한 명, 글자·장식 금지
 * 운영 DB 지시문(관리자가 손으로 고침)과 별개로 코드에 둠 > 배포하면 바로 모든 카드에 적용
 * (실사·FLUX 는 이 규격을 쓰지 않음, 캐릭터 그림 지시문 뒤에 붙임)
 */
public final class ImageCardLayoutRules {

  public static final String KO = """
    [화면 규격 - 모든 카드 동일]
    - 배경은 순백(#FFFFFF) 한 가지 색입니다. 벽, 바닥, 하늘, 풍경, 건물, 도로, 창밖 같은 배경 장면을 그리지 않습니다.
    - 캐릭터 몸 아래에 옅은 회색 타원 그림자 하나만 허용합니다.
    - 캐릭터는 전신이 보이고 화면 높이의 60% 안팎, 화면 중앙에 놓입니다. 카드마다 같은 크기로 그립니다.
    - 장면에는 이 행동에 꼭 필요한 물건 1~2개만 그립니다. 물건은 캐릭터 가까이에 크게 그립니다.
    - 캐릭터는 참조 이미지와 같은 얼굴, 몸 비율, 색, 같은 굵기의 어두운 회색 외곽선으로 그립니다. 눈썹, 땀, 수염 선, 화난 표정을 만들지 않습니다.
    - 그림 전체에 캐릭터는 한 명뿐입니다. 가족, 친구, 선생님, 의사 같은 다른 사람이나 동물은 그리지 않고 문, 의자, 가방 같은 물건과 캐릭터의 자세로 보여줍니다.
    - scene.sceneDetail이 있으면 그 문장의 자세, 손에 든 물건, 물건 위치를 그대로 그립니다. scene.routineTitle은 참고용이고 그리지 않습니다.
    - 장면에 간판, 표지판, EXIT, 시계 문자판, 책 제목, 숫자가 언급되어도 글자는 그리지 않습니다.
    - 온도계, 구름, 하트, 땀방울 같은 기분·상태 기호와 장식을 넣지 않습니다.""";

  public static final String EN = """
    [Canvas rules - identical for every card]
    - The background is pure white (#FFFFFF) only. Do not draw walls, floors, sky, scenery, buildings, roads, or windows.
    - Allow only one pale gray oval shadow under the character.
    - Show the full body of the character at about 60% of the image height, centered. Draw it at the same size on every card.
    - Draw only the 1-2 objects this action needs, large and close to the character.
    - Draw the character with the same face, body proportions, colors, and the same dark gray outline thickness as the reference. No eyebrows, sweat, whisker lines, or angry face.
    - Exactly one character in the whole picture. Never draw other people or animals (family, friend, teacher, doctor); show them with objects such as a door, chair, or bag and the character's pose.
    - If scene.sceneDetail is present, draw its pose, held objects, and object positions exactly. scene.routineTitle is for reference only; do not draw it.
    - Even if the scene mentions a sign, EXIT, clock face, book title, or numbers, draw no text.
    - No mood or status symbols or decorations such as thermometers, clouds, hearts, or sweat drops.""";

  private ImageCardLayoutRules() {
  }

  /// 그림 지시문 언어에 맞는 규격
  public static String of(ImagePromptLanguage language) {
    return language == ImagePromptLanguage.EN ? EN : KO;
  }
}
