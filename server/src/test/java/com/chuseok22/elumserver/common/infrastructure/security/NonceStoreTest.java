package com.chuseok22.elumserver.common.infrastructure.security;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class NonceStoreTest {

  @Test
  void 처음_보는_nonce는_통과_재사용은_차단() {
    NonceStore store = new NonceStore();
    long now = 1_700_000_000_000L;

    assertThat(store.checkAndRemember("abc", now)).isTrue();   // 최초
    assertThat(store.checkAndRemember("abc", now)).isFalse();  // 재사용
    assertThat(store.checkAndRemember("def", now)).isTrue();   // 다른 값
  }

  @Test
  void TTL_지난_nonce는_다시_통과() {
    NonceStore store = new NonceStore();
    long t0 = 1_700_000_000_000L;

    assertThat(store.checkAndRemember("abc", t0)).isTrue();
    // 11분 뒤: 이전 항목이 만료되어 다시 통과해야 한다
    long later = t0 + 11 * 60 * 1000L;
    assertThat(store.checkAndRemember("abc", later)).isTrue();
  }
}
