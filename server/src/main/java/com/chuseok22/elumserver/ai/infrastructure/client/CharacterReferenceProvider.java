package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import java.io.IOException;
import java.io.InputStream;
import java.util.EnumMap;
import java.util.Map;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

// 캐릭터 참조 이미지는 앱과 함께 배포되는 고정 에셋이라, 매 루틴 이미지 생성 호출마다 디스크에서
// 다시 읽지 않도록 생성 시점(빈 초기화)에 한 번만 읽어 메모리에 캐싱해둔다. 파일이 없거나 읽기에
// 실패하면 예외를 그대로 던져 애플리케이션 기동을 막는다 — Gemini 호출 실패(fail-open)와 달리
// 정적 에셋 누락은 배포 실수이지 런타임에 감출 상황이 아니다.
@Component
public class CharacterReferenceProvider {

  private static final Map<CharacterType, String> ASSET_PATHS = Map.of(
    CharacterType.LULU, "static/characters/lulu.png",
    CharacterType.POPO, "static/characters/popo.png"
  );

  private final Map<CharacterType, byte[]> images;

  public CharacterReferenceProvider() {
    this.images = loadImages();
  }

  public byte[] get(CharacterType characterType) {
    return images.get(characterType);
  }

  private Map<CharacterType, byte[]> loadImages() {
    Map<CharacterType, byte[]> loaded = new EnumMap<>(CharacterType.class);
    ASSET_PATHS.forEach((characterType, path) -> loaded.put(characterType, readClasspathResource(path)));
    return loaded;
  }

  private byte[] readClasspathResource(String path) {
    try (InputStream inputStream = new ClassPathResource(path).getInputStream()) {
      return inputStream.readAllBytes();
    } catch (IOException e) {
      throw new IllegalStateException("캐릭터 이미지 로딩 실패: " + path, e);
    }
  }
}
