package com.chuseok22.elumserver.member.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.CurrentLocale;
import com.chuseok22.elumserver.consent.application.service.ConsentDocumentService;
import com.chuseok22.elumserver.consent.core.ConsentKey;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;
import com.chuseok22.elumserver.consent.infrastructure.repository.ConsentDocumentHistoryRepository;
import com.chuseok22.elumserver.consent.infrastructure.repository.ConsentDocumentRepository;
import com.chuseok22.elumserver.member.application.dto.request.MemberConsentRequest;
import com.chuseok22.elumserver.member.application.dto.response.MemberConsentResponse;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * 동의 언어 기록 (#531): 사용자가 실제로 본 약관 언어로 남는가
 * 약관 언어 판정은 진짜 ConsentDocumentService (저장소만 가짜) — 가짜가 준 값을 되읽는 시험이 되지 않게
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class MemberServiceConsentLocaleTest {

  private static final String MEMBER_ID = "member-1";

  @Mock
  private MemberRepository memberRepository;
  @Mock
  private ConsentDocumentRepository consentDocumentRepository;
  @Mock
  private ConsentDocumentHistoryRepository consentDocumentHistoryRepository;

  @InjectMocks
  private MemberService memberService;

  private Member member;

  @BeforeEach
  void setUp() {
    ReflectionTestUtils.setField(memberService, "consentDocumentService",
      new ConsentDocumentService(consentDocumentRepository, consentDocumentHistoryRepository));
    // 게시본: ko 만 (지금 운영과 같음)
    when(consentDocumentRepository.findAllByLocale(anyString())).thenReturn(List.of());
    when(consentDocumentRepository.findAllByLocale("ko")).thenReturn(documents("ko"));
    member = new Member();
    member.setId(MEMBER_ID);
    member.setStatus(MemberStatus.ACTIVE);
    when(memberRepository.findById(MEMBER_ID)).thenReturn(Optional.of(member));
  }

  @Test
  @DisplayName("언어를 안 보내는 옛 앱(헤더 없음 = ko) — ko 로 기록하고 가입이 된다")
  void legacyRequest_recordsKo() {
    MemberConsentResponse response = memberService.agreeConsents(MEMBER_ID, request(null));

    assertThat(member.getConsentLocale()).isEqualTo("ko");
    assertThat(response.consentLocale()).isEqualTo("ko");
    assertThat(response.requiredCompleted()).isTrue();
  }

  @Test
  @DisplayName("en 을 보내도 en 약관이 없으면 ko 로 기록한다 — 본 적 없는 언어로 동의했다고 남기지 않는다")
  void unpublishedLocale_recordsServedKo() {
    memberService.agreeConsents(MEMBER_ID, request("en"));

    assertThat(member.getConsentLocale()).isEqualTo("ko");
  }

  @Test
  @DisplayName("본문 언어가 모르는 값이면 헤더 언어로 판정하고 가입은 막지 않는다")
  void unknownLocale_fallsBackToHeaderAndStillAgrees() {
    when(consentDocumentRepository.findAllByLocale("en")).thenReturn(documents("en"));

    MemberConsentResponse response = CurrentLocale.callAs(AppLocale.EN,
      () -> memberService.agreeConsents(MEMBER_ID, request("fr")));

    assertThat(member.getConsentLocale()).isEqualTo("en");
    assertThat(response.requiredCompleted()).isTrue();
  }

  @Test
  @DisplayName("탈퇴 계정을 되살릴 때 동의 언어도 비운다 — 새로 동의받지 않았는데 기록이 남지 않게")
  void clearConsents_clearsLocale() {
    memberService.agreeConsents(MEMBER_ID, request(null));

    member.clearConsents();

    assertThat(member.getConsentLocale()).isNull();
  }

  private static MemberConsentRequest request(String consentLocale) {
    return new MemberConsentRequest(true, true, true, true, false, "2026-09-21", consentLocale);
  }

  private static List<ConsentDocument> documents(String locale) {
    return Arrays.stream(ConsentKey.values()).map(key -> {
      ConsentDocument document = new ConsentDocument();
      document.setConsentKey(key);
      document.setLocale(locale);
      return document;
    }).toList();
  }
}
