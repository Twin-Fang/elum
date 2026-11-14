package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;

/**
 * 영어 장면 한 줄로 그리는 제공자 (FLUX·Cloudflare): 만화, 실사, 관리자 시험
 * 한국어 설명은 받지 않는다 > CardImageGenerator 가 영어 장면을 마련해 부른다
 */
public interface EnglishSceneImageClient extends ImageGenerationClient {

  /// 만화: 화풍 + 인물 생김새 + 영어 장면. seed 는 일과마다 고정 (null 이면 제공자가 고름)
  GeneratedImage generate(String sceneEn, CharacterType characterType, Integer seed);

  /**
   * 다시 그리기(보호자 요청 반영 장면): 기본은 generate 와 같음
   * 인물 생김새를 장면에 맞게 줄이는 제공자(CLOUDFLARE)만 덮어씀 (#1384)
   */
  default GeneratedImage generateWithGuardianRequest(String sceneEn, CharacterType characterType, Integer seed) {
    return generate(sceneEn, characterType, seed);
  }

  /// 실사: 실사 지시문 + 영어 장면 (인물 없음)
  GeneratedImage generateRealistic(String sceneEn, Integer seed);

  /// 관리자 시험: 저장된 화풍 대신 넘겨받은 prefix, seed 없음
  GeneratedImage generateForTest(String prefix, String sceneEn, CharacterType characterType);

  /**
   * 카드 그림에서 프로필 캐릭터(루루·포포)를 빼는가 (기본 false: 캐릭터를 그림)
   * true 면 이 제공자가 실패해 OpenAI 로 넘어간 카드도 캐릭터 없이 그린다
   */
  default boolean shouldDropProfileCharacter() {
    return false;
  }

  /// 지금은 부르지 않는 상태인가 (하루 한도 소진 등). true 면 번역도 하지 않고 바로 OpenAI
  default boolean isTemporarilySkipped() {
    return false;
  }
}
