package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.io.IOException;
import java.lang.reflect.Method;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.web.bind.annotation.PostMapping;

/**
 * 관리자 회원 화면의 탈퇴 계정 표시와 즉시 완전 삭제 버튼 (이슈 #372 S6·S9).
 *
 * <p>템플릿을 글로 훑는다. 화면을 띄우지 않으므로 보이는 모양까지는 못 보지만, 버튼이 확인 창 없이
 * 바로 지우거나 탈퇴하지 않은 계정에도 보이는 실수는 잡는다.
 */
class AdminWithdrawnMemberViewTest {

  private static final Path TEMPLATES = Path.of("src/main/resources/templates/admin");

  @Test
  @DisplayName("S6 회원 목록에 탈퇴 필터가 있고, 탈퇴 계정에는 보관 만료 예정일을 보인다")
  void memberList_hasWithdrawnFilterAndExpiry() throws IOException {
    String list = Files.readString(TEMPLATES.resolve("members.html"));

    assertThat(list).contains("<option value=\"WITHDRAWN\"");
    assertThat(list).contains("retentionExpiresAt()");
  }

  @Test
  @DisplayName("S9 즉시 완전 삭제 버튼은 탈퇴 계정에만 보이고, 확인 창을 거친다")
  void purgeButton_onlyForWithdrawn_withConfirm() throws IOException {
    String detail = Files.readString(TEMPLATES.resolve("member-detail.html"));
    Matcher form = Pattern.compile("<form[^>]*/purge[^>]*>", Pattern.DOTALL).matcher(detail);

    assertThat(form.find()).as("완전 삭제 폼이 없다").isTrue();
    String tag = form.group();
    // 되돌릴 수 없는 삭제다. 잘못 누른 한 번으로 지워지면 안 된다.
    assertThat(tag).contains("confirm(");
    // 쓰는 중인 계정에 보이면 먼저 탈퇴하지 않은 계정을 지우려 들게 된다 (서버도 막는다).
    assertThat(tag).contains("'WITHDRAWN'");
    assertThat(tag).contains("method=\"post\"");
  }

  /**
   * 운영 E2E D3 — 관리자 문구가 방침 4조와 다른 말을 했다. "소셜 식별값과 AI 기록만 남는다",
   * "같은 소셜 계정으로 오면 되살아난다" 였지만 실제로는 비밀번호 변환값·약관 동의 기록도 남고
   * 아이디 계정도 같은 아이디로 로그인하면 되살아난다. 관리자가 정보주체 문의에 이 문구로 답하게 된다.
   */
  @Test
  @DisplayName("D3 탈퇴 카드·완전 삭제 확인 창이 방침 4조의 보관 항목 넷과 아이디 계정 복원을 말한다")
  void withdrawnCard_matchesPrivacyPolicyRetention() throws IOException {
    String detail = Files.readString(TEMPLATES.resolve("member-detail.html"));
    Matcher card = Pattern.compile("<!-- 탈퇴 계정 \\(이슈 #372\\).*?</form>", Pattern.DOTALL).matcher(detail);
    assertThat(card.find()).as("탈퇴 카드가 없다").isTrue();
    String text = card.group();

    // 방침 4조 [탈퇴 후 1년간 보관하는 정보] 의 네 항목
    assertThat(text)
      .contains("계정 식별값")
      .contains("AI 이용 기록")
      .contains("비밀번호 변환값")
      .contains("약관 동의 기록");
    // 소셜 계정만 되살아나는 것처럼 말하지 않는다
    assertThat(text).contains("같은 아이디와 비밀번호로");
    assertThat(text).contains("약관 동의는 다시 받아요");
    assertThat(text).doesNotContain("소셜 로그인 식별값과 AI 이용 기록만");
    assertThat(text).doesNotContain("남아 있는 소셜 로그인 식별값을 지우고");
  }

  @Test
  @DisplayName("D3 보관 일수 설정 설명이 보관 항목 넷과 아이디 계정 복원을 말한다")
  void retentionConfigDescription_matchesPrivacyPolicyRetention() {
    String description = ConfigKey.MEMBER_WITHDRAWN_RETENTION_DAYS.getDescription();

    assertThat(description)
      .contains("계정 식별값")
      .contains("AI 이용 기록")
      .contains("비밀번호 변환값")
      .contains("약관 동의 기록")
      .contains("같은 아이디");
    // 방침과 묶여 있다는 경고는 그대로 둔다
    assertThat(description).contains("개인정보처리방침 4조");
  }

  @Test
  @DisplayName("S9 즉시 완전 삭제는 POST 로만 받는다")
  void purgeEndpoint_isPost() throws NoSuchMethodException {
    Method purge = null;
    for (Method method : AdminMemberController.class.getMethods()) {
      if (method.getName().equals("purge")) {
        purge = method;
      }
    }

    assertThat(purge).as("AdminMemberController#purge 가 없다").isNotNull();
    PostMapping mapping = purge.getAnnotation(PostMapping.class);
    assertThat(mapping).isNotNull();
    assertThat(mapping.value()).containsExactly("/admin/members/{id}/purge");
  }
}
