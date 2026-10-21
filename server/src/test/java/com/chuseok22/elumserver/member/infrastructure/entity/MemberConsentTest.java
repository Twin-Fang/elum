package com.chuseok22.elumserver.member.infrastructure.entity;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDateTime;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class MemberConsentTest {

  @Test
  @DisplayName("동의 초기화는 이야기 이용 규칙 동의 시각도 비운다 (되살린 계정이 옛 동의로 글을 쓰지 못함)")
  void clearConsents_alsoClearsTalkRulesAgreement() {
    Member member = new Member();
    member.setTermsAgreed(true);
    member.setConsentedAt(LocalDateTime.of(2026, 10, 1, 9, 0));
    member.setTalkRulesAgreedAt(LocalDateTime.of(2026, 10, 20, 9, 0));

    member.clearConsents();

    assertThat(member.getTermsAgreed()).isFalse();
    assertThat(member.getConsentedAt()).isNull();
    assertThat(member.getTalkRulesAgreedAt()).isNull();
  }
}
