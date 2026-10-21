package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.dto.response.AdminDeviceLinkLine;
import com.chuseok22.elumserver.admin.application.dto.response.AdminDeviceLinkStatus;
import com.chuseok22.elumserver.admin.application.dto.response.AdminInviteStatus;
import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberConnections;
import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberDetailResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberProfileCard;
import com.chuseok22.elumserver.admin.application.dto.response.AdminProfileGuardianLine;
import com.chuseok22.elumserver.admin.application.dto.response.AdminProfileInviteLine;
import com.chuseok22.elumserver.admin.application.dto.response.AdminPushDeviceLine;
import com.chuseok22.elumserver.admin.application.dto.response.AdminSubscriptionSummary;
import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.member.infrastructure.entity.GuardianKind;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.notification.core.PushPlatform;
import com.chuseok22.elumserver.notification.infrastructure.entity.PushDevice;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.context.support.GenericApplicationContext;
import org.thymeleaf.context.Context;
import org.thymeleaf.context.IExpressionContext;
import org.thymeleaf.linkbuilder.StandardLinkBuilder;
import org.thymeleaf.spring6.SpringTemplateEngine;
import org.thymeleaf.spring6.expression.ThymeleafEvaluationContext;
import org.thymeleaf.templatemode.TemplateMode;
import org.thymeleaf.templateresolver.ClassLoaderTemplateResolver;

/**
 * 회원 상세의 이룸이·연결 영역 렌더링 (#908)
 * 깨지면 회원 상세 전체가 500 이 되거나, 푸시 토큰 원문이 관리자 화면에 노출된다
 */
class AdminMemberConnectionsRenderTest {

  private static final LocalDateTime AT = LocalDateTime.of(2026, 10, 21, 9, 0);

  private SpringTemplateEngine engine;
  private GenericApplicationContext applicationContext;

  @BeforeEach
  void setUp() {
    ClassLoaderTemplateResolver resolver = new ClassLoaderTemplateResolver();
    resolver.setPrefix("templates/");
    resolver.setSuffix(".html");
    resolver.setTemplateMode(TemplateMode.HTML);
    resolver.setCharacterEncoding("UTF-8");
    engine = new SpringTemplateEngine();
    engine.setTemplateResolver(resolver);
    engine.setLinkBuilder(new StandardLinkBuilder() {
      @Override
      protected String computeContextPath(IExpressionContext context, String base, Map<String, Object> parameters) {
        return "";
      }
    });
    // ${@adminDate...} 를 풀 빈 컨텍스트
    applicationContext = new GenericApplicationContext();
    applicationContext.registerBean("adminDate", AdminDateFormatter.class);
    applicationContext.refresh();
  }

  private String renderDetail(AdminMemberConnections connections) {
    Member member = new Member();
    member.setId("m1");
    member.setUsername("parent1");
    member.setStatus(MemberStatus.ACTIVE);
    AdminMemberDetailResponse detail = AdminMemberDetailResponse.of(member, null, List.of(), null, List.of(),
      AdminSubscriptionSummary.none(), List.of(), null).withConnections(connections);
    Context context = new Context();
    context.setVariables(Map.of("member", detail));
    context.setVariable(ThymeleafEvaluationContext.THYMELEAF_EVALUATION_CONTEXT_CONTEXT_VARIABLE_NAME,
      new ThymeleafEvaluationContext(applicationContext, null));
    return engine.process("admin/member-detail", context);
  }

  private AdminMemberConnections connectionsWithOneProfile() {
    AdminMemberProfileCard profile = new AdminMemberProfileCard(
      "p1", "하늘", null, 3, Set.of(), AT,
      List.of(
        new AdminProfileGuardianLine("m1", "parent1", "엄마", GuardianKind.GUARDIAN, AT, MemberStatus.ACTIVE, true),
        new AdminProfileGuardianLine("m2", "kakao_2", null, GuardianKind.CAREGIVER, AT, MemberStatus.SUSPENDED, false)),
      List.of(new AdminProfileInviteLine("i1", AdminInviteStatus.BLOCKED, "m1", "엄마", AT, AT.plusMinutes(10),
        null, null, null, AT.plusMinutes(3), 5)),
      12,
      List.of(
        new AdminDeviceLinkLine("l1", AdminDeviceLinkStatus.LINKED, "m1", "엄마", "iPad", AT, AT.plusMinutes(10),
          AT.plusMinutes(2), null, 0, AT.plusDays(1)),
        new AdminDeviceLinkLine("l2", AdminDeviceLinkStatus.UNLINKED, "x9", null, null, AT, AT.plusMinutes(10),
          AT.plusMinutes(2), AT.plusDays(2), 0, null)),
      0);
    PushDevice pushDevice = new PushDevice();
    pushDevice.setPlatform(PushPlatform.IOS);
    pushDevice.setToken("abcdefSECRETTOKENTAIL");
    pushDevice.setLastRegisteredAt(AT.minusDays(40));
    return new AdminMemberConnections(List.of(profile), List.of(AdminPushDeviceLine.of(pushDevice, AT)), false);
  }

  @Test
  @DisplayName("이룸이 카드: 보호자 링크·막힌 코드 강조·연결된 기기만 끊기 폼·토큰 앞 6자만·알림/광고 보상 링크")
  void rendersProfileCardsAndMasksToken() {
    String html = renderDetail(connectionsWithOneProfile());

    assertThat(html).contains("data-profile-card").contains("하늘").contains("기본");
    // 공동 보호자: 그 보호자 회원 상세로 가는 링크, 이름 없으면 아이디가 보인다
    assertThat(html).contains("href=\"/admin/members/m2\"").contains("kakao_2").contains("기관 지도자");
    // 시도 초과로 막힌 초대 코드는 카드 머리글에서 먼저 보인다
    assertThat(html).contains("data-blocked-code-badge").contains("시도 초과로 막힘");
    assertThat(html).contains("이전 12건은 생략했어요");
    // 지금 연결된 기기에만 끊기 폼 (끊긴 기록에는 없음)
    assertThat(html).contains("action=\"/admin/members/m1/device-links/l1/unlink\"")
      .doesNotContain("/device-links/l2/unlink");
    assertThat(html).contains("나간 보호자");
    // 푸시 토큰은 앞 6자만
    assertThat(html).contains("abcdef…").doesNotContain("SECRETTOKEN");
    assertThat(html).contains("30일 넘게 갱신 없음");
    assertThat(html).contains("href=\"/admin/notifications?memberId=m1\"")
      .contains("href=\"/admin/ad-rewards?memberId=m1\"");
  }

  @Test
  @DisplayName("연결 정보 조회 실패: 회원 상세는 그려지고 그 영역에 오류 코드가 보인다")
  void rendersLoadFailure() {
    String html = renderDetail(AdminMemberConnections.failed());

    assertThat(html).contains("data-connections-load-failed").contains(AdminMemberConnections.LOAD_FAILED_ERROR_CODE)
      .contains("parent1").doesNotContain("data-push-devices");
  }
}
