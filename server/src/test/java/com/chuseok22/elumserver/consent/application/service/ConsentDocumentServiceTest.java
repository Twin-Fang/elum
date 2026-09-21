package com.chuseok22.elumserver.consent.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.consent.application.service.ConsentDocumentService.UpdateResult;
import com.chuseok22.elumserver.consent.core.ConsentKey;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocumentHistory;
import com.chuseok22.elumserver.consent.infrastructure.repository.ConsentDocumentHistoryRepository;
import com.chuseok22.elumserver.consent.infrastructure.repository.ConsentDocumentRepository;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

/**
 * 약관 저장 검증 (이슈 #278 QA).
 *
 * <p>여기 사례는 전부 운영 배포본을 밟아 실제로 뚫렸던 입력이다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ConsentDocumentServiceTest {

  @Mock
  private ConsentDocumentRepository documentRepository;
  @Mock
  private ConsentDocumentHistoryRepository historyRepository;

  private ConsentDocumentService service;
  private ConsentDocument terms;

  @BeforeEach
  void setUp() {
    service = new ConsentDocumentService(documentRepository, historyRepository);
    terms = document(ConsentKey.TERMS, "2026-09-18");
    when(documentRepository.findByConsentKey(ConsentKey.TERMS)).thenReturn(Optional.of(terms));
  }

  private ConsentDocument document(ConsentKey key, String version) {
    ConsentDocument document = new ConsentDocument();
    document.setConsentKey(key);
    document.setVersion(version);
    document.setLabel(key.getLabel());
    document.setSummary(key.getSummary());
    document.setBody("본문");
    document.setRequired(key.isRequired());
    document.setPublishedAt(LocalDateTime.now());
    return document;
  }

  private UpdateResult save(String body, boolean bump, String version) {
    return service.update(ConsentKey.TERMS, terms.getLabel(), terms.getSummary(), body,
      bump, version, "admin", "사유");
  }

  @Test
  @DisplayName("공백만 있는 전문은 받지 않는다 — 앱이 서버 약관 전체를 버리게 된다")
  void blankBody_rejected() {
    assertThatThrownBy(() -> save("   ", false, null))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.CONSENT_FIELD_BLANK);
    verify(historyRepository, never()).save(any());
  }

  @Test
  @DisplayName("항목 이름·요약도 비울 수 없다")
  void blankLabelOrSummary_rejected() {
    assertThatThrownBy(() -> service.update(ConsentKey.TERMS, " ", "요약", "본문", false, null, "a", "r"))
      .extracting("errorCode").isEqualTo(ErrorCode.CONSENT_FIELD_BLANK);
    assertThatThrownBy(() -> service.update(ConsentKey.TERMS, "이름", "", "본문", false, null, "a", "r"))
      .extracting("errorCode").isEqualTo(ErrorCode.CONSENT_FIELD_BLANK);
  }

  @Test
  @DisplayName("255자를 넘는 이름은 저장 전에 막는다 — DB에서 터지면 500이 난다")
  void tooLongLabel_rejected() {
    String longLabel = "가".repeat(ConsentDocumentService.TEXT_FIELD_MAX_LENGTH + 1);
    assertThatThrownBy(() -> service.update(ConsentKey.TERMS, longLabel, "요약", "본문", false, null, "a", "r"))
      .extracting("errorCode").isEqualTo(ErrorCode.CONSENT_FIELD_TOO_LONG);
  }

  @Test
  @DisplayName("사유가 없으면 받지 않는다 — 화면을 거치지 않은 요청도 막는다")
  void missingReason_rejected() {
    assertThatThrownBy(() -> service.update(ConsentKey.TERMS, "이름", "요약", "새 본문", false, null, "a", "  "))
      .extracting("errorCode").isEqualTo(ErrorCode.CONSENT_REASON_REQUIRED);
  }

  @Test
  @DisplayName("버전 올리기를 켜고 칸을 비우면 거절한다 — 전에는 '올렸습니다'라고 거짓 안내했다")
  void bumpWithoutVersion_rejected() {
    assertThatThrownBy(() -> save("새 본문", true, " "))
      .extracting("errorCode").isEqualTo(ErrorCode.CONSENT_VERSION_REQUIRED);
    assertThat(terms.getVersion()).isEqualTo("2026-09-18");
  }

  @ParameterizedTest
  @ValueSource(strings = {"v2", "2026-9-21", "2026/09/21", "2026-02-30", "내일"})
  @DisplayName("날짜가 아닌 버전은 받지 않는다 — v2 한 번에 묶음 버전이 고정됐다")
  void nonDateVersion_rejected(String version) {
    assertThatThrownBy(() -> save("새 본문", true, version))
      .extracting("errorCode").isEqualTo(ErrorCode.CONSENT_VERSION_INVALID);
  }

  @ParameterizedTest
  @ValueSource(strings = {"2026-09-18", "2000-01-01"})
  @DisplayName("지금과 같거나 과거인 버전은 받지 않는다")
  void notNewerVersion_rejected(String version) {
    assertThatThrownBy(() -> save("새 본문", true, version))
      .extracting("errorCode").isEqualTo(ErrorCode.CONSENT_VERSION_NOT_NEWER);
  }

  @Test
  @DisplayName("버전을 올리면 결과가 SAVED_AND_BUMPED 이고 직전 내용이 이력에 남는다")
  void bump_savesHistoryAndReportsBump() {
    UpdateResult result = save("새 본문", true, "2026-10-01");

    assertThat(result).isEqualTo(UpdateResult.SAVED_AND_BUMPED);
    assertThat(terms.getVersion()).isEqualTo("2026-10-01");
    ArgumentCaptor<ConsentDocumentHistory> captor = ArgumentCaptor.forClass(ConsentDocumentHistory.class);
    verify(historyRepository).save(captor.capture());
    assertThat(captor.getValue().getVersion()).isEqualTo("2026-09-18");
    assertThat(captor.getValue().getBody()).isEqualTo("본문");
  }

  @Test
  @DisplayName("버전을 올리지 않으면 결과가 SAVED 이고 버전은 그대로다")
  void save_withoutBump() {
    assertThat(save("새 본문", false, null)).isEqualTo(UpdateResult.SAVED);
    assertThat(terms.getVersion()).isEqualTo("2026-09-18");
  }

  @Test
  @DisplayName("바뀐 것이 없으면 UNCHANGED 이고 이력을 만들지 않는다")
  void noChange_unchanged() {
    assertThat(save("본문", false, null)).isEqualTo(UpdateResult.UNCHANGED);
    verify(historyRepository, never()).save(any());
  }

  @Test
  @DisplayName("CRLF 는 LF 로 맞춘다 — 저장만 눌러도 가짜 이력이 쌓이지 않는다")
  void crlf_normalized() {
    terms.setBody("첫 줄\n둘째 줄");
    assertThat(save("첫 줄\r\n둘째 줄", false, null)).isEqualTo(UpdateResult.UNCHANGED);
  }

  @Test
  @DisplayName("필수 여부는 DB 값이 어긋나 있어도 법이 정한 값으로 되돌린다")
  void required_followsLaw() {
    terms.setRequired(false); // 예전 화면에서 끈 흔적
    save("새 본문", false, null);
    assertThat(terms.isRequired()).isTrue();
  }

  @Test
  @DisplayName("법이 정한 필수·선택 — 네 항목은 필수, 소식 받기는 선택")
  void lawfulRequiredFlags() {
    assertThat(Arrays.stream(ConsentKey.values()).filter(ConsentKey::isRequired).toList())
      .containsExactly(ConsentKey.TERMS, ConsentKey.PRIVACY, ConsentKey.OVERSEAS_TRANSFER, ConsentKey.AGE_CONFIRM);
    assertThat(ConsentKey.MARKETING.isRequired()).isFalse();
  }

  @Test
  @DisplayName("묶음 버전은 필수 항목만 센다 — 소식 받기 버전이 더 늦어도 무시한다")
  void bundleVersion_countsRequiredOnly() {
    ConsentDocument marketing = document(ConsentKey.MARKETING, "2027-01-01");
    ConsentDocument privacy = document(ConsentKey.PRIVACY, "2026-10-01");
    when(documentRepository.findAll()).thenReturn(List.of(terms, privacy, marketing));

    assertThat(service.bundleVersion()).isEqualTo("2026-10-01");
  }
}
