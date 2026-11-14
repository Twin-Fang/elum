package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

import com.chuseok22.elumserver.admin.application.dto.response.AdminLocaleBundleStatus;
import com.chuseok22.elumserver.admin.application.dto.response.AdminPushMessageCompareRow;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.ClasspathLocaleBundle;
import com.chuseok22.elumserver.consent.application.service.ConsentDocumentService;
import com.chuseok22.elumserver.notice.application.service.NoticeService;
import com.chuseok22.elumserver.systemconfig.application.service.EnabledLocales;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 언어 현황 빈 키 셈: 깨지면 관리자가 번역이 빠진 언어를 다 됐다고 보고 켬
 */
class AdminLocaleStatusServiceTest {

  private static final Map<String, String> KO_PUSH = Map.of("push.title", "이룸", "push.a", "가", "push.b", "나");

  private AdminLocaleStatusService serviceWith(Map<String, String> enPush) {
    return new AdminLocaleStatusService(mock(AdminPromptService.class), mock(ConsentDocumentService.class),
      mock(NoticeService.class), mock(EnabledLocales.class),
      (resource, locale) -> locale == AppLocale.KO ? KO_PUSH : enPush);
  }

  @Test
  @DisplayName("ko 에 있는데 없거나 공백인 키는 빈 키로 세고, ko 에 없는 여분 키는 빈 키로 세지 않는다")
  void countsMissingAndBlankKeysAgainstKo() {
    AdminLocaleBundleStatus status = serviceWith(Map.of("push.title", "ELUM", "push.a", "  ", "push.extra", "x"))
      .compareBundle(AdminLocaleStatusService.PUSH_MESSAGES_RESOURCE, AppLocale.EN);

    assertThat(status.missingKeys()).containsExactly("push.a", "push.b");
    assertThat(status.keyCount()).isEqualTo(2);
    assertThat(status.isComplete()).isFalse();
  }

  @Test
  @DisplayName("파일이 통째로 없으면 ko 키 전부가 빈 키다 (빈 파일을 완성으로 오해하지 않음)")
  void missingFileMeansAllKoKeysMissing() {
    AdminLocaleBundleStatus status = serviceWith(Map.of())
      .compareBundle(AdminLocaleStatusService.PUSH_MESSAGES_RESOURCE, AppLocale.JA);

    assertThat(status.missingCount()).isEqualTo(KO_PUSH.size());
    assertThat(status.keyCount()).isZero();
  }

  @Test
  @DisplayName("푸시 문구 보기는 ko 키 순서로 ko·고른 언어 문구를 나란히 두고 빠진 줄을 표시한다")
  void pushCompareRowsFollowKoKeys() {
    List<AdminPushMessageCompareRow> rows = serviceWith(Map.of("push.title", "ELUM", "push.a", "A"))
      .getPushMessageCompareRows(AppLocale.EN);

    assertThat(rows).extracting(AdminPushMessageCompareRow::key).containsExactly("push.a", "push.b", "push.title");
    assertThat(rows.get(1).isMissing()).isTrue();
    assertThat(rows.get(2).selectedText()).isEqualTo("ELUM");
  }

  @Test
  @DisplayName("실제 푸시 문구 파일: 5개 언어 모두 ko 키를 빠짐없이 채운다")
  void realPushMessageFilesAreComplete() {
    AdminLocaleStatusService service = new AdminLocaleStatusService(mock(AdminPromptService.class),
      mock(ConsentDocumentService.class), mock(NoticeService.class), mock(EnabledLocales.class),
      ClasspathLocaleBundle::load);

    for (AppLocale locale : AppLocale.values()) {
      assertThat(service.compareBundle(AdminLocaleStatusService.PUSH_MESSAGES_RESOURCE, locale).missingKeys())
        .as(locale.code()).isEmpty();
    }
  }
}
