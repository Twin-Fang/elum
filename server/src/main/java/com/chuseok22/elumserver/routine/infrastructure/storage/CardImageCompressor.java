package com.chuseok22.elumserver.routine.infrastructure.storage;

import com.chuseok22.elumserver.ai.core.GeneratedImage;
import java.util.Optional;

/**
 * AI 카드 그림 압축 (#1219): 저장 직전 png 등 > webp. 실패하면 빈 값 (호출부가 원본 저장)
 */
public interface CardImageCompressor {

  // 압축하지 않음 (MinIO 안의 로컬 사본 등 운영 밖 경로용)
  CardImageCompressor NONE = image -> Optional.empty();

  /**
   * 그림 > webp 그림. 이미 webp 거나 실패면 빈 값
   */
  Optional<GeneratedImage> toWebp(GeneratedImage image);
}
