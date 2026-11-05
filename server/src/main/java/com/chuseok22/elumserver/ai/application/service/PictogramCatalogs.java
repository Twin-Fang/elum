package com.chuseok22.elumserver.ai.application.service;

import com.chuseok22.elumserver.ai.core.PictogramSet;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

/**
 * 그림 기호 세트별 카탈로그: Mulberry(기존 빈), 이모지(emoji/catalog.json, #1149)
 * 이모지 카탈로그가 비면 이모지 세트도 Mulberry 로 고름 (그림 빈 카드보다 나음)
 */
@Slf4j
@Component
public class PictogramCatalogs {

  // 이모지 카탈로그 위치 (server/tool/emoji/build_emoji_catalog.py 생성물)
  static final String EMOJI_RESOURCE_PATH = "emoji/catalog.json";

  private final PictogramCatalog mulberry;
  private final PictogramCatalog emoji;

  @Autowired
  public PictogramCatalogs(PictogramCatalog mulberry) {
    this(mulberry, PictogramCatalog.fromClasspath(EMOJI_RESOURCE_PATH));
  }

  public PictogramCatalogs(PictogramCatalog mulberry, PictogramCatalog emoji) {
    this.mulberry = mulberry;
    this.emoji = emoji;
    if (emoji.isEmpty()) {
      log.warn("[pictogram catalogs] emoji catalog empty : emoji style falls back to mulberry");
    }
  }

  /// 이모지 없이 Mulberry 하나만 (테스트·수동 구성)
  public static PictogramCatalogs mulberryOnly(PictogramCatalog mulberry) {
    return new PictogramCatalogs(mulberry, PictogramCatalog.empty());
  }

  /// 세트 > 카탈로그 (null·이모지 빈 경우 Mulberry)
  public PictogramCatalog of(PictogramSet set) {
    if (set == PictogramSet.EMOJI && !emoji.isEmpty()) {
      return emoji;
    }
    return mulberry;
  }

  /// 전문가·예시 일과처럼 Mulberry id 만 받는 경로용
  public PictogramCatalog mulberry() {
    return mulberry;
  }
}
