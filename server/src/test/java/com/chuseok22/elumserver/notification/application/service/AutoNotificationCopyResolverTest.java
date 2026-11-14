package com.chuseok22.elumserver.notification.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.notification.application.service.AutoNotificationCopyResolver.RenderedCopy;
import com.chuseok22.elumserver.notification.core.AdminMessageRoute;
import com.chuseok22.elumserver.notification.core.AutoNotificationType;
import com.chuseok22.elumserver.notification.infrastructure.entity.AutoNotificationRule;
import com.chuseok22.elumserver.notification.infrastructure.entity.PushDevice;
import com.chuseok22.elumserver.notification.infrastructure.repository.PushDeviceRepository;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 자동 알림이 영어·일본어로 쓰는 보호자에게 한국어로 가거나, 관리자가 고친 한국어 문구가 무시되면 안 된다 (#1409)
class AutoNotificationCopyResolverTest {

  private final PushDeviceRepository pushDeviceRepository = mock(PushDeviceRepository.class);
  private final AutoNotificationCopyResolver resolver = new AutoNotificationCopyResolver(pushDeviceRepository);

  @Test
  @DisplayName("ko 는 관리자가 고친 규칙 틀 그대로, 값이 없으면 '이룸이'")
  void korean_usesRuleTemplate() {
    RenderedCopy copy = resolver.render(rule(AutoNotificationType.LINK_PENDING, "관리자 제목 {아이이름}", "관리자 본문"),
      new AutoNotificationCandidate("m", null, null, null), AppLocale.KO);

    assertThat(copy).isEqualTo(new RenderedCopy("관리자 제목 이룸이", "관리자 본문"));
  }

  @Test
  @DisplayName("en 은 문구 파일 기본 문구 + 이름 값, 이름이 없으면 Elumi (child 라고 부르지 않음)")
  void english_usesBundleCopyWithElumiDefault() {
    AutoNotificationRule rule = rule(AutoNotificationType.LINK_PENDING, "관리자 제목", "관리자 본문");

    RenderedCopy named = resolver.render(rule, new AutoNotificationCandidate("m", "Sky", null, null), AppLocale.EN);
    RenderedCopy unnamed = resolver.render(rule, new AutoNotificationCandidate("m", null, null, null), AppLocale.EN);

    assertThat(named.title()).isEqualTo("📱 Link Sky's device?");
    assertThat(unnamed.title()).contains("Elumi").doesNotContainIgnoringCase("child");
    assertThat(unnamed.body()).doesNotContain("관리자");
  }

  @Test
  @DisplayName("{날짜} 는 받는 사람 언어 형식으로 (ko 2월 12일, en Feb 12, ja 2月12日)")
  void date_isFormattedPerLocale() {
    AutoNotificationRule rule = rule(AutoNotificationType.PRO_GIFT_ENDING, "Pro 선물이 {날짜}에 끝나요", "본문");
    AutoNotificationCandidate candidate = new AutoNotificationCandidate("m", null, null, LocalDate.of(2027, 2, 12));

    assertThat(resolver.render(rule, candidate, AppLocale.KO).title()).isEqualTo("Pro 선물이 2월 12일에 끝나요");
    assertThat(resolver.render(rule, candidate, AppLocale.EN).title()).contains("Feb 12");
    assertThat(resolver.render(rule, candidate, AppLocale.JA).title()).contains("2月12日");
  }

  @Test
  @DisplayName("언어는 가장 최근 등록한 보호자 기기 기준, 기기가 없으면 ko")
  void locale_followsLatestGuardianDevice() {
    when(pushDeviceRepository.findAllByMemberIdInAndLinkIdIsNull(anyCollection())).thenReturn(List.of(
      device("m-1", AppLocale.KO, LocalDateTime.of(2026, 11, 1, 9, 0)),
      device("m-1", AppLocale.JA, LocalDateTime.of(2026, 11, 10, 9, 0))));

    Map<String, AppLocale> locales = resolver.localesOf(List.of("m-1", "m-no-device"));

    assertThat(locales).containsEntry("m-1", AppLocale.JA).containsEntry("m-no-device", AppLocale.KO);
  }

  @Test
  @DisplayName("관리자 미리 보기는 ko 를 뺀 네 언어 모두")
  void preview_coversFourOtherLocales() {
    Map<AppLocale, RenderedCopy> previews = resolver.previewOtherLocales(
      rule(AutoNotificationType.STREAK_AT_RISK, "제목", "본문"), LocalDate.of(2026, 11, 14));

    assertThat(previews).containsOnlyKeys(AppLocale.EN, AppLocale.JA, AppLocale.ZH, AppLocale.ES);
    assertThat(previews.values()).allSatisfy(copy -> assertThat(copy.title()).isNotBlank().doesNotContain("{"));
  }

  private static AutoNotificationRule rule(AutoNotificationType type, String title, String body) {
    AutoNotificationRule rule = new AutoNotificationRule();
    rule.setType(type);
    rule.setTitleTemplate(title);
    rule.setBodyTemplate(body);
    rule.setRoute(AdminMessageRoute.HOME);
    return rule;
  }

  private static PushDevice device(String memberId, AppLocale locale, LocalDateTime registeredAt) {
    PushDevice device = new PushDevice();
    device.setMemberId(memberId);
    device.setLocale(locale);
    device.setLastRegisteredAt(registeredAt);
    return device;
  }
}
