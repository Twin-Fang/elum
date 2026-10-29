package com.chuseok22.elumserver.consent.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.consent.application.service.ConsentDocumentService.PublishedConsents;
import com.chuseok22.elumserver.consent.core.ConsentKey;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;
import com.chuseok22.elumserver.consent.infrastructure.repository.ConsentDocumentHistoryRepository;
import com.chuseok22.elumserver.consent.infrastructure.repository.ConsentDocumentRepository;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

/**
 * 약관 언어 판정 (#531): 요청 언어 게시본 > 없으면 ko 대체(en 대체 없음) + 대체 표시
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ConsentDocumentLocaleTest {

  @Mock
  private ConsentDocumentRepository documentRepository;
  @Mock
  private ConsentDocumentHistoryRepository historyRepository;

  private ConsentDocumentService service;

  @BeforeEach
  void setUp() {
    service = new ConsentDocumentService(documentRepository, historyRepository);
    // 기본: 어떤 언어도 없음, ko 만 5종 전부
    when(documentRepository.findAllByLocale(anyString())).thenReturn(List.of());
    when(documentRepository.findAllByLocale("ko")).thenReturn(allDocuments("ko"));
  }

  @Test
  @DisplayName("헤더 없는 옛 앱(ko) — ko 약관을 대체 표시 없이 받는다")
  void koRequest_servesKoWithoutFallback() {
    PublishedConsents published = service.getPublished(AppLocale.KO);

    assertThat(published.locale()).isEqualTo(AppLocale.KO);
    assertThat(published.isFallbackLocale()).isFalse();
    assertThat(published.documents()).hasSize(ConsentKey.values().length);
  }

  @Test
  @DisplayName("en 약관이 없으면 ko 로 대체하고 대체했다고 표시한다 — 빈 약관이나 표시 없는 한국어가 아니게")
  void unpublishedLocale_fallsBackToKoWithFlag() {
    PublishedConsents published = service.getPublished(AppLocale.EN);

    assertThat(published.locale()).isEqualTo(AppLocale.KO);
    assertThat(published.isFallbackLocale()).isTrue();
    assertThat(published.documents()).extracting(ConsentDocument::getLocale).containsOnly("ko");
  }

  @Test
  @DisplayName("en 에 필수 4종 중 일부만 있으면 게시가 아니다 — 필수가 빠진 동의 화면을 띄우지 않는다")
  void incompleteLocale_isNotPublished() {
    when(documentRepository.findAllByLocale("en"))
      .thenReturn(List.of(document(ConsentKey.TERMS, "en"), document(ConsentKey.PRIVACY, "en")));

    assertThat(service.resolvePublishedLocale(AppLocale.EN)).isEqualTo(AppLocale.KO);
  }

  @Test
  @DisplayName("ja 가 없으면 en 게시본이 있어도 en 이 아니라 ko 로 대체한다 — 확인 안 된 번역으로 동의받지 않는다")
  void missingLocale_neverFallsBackToEnglish() {
    when(documentRepository.findAllByLocale("en")).thenReturn(allDocuments("en"));

    assertThat(service.resolvePublishedLocale(AppLocale.JA)).isEqualTo(AppLocale.KO);
    assertThat(service.resolvePublishedLocale(AppLocale.EN)).isEqualTo(AppLocale.EN);
  }

  private List<ConsentDocument> allDocuments(String locale) {
    return Arrays.stream(ConsentKey.values()).map(key -> document(key, locale)).toList();
  }

  private static ConsentDocument document(ConsentKey key, String locale) {
    ConsentDocument document = new ConsentDocument();
    document.setConsentKey(key);
    document.setLocale(locale);
    document.setVersion("2026-09-21");
    document.setLabel(key.getLabel());
    document.setSummary(key.getSummary());
    document.setBody("본문");
    document.setRequired(key.isRequired());
    document.setPublishedAt(LocalDateTime.now());
    return document;
  }
}
