package com.chuseok22.elumserver.consent.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.consent.application.service.ConsentDocumentService.UpdateResult;
import com.chuseok22.elumserver.consent.core.ConsentKey;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocumentHistory;
import com.chuseok22.elumserver.consent.infrastructure.repository.ConsentDocumentHistoryRepository;
import com.chuseok22.elumserver.consent.infrastructure.repository.ConsentDocumentRepository;
import java.time.LocalDateTime;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

/**
 * 번역본 저장 (#1379): 없으면 ko 원본 버전으로 새로 만들기, 있으면 ko 와 같은 규칙(이력·사유·공백·CRLF)
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ConsentDocumentTranslationUpdateTest {

  private static final String KO_VERSION = "2026-10-01";

  @Mock
  private ConsentDocumentRepository documentRepository;
  @Mock
  private ConsentDocumentHistoryRepository historyRepository;

  private ConsentDocumentService service;
  private ConsentDocument koTerms;

  @BeforeEach
  void setUp() {
    service = new ConsentDocumentService(documentRepository, historyRepository);
    koTerms = document(ConsentKey.TERMS, "ko", KO_VERSION, "본문");
    when(documentRepository.findByConsentKeyAndLocale(ConsentKey.TERMS, "ko")).thenReturn(Optional.of(koTerms));
    when(documentRepository.findByConsentKeyAndLocale(ConsentKey.TERMS, "en")).thenReturn(Optional.empty());
  }

  private ConsentDocument document(ConsentKey key, String locale, String version, String body) {
    ConsentDocument document = new ConsentDocument();
    document.setConsentKey(key);
    document.setLocale(locale);
    document.setVersion(version);
    document.setLabel(key.getLabel());
    document.setSummary(key.getSummary());
    document.setBody(body);
    document.setRequired(key.isRequired());
    document.setPublishedAt(LocalDateTime.of(2026, 10, 1, 0, 0));
    return document;
  }

  @Test
  @DisplayName("없는 번역본은 ko 원본 버전으로 새로 만든다 — 어느 ko 문구를 옮겼는지 버전이 어긋나지 않게")
  void missingTranslation_createdWithKoVersion() {
    UpdateResult result = service.update(ConsentKey.TERMS, AppLocale.EN,
      " Terms of Service ", "How you use ELUM", "Line 1\r\nLine 2\r\n", true, "2099-01-01", "admin", "번역 게시");

    assertThat(result).isEqualTo(UpdateResult.CREATED);
    ArgumentCaptor<ConsentDocument> saved = ArgumentCaptor.forClass(ConsentDocument.class);
    verify(documentRepository).save(saved.capture());
    ConsentDocument created = saved.getValue();
    assertThat(created.getLocale()).isEqualTo("en");
    assertThat(created.getConsentKey()).isEqualTo(ConsentKey.TERMS);
    // bumpVersion 을 보내도 새 행은 ko 원본 버전 그대로
    assertThat(created.getVersion()).isEqualTo(KO_VERSION);
    assertThat(created.getLabel()).isEqualTo("Terms of Service");
    assertThat(created.getBody()).isEqualTo("Line 1\nLine 2");
    assertThat(created.isRequired()).isTrue();
    assertThat(created.getPublishedAt()).isNotNull();
    // 직전 내용이 없으므로 이력 없음, ko 원본은 그대로
    verify(historyRepository, never()).save(any());
    assertThat(koTerms.getBody()).isEqualTo("본문");
  }

  @Test
  @DisplayName("선택 항목 번역본은 선택으로 만든다 — 소식 받기를 필수로 받으면 위법")
  void missingMarketingTranslation_createdAsOptional() {
    when(documentRepository.findByConsentKeyAndLocale(ConsentKey.MARKETING, "ja")).thenReturn(Optional.empty());
    when(documentRepository.findByConsentKeyAndLocale(ConsentKey.MARKETING, "ko"))
      .thenReturn(Optional.of(document(ConsentKey.MARKETING, "ko", "2026-09-21", "본문")));

    service.update(ConsentKey.MARKETING, AppLocale.JA, "お知らせ", "要約", "本文", false, null, "admin", "번역 게시");

    ArgumentCaptor<ConsentDocument> saved = ArgumentCaptor.forClass(ConsentDocument.class);
    verify(documentRepository).save(saved.capture());
    assertThat(saved.getValue().isRequired()).isFalse();
    assertThat(saved.getValue().getVersion()).isEqualTo("2026-09-21");
  }

  @Test
  @DisplayName("ko 원본이 없으면 번역본을 만들지 않는다 — 기준 버전 없는 번역이 생기지 않게")
  void missingKoSource_rejected() {
    when(documentRepository.findByConsentKeyAndLocale(ConsentKey.TERMS, "ko")).thenReturn(Optional.empty());

    assertThatThrownBy(() -> service.update(ConsentKey.TERMS, AppLocale.EN,
      "Terms", "Summary", "Body", false, null, "admin", "번역 게시"))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.CONSENT_DOCUMENT_NOT_FOUND);
    verify(documentRepository, never()).save(any());
  }

  @Test
  @DisplayName("있는 번역본은 이력을 먼저 남기고 그 행만 고친다 — ko 원본은 건드리지 않는다")
  void existingTranslation_updatedWithHistory() {
    ConsentDocument enTerms = document(ConsentKey.TERMS, "en", KO_VERSION, "Old body");
    when(documentRepository.findByConsentKeyAndLocale(ConsentKey.TERMS, "en")).thenReturn(Optional.of(enTerms));

    UpdateResult result = service.update(ConsentKey.TERMS, AppLocale.EN,
      "Terms of Service", "Summary", "New body\r\n", false, null, "admin", "오역 정정");

    assertThat(result).isEqualTo(UpdateResult.SAVED);
    ArgumentCaptor<ConsentDocumentHistory> history = ArgumentCaptor.forClass(ConsentDocumentHistory.class);
    verify(historyRepository).save(history.capture());
    assertThat(history.getValue().getLocale()).isEqualTo("en");
    assertThat(history.getValue().getBody()).isEqualTo("Old body");
    assertThat(history.getValue().getReason()).isEqualTo("오역 정정");
    assertThat(enTerms.getBody()).isEqualTo("New body");
    assertThat(enTerms.getVersion()).isEqualTo(KO_VERSION);
    assertThat(koTerms.getBody()).isEqualTo("본문");
    verify(documentRepository, never()).save(any());
  }

  @Test
  @DisplayName("있는 번역본도 버전을 올릴 수 있다 — ko 와 같은 검증")
  void existingTranslation_bumped() {
    ConsentDocument enTerms = document(ConsentKey.TERMS, "en", KO_VERSION, "Body");
    when(documentRepository.findByConsentKeyAndLocale(ConsentKey.TERMS, "en")).thenReturn(Optional.of(enTerms));

    UpdateResult result = service.update(ConsentKey.TERMS, AppLocale.EN,
      enTerms.getLabel(), enTerms.getSummary(), "Body", true, "2026-11-14", "admin", "ko 개정 반영");

    assertThat(result).isEqualTo(UpdateResult.SAVED_AND_BUMPED);
    assertThat(enTerms.getVersion()).isEqualTo("2026-11-14");
  }

  @Test
  @DisplayName("번역본도 수정 사유가 없으면 받지 않는다 — 새로 만들 때도")
  void translation_reasonRequired() {
    assertThatThrownBy(() -> service.update(ConsentKey.TERMS, AppLocale.EN,
      "Terms", "Summary", "Body", false, null, "admin", "  "))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.CONSENT_REASON_REQUIRED);
    verify(documentRepository, never()).save(any());
  }

  @Test
  @DisplayName("번역본도 공백만 있는 전문은 받지 않는다 — 빈 약관 행이 생기지 않게")
  void translation_blankBodyRejected() {
    assertThatThrownBy(() -> service.update(ConsentKey.TERMS, AppLocale.EN,
      "Terms", "Summary", " \r\n ", false, null, "admin", "번역 게시"))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.CONSENT_FIELD_BLANK);
    verify(documentRepository, never()).save(any());
  }

  @Test
  @DisplayName("ko 저장은 언어 없는 기존 호출과 같다 — ko 행만 고치고 새 행을 만들지 않는다")
  void koUpdate_unchangedBehavior() {
    UpdateResult result = service.update(ConsentKey.TERMS, koTerms.getLabel(), koTerms.getSummary(),
      "새 본문", false, null, "admin", "문구 정정");

    assertThat(result).isEqualTo(UpdateResult.SAVED);
    assertThat(koTerms.getBody()).isEqualTo("새 본문");
    assertThat(koTerms.getVersion()).isEqualTo(KO_VERSION);
    verify(historyRepository).save(any());
    verify(documentRepository, never()).save(any());
  }

  @Test
  @DisplayName("ko 행이 없으면 ko 는 새로 만들지 않는다 — ko 는 기동 시딩 대상")
  void koMissing_notCreated() {
    when(documentRepository.findByConsentKeyAndLocale(ConsentKey.TERMS, "ko")).thenReturn(Optional.empty());

    assertThatThrownBy(() -> service.update(ConsentKey.TERMS, AppLocale.KO,
      "이용약관", "요약", "본문", false, null, "admin", "사유"))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.CONSENT_DOCUMENT_NOT_FOUND);
    verify(documentRepository, never()).save(any());
  }
}
