package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.core.GeneratedImage;
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
   * 카드 생성이 전부 실패하는 사고</b>를 저장 단계에서 끊기 위해서다.
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

  /// 관리자 테스트 전용: 저장된 프롬프트 대신 전달받은 prefix를 그대로 쓴다.
  GeneratedImage generateImageForTest(String prefix, String sampleInput, CharacterType characterType);
}
