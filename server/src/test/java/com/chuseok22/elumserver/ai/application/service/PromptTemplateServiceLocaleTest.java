package com.chuseok22.elumserver.ai.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import ch.qos.logback.classic.Level;
import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;
import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplate;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplateHistory;
import com.chuseok22.elumserver.ai.infrastructure.repository.PromptTemplateHistoryRepository;
import com.chuseok22.elumserver.ai.infrastructure.repository.PromptTemplateRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.slf4j.LoggerFactory;

@ExtendWith(MockitoExtension.class)
class PromptTemplateServiceLocaleTest {

  private static final PromptKey CREATE = PromptKey.GEMINI_ROUTINE_CREATE_PREFIX;

  @Mock
  private PromptTemplateRepository promptTemplateRepository;

  @Mock
  private PromptTemplateHistoryRepository promptTemplateHistoryRepository;

  @InjectMocks
  private PromptTemplateService service;

  private ListAppender<ILoggingEvent> logs;

  @BeforeEach
  void attachLogAppender() {
    logs = new ListAppender<>();
    logs.start();
    ((Logger) LoggerFactory.getLogger(PromptTemplateService.class)).addAppender(logs);
  }

  @AfterEach
  void tearDown() {
    ((Logger) LoggerFactory.getLogger(PromptTemplateService.class)).detachAppender(logs);
    AiCallContext.clear();
  }

  private PromptTemplate row(PromptKey key, String locale, String content) {
    PromptTemplate template = new PromptTemplate();
    template.setPromptKey(key);
    template.setLocale(locale);
    template.setContent(content);
    return template;
  }

  @Test
  @DisplayName("그 언어의 행이 있으면 그 행을 쓴다")
  void exactRow() {
    when(promptTemplateRepository.findByPromptKeyAndLocale(CREATE, "es"))
      .thenReturn(Optional.of(row(CREATE, "es", "지시문 es")));

    assertThat(service.getContent(CREATE, AppLocale.ES)).isEqualTo("지시문 es");
    assertThat(logs.list).isEmpty();
  }

  @Test
  @DisplayName("인자 없는 getContent 는 일과 언어(AiCallContext)의 행을 읽는다")
  void noArgUsesContextLocale() {
    AiCallContext.setContentLocale(AppLocale.JA);
    when(promptTemplateRepository.findByPromptKeyAndLocale(CREATE, "ja"))
      .thenReturn(Optional.of(row(CREATE, "ja", "지시문 ja")));

    assertThat(service.getContent(CREATE)).isEqualTo("지시문 ja");
  }

  @Test
  @DisplayName("행이 없으면 en 으로 대체하고 마커가 든 오류 로그를 남긴다 — 로그에 프롬프트 내용은 없다")
  void missingFallsBackToEn_andLogsMarkerWithoutContent() {
    when(promptTemplateRepository.findByPromptKeyAndLocale(CREATE, "es")).thenReturn(Optional.empty());
    when(promptTemplateRepository.findByPromptKeyAndLocale(CREATE, "en"))
      .thenReturn(Optional.of(row(CREATE, "en", "SECRET-EN-PROMPT-BODY")));

    assertThat(service.getContent(CREATE, AppLocale.ES)).isEqualTo("SECRET-EN-PROMPT-BODY");

    assertThat(logs.list).hasSize(1);
    ILoggingEvent event = logs.list.get(0);
    assertThat(event.getLevel()).isEqualTo(Level.ERROR);
    assertThat(event.getFormattedMessage())
      .contains("[PROMPT_LOCALE_FALLBACK]").contains("requested=es").contains("used=en")
      .doesNotContain("SECRET-EN-PROMPT-BODY");
  }

  @Test
  @DisplayName("es 도 en 도 없으면 ko 행까지 내려간다")
  void fallsBackToKo() {
    when(promptTemplateRepository.findByPromptKeyAndLocale(CREATE, "es")).thenReturn(Optional.empty());
    when(promptTemplateRepository.findByPromptKeyAndLocale(CREATE, "en")).thenReturn(Optional.empty());
    when(promptTemplateRepository.findByPromptKeyAndLocale(CREATE, "ko"))
      .thenReturn(Optional.of(row(CREATE, "ko", "지시문 ko")));

    assertThat(service.getContent(CREATE, AppLocale.ES)).isEqualTo("지시문 ko");
    assertThat(logs.list.get(0).getFormattedMessage()).contains("used=ko");
  }

  @Test
  @DisplayName("ko 요청은 ko 행이 없어도 영어로 떨어지지 않는다")
  void koRequest_neverFallsToEnglish() {
    when(promptTemplateRepository.findByPromptKeyAndLocale(CREATE, "ko")).thenReturn(Optional.empty());

    assertThatThrownBy(() -> service.getContent(CREATE, AppLocale.KO))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.PROMPT_TEMPLATE_NOT_FOUND));
    verify(promptTemplateRepository, never()).findByPromptKeyAndLocale(CREATE, "en");
  }

  @Test
  @DisplayName("어느 행도 없으면 PROMPT_TEMPLATE_NOT_FOUND")
  void nothingAtAll_throws() {
    when(promptTemplateRepository.findByPromptKeyAndLocale(any(), any())).thenReturn(Optional.empty());

    assertThatThrownBy(() -> service.getContent(CREATE, AppLocale.ES))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.PROMPT_TEMPLATE_NOT_FOUND));
  }

  @Test
  @DisplayName("언어 중립 키(그림 지시문)는 어느 언어로 불러도 ko 행 하나다")
  void neutralKeyAlwaysKo() {
    PromptKey image = PromptKey.GEMINI_ROUTINE_IMAGE_PREFIX;
    when(promptTemplateRepository.findByPromptKeyAndLocale(image, "ko"))
      .thenReturn(Optional.of(row(image, "ko", "그림 지시문")));

    assertThat(service.getContent(image, AppLocale.ES)).isEqualTo("그림 지시문");
    verify(promptTemplateRepository, never()).findByPromptKeyAndLocale(image, "es");
    assertThat(logs.list).isEmpty();
  }

  @Test
  @DisplayName("update 는 그 언어 행만 고치고 직전 내용을 그 언어 이력으로 남긴다")
  void update_writesLocaleHistory() {
    PromptTemplate es = row(CREATE, "es", "이전 es");
    when(promptTemplateRepository.findByPromptKeyAndLocale(CREATE, "es")).thenReturn(Optional.of(es));

    service.update(CREATE, AppLocale.ES, "새 es\r\n둘째 줄");

    assertThat(es.getContent()).isEqualTo("새 es\n둘째 줄");
    ArgumentCaptor<PromptTemplateHistory> captor = ArgumentCaptor.forClass(PromptTemplateHistory.class);
    verify(promptTemplateHistoryRepository).save(captor.capture());
    assertThat(captor.getValue().getLocale()).isEqualTo("es");
    assertThat(captor.getValue().getContent()).isEqualTo("이전 es");
    verify(promptTemplateRepository, never()).findByPromptKeyAndLocale(CREATE, "ko");
  }

  @Test
  @DisplayName("없는 행을 update 로 만들지 않는다 — 행 만들기는 시더의 일이다")
  void update_missingRow_throws() {
    when(promptTemplateRepository.findByPromptKeyAndLocale(CREATE, "zh")).thenReturn(Optional.empty());

    assertThatThrownBy(() -> service.update(CREATE, AppLocale.ZH, "내용"))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.PROMPT_TEMPLATE_NOT_FOUND));
    verify(promptTemplateHistoryRepository, never()).save(any());
  }

  @Test
  @DisplayName("getHistory·getAll 은 그 언어 것만 돌려준다")
  void historyAndListAreLocaleScoped() {
    PromptTemplateHistory history = new PromptTemplateHistory();
    when(promptTemplateHistoryRepository.findTop50ByPromptKeyAndLocaleOrderByCreatedAtDesc(CREATE, "ja"))
      .thenReturn(List.of(history));
    PromptTemplate ko = row(CREATE, "ko", "ko");
    PromptTemplate ja = row(CREATE, "ja", "ja");
    when(promptTemplateRepository.findAll()).thenReturn(List.of(ko, ja));

    assertThat(service.getHistory(CREATE, AppLocale.JA)).containsExactly(history);
    assertThat(service.getAll(AppLocale.JA)).containsExactly(ja);
    assertThat(service.getAll()).containsExactly(ko);
  }

  @Test
  @DisplayName("missingKeys: ko 는 모든 키, 그 밖의 언어는 번역이 필요한 키만 본다")
  void missingKeys() {
    when(promptTemplateRepository.findByPromptKeyAndLocale(any(), eq("es"))).thenAnswer(invocation -> {
      PromptKey key = invocation.getArgument(0);
      boolean present = key == PromptKey.GEMINI_ROUTINE_CREATE_PREFIX || key == PromptKey.GEMINI_ROUTINE_QUESTION_PREFIX;
      return present ? Optional.of(row(key, "es", "x")) : Optional.empty();
    });
    when(promptTemplateRepository.findByPromptKeyAndLocale(any(), eq("ko")))
      .thenReturn(Optional.of(row(CREATE, "ko", "x")));

    assertThat(service.missingKeys(AppLocale.ES))
      .containsExactly(PromptKey.FLUX_IMAGE_PROMPT_TRANSLATE, PromptKey.REALISTIC_IMAGE_PROMPT_TRANSLATE);
    assertThat(service.missingKeys(AppLocale.KO)).isEmpty();
  }
}
