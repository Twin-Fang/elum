package com.chuseok22.elumserver.ai.core;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 영어 장면 경로를 타는 제공자 — 틀리면 한국어 설명이 FLUX·Cloudflare 로 가 사람·글자가 그려진다
class ImageProviderTest {

  @Test
  @DisplayName("FLUX·CLOUDFLARE 만 영어 장면 한 줄로 그린다")
  void usesEnglishScene() {
    assertThat(ImageProvider.FLUX.usesEnglishScene()).isTrue();
    assertThat(ImageProvider.CLOUDFLARE.usesEnglishScene()).isTrue();
    assertThat(ImageProvider.GEMINI.usesEnglishScene()).isFalse();
    assertThat(ImageProvider.OPENAI.usesEnglishScene()).isFalse();
  }
}
