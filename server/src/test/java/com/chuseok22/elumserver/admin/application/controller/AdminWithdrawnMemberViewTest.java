package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

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
