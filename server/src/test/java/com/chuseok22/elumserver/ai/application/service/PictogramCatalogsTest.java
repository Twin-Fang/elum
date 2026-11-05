package com.chuseok22.elumserver.ai.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.ai.core.PictogramSet;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 그림 방식별 카탈로그 고르기 (#1149): 이모지 방식 카드가 이모지 목록에서, 그 외는 Mulberry 에서 고른다.
 */
class PictogramCatalogsTest {

  @Test
  @DisplayName("이모지 방식은 번들된 이모지 카탈로그를, 그 외는 Mulberry 카탈로그를 돌려준다")
  void emojiSetLoadsEmojiCatalog() {
    PictogramCatalogs catalogs = new PictogramCatalogs(new PictogramCatalog());

    assertThat(catalogs.of(PictogramSet.EMOJI).contains("emoji_toothbrush")).isTrue();
    assertThat(catalogs.of(PictogramSet.EMOJI).contains("brush_teeth_,_to")).isFalse();
    assertThat(catalogs.of(PictogramSet.EMOJI).fallbackId()).isEqualTo("emoji_star");
    assertThat(catalogs.of(PictogramSet.MULBERRY).contains("brush_teeth_,_to")).isTrue();
  }

  @Test
  @DisplayName("이모지 카탈로그를 못 읽은 서버는 이모지 방식도 Mulberry 로 고른다 — 그림 빈 카드보다 낫다")
  void emptyEmojiFallsBackToMulberry() {
    PictogramCatalog mulberry = new PictogramCatalog(List.of("brush_teeth", "go_,_to"), "go_,_to");
    PictogramCatalogs catalogs = new PictogramCatalogs(mulberry, PictogramCatalog.empty());

    assertThat(catalogs.of(PictogramSet.EMOJI)).isSameAs(mulberry);
  }
}
