package com.chuseok22.elumserver.member;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 탈퇴 계정 보관 기간과 개인정보처리방침이 같은 말을 하는지 (이슈 #372).
 *
 * <p>보관 기간은 설정값(MEMBER_WITHDRAWN_RETENTION_DAYS)이고 방침은 글이라 한쪽만 바뀌기 쉽다.
 * 어긋나면 방침에 없는 기간만큼 개인정보를 들고 있게 된다. 서버 원본 privacy.txt 는 첫 시딩에만 쓰이지만
 * 앱 번들에서 기계로 떠낸 것이라 번들·게시본과 같은 글이다.
 */
class WithdrawnRetentionMatchesPrivacyPolicyTest {

  private static String privacy() throws IOException {
    try (InputStream in = WithdrawnRetentionMatchesPrivacyPolicyTest.class
      .getResourceAsStream("/consent/privacy.txt")) {
      assertThat(in).as("consent/privacy.txt 가 클래스패스에 있다").isNotNull();
      return new String(in.readAllBytes(), StandardCharsets.UTF_8);
    }
  }

  @Test
  @DisplayName("보관 기간 기본값 365일과 방침의 '탈퇴일로부터 1년'이 같다")
  void defaultRetentionMatchesPolicy() throws IOException {
    assertThat(ConfigKey.MEMBER_WITHDRAWN_RETENTION_DAYS.getDefaultValue()).isEqualTo("365");
    // 하드랩된 원문이라 줄바꿈을 공백으로 펴서 본다.
    String flat = privacy().replaceAll("\\s+", " ");
    assertThat(flat).contains("탈퇴일로부터 1년간 보관한 뒤 파기합니다");
  }

  @Test
  @DisplayName("방침이 보관 항목·목적·다른 목적 이용 금지·복원·즉시 삭제를 모두 적는다")
  void policyStatesWhatIsKeptAndWhy() throws IOException {
    String flat = privacy().replaceAll("\\s+", " ");
    assertThat(flat)
      // 보관 항목 — 코드가 남기는 것과 같아야 한다 (소셜 신원 · 아이디 · AI 호출 기록의 회원 식별자)
      .contains("소셜 로그인 제공자와 그 회원 식별번호, 서비스 아이디")
      .contains("AI 기능 이용 기록(이용 일시·횟수)")
      // 목적
      .contains("무료 이용 한도를 탈퇴와 재가입으로 되풀이해 받는 부정 이용을 막기 위해")
      .contains("부정 이용 방지 외의 목적으로 이용하지 않습니다")
      // 재가입 시 빈 계정 복원
      .contains("이전 계정이 빈 상태로 복원되어")
      // 즉시 삭제 요구
      .contains("즉시 삭제를 요구하시면 지체 없이 파기합니다");
  }

  @Test
  @DisplayName("탈퇴 시 계정을 지체 없이 삭제한다는 옛 약속은 남아 있지 않다")
  void oldImmediateDeletionPromiseIsGone() throws IOException {
    String flat = privacy().replaceAll("\\s+", " ");
    // 소프트 딜리트는 계정 행을 남긴다. 이 문장이 남아 있으면 방침과 동작이 어긋난다.
    assertThat(flat).doesNotContain("계정·이룸이 정보·일과·로그인 토큰을 지체 없이 삭제합니다");
    assertThat(flat).doesNotContain("회원 탈퇴로 전체 삭제를 요청할 수 있습니다");
  }
}
