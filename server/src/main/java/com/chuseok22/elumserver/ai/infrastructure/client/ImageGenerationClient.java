package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.ai.core.ImagePromptLanguage;
import com.chuseok22.elumserver.ai.core.ImageProvider;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;

/**
 * 카드 삽화를 만드는 곳. 부르는 쪽은 어느 제공자인지 모른다.
 *
 * <p>구현체마다 자기 호출 기록과 비용 계산을 책임진다 — 단가 설정 키가 제공자마다
 * 다르기 때문이다.
 */
public interface ImageGenerationClient {

  ImageProvider provider();

  /**
   * 지금 쓸 수 있는 상태인가. API 키가 없으면 false.
   *
   * <p>관리자 화면이 이 값으로 전환 버튼을 막는다. <b>키 없는 제공자로 바꿔 놓고
   * 카드 생성이 전부 실패하는 상황</b>을 저장 단계에서 끊기 위해서다.
   */
  boolean available();

  /**
   * 참조 이미지로 캐릭터 일관성을 지킬 수 있는가.
   *
   * <p>false면 단계마다 다른 캐릭터가 나온다. 일과 카드는 <i>"단계마다 같은 모습이어야
   * 한 이야기로 읽힌다"</i>({@code Profile.character})가 전제라, 이게 깨지면 Pro의
   * 핵심 가치가 사라진다. 그래서 고르지 못하게 막지는 않되 화면에서 경고한다.
   */
  boolean supportsCharacterReference();

  GeneratedImage generateImage(String stepDescription, CharacterType characterType);

  /**
   * 실사 방식 — 캐릭터 없이 물건·장소를 사진처럼 그린다. 참조 이미지도 캐릭터 묘사도 쓰지 않는다.
   *
   * <p>기본 구현은 던진다. FLUX 는 영어 장면이 있어야 하므로 이 메서드가 아니라
   * {@code CardImageGenerator} 가 준비한 영어 장면으로 따로 부른다.
   */
  default GeneratedImage generateRealisticImage(String stepDescription) {
    throw new IllegalStateException(provider() + " 는 한국어 카드 설명으로 실사 그림을 그리지 않는다");
  }

  /// 관리자 테스트 전용: 저장된 프롬프트 대신 전달받은 prefix를 그대로 쓴다.
  /// language 는 그 prefix 가 어느 언어 키의 것인지 — 장면 머리말·생김새를 맞춰 싣는다.
  GeneratedImage generateImageForTest(
    String prefix, ImagePromptLanguage language, String sampleInput, CharacterType characterType);
}
