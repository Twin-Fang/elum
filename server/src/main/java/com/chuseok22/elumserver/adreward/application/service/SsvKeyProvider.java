package com.chuseok22.elumserver.adreward.application.service;

import java.security.PublicKey;
import java.util.Optional;

/// Google AdMob 보상 검증용 공개키를 `key_id` 로 찾아 준다 (#463).
public interface SsvKeyProvider {

  /**
   * @return 그 `key_id` 의 공개키. Google 이 모르는 id 면 빈 값
   * @throws SsvKeysUnavailableException 키 목록을 받지 못해 있는지 없는지도 모를 때
   */
  Optional<PublicKey> find(String keyId);
}
