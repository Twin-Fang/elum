package com.chuseok22.elumserver.link.application.service;

import com.chuseok22.elumserver.common.infrastructure.jwt.LinkAccessValidator;
import com.chuseok22.elumserver.link.infrastructure.repository.DeviceLinkRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
@RequiredArgsConstructor
public class LinkAccessGuard implements LinkAccessValidator {

  private final DeviceLinkRepository deviceLinkRepository;

  /**
   * 이룸이 휴대폰 요청마다 한 번 도는 조회다. 기본키 조회라 인덱스를 그대로 타며,
   * 보호자 요청에는 걸리지 않는다.
   */
  @Override
  @Transactional(readOnly = true)
  public boolean isLinkActive(String linkId) {
    if (linkId == null || linkId.isBlank()) {
      // linkId 없는 이룸이 토큰은 끊을 방법이 없다. 통과시키면 영원히 못 끊는 세션이 남는다.
      return false;
    }
    return deviceLinkRepository.findById(linkId)
      .map(l -> l.getRevokedAt() == null && l.getRedeemedAt() != null)
      .orElse(false);
  }
}
