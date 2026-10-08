package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.application.service.PictogramCatalog;
import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Duration;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

/**
 * 보호자가 직접 추가한 카드 한 장에 무료 픽토그램 id 를 고른다.
 *
 * <p>일과 생성은 글 호출 하나에서 id 를 함께 받지만 직접 추가한 카드는 그 호출이 없어, 글 모델을 한 번 더 부른다(제한 목록 선택 방식).
 *
 * <p><b>카드 추가는 절대 실패하지 않는다.</b> 호출 실패·타임아웃·잘못된 응답·하루 비용 상한이면 카탈로그의 폴백 id 를 돌려준다.
 * 카탈로그를 못 읽은 서버만 null 이다.
 *
 * <p><b>크레딧을 쓰지 않는다.</b> 글 호출 한 번은 그림 한 장의 몇 백 분의 일이라 서비스 원가로 흡수한다. 하루 비용 상한에 걸리면
 * 호출을 건너뛰고, 호출은 ai_call_log 에 기록돼(GEMINI/OPENAI_TEXT_PICTOGRAM) 하루 합계에 잡힌다.
 *
 * <p>가상 스레드에서 짧은 제한 시간으로 기다리고, 넘기면 결과를 버리고 폴백으로 간다. addStep 트랜잭션 안에서 불리므로
 * DB 커넥션을 오래 붙잡지 않게 제한을 짧게 둔다.
 */
@Slf4j
@Component
public class PictogramPicker {

  static final Duration DEFAULT_TIMEOUT = Duration.ofSeconds(5);

  private final ObjectMapper objectMapper = new ObjectMapper();
  private final PictogramCatalog catalog;
  private final TextClientRouter textClientRouter;
  private final AiDailyBudgetGuard aiDailyBudgetGuard;
  private final Duration timeout;
  private final ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();

  @Autowired
  public PictogramPicker(
    PictogramCatalog catalog, TextClientRouter textClientRouter, AiDailyBudgetGuard aiDailyBudgetGuard
  ) {
    this(catalog, textClientRouter, aiDailyBudgetGuard, DEFAULT_TIMEOUT);
  }

  PictogramPicker(
    PictogramCatalog catalog, TextClientRouter textClientRouter, AiDailyBudgetGuard aiDailyBudgetGuard,
    Duration timeout
  ) {
    this.catalog = catalog;
    this.textClientRouter = textClientRouter;
    this.aiDailyBudgetGuard = aiDailyBudgetGuard;
    this.timeout = timeout;
  }

  /**
   * @param memberId AI 호출 기록에 회원을 남기려고 호출 스레드에 세운다
   * @return 유효한 픽토그램 id, 못 골랐으면 폴백 id. 카탈로그가 비었으면 null. 던지지 않는다.
   */
  public String pick(String memberId, String title, String description) {
    if (catalog.isEmpty()) {
      return null;
    }
    try {
      if (aiDailyBudgetGuard.isReached()) {
        log.warn("AI 하루 비용 상한 — 픽토그램 고르기를 건너뛰고 폴백을 쓴다");
        return catalog.fallbackId();
      }
      String json = CompletableFuture
        .supplyAsync(() -> callModel(memberId, title, description), executor)
        .get(timeout.toMillis(), TimeUnit.MILLISECONDS);
      String resolved = catalog.resolve(readPictogramId(json));
      if (resolved != null && !resolved.equals(catalog.fallbackId())) {
        log.info("픽토그램 선택: pictogramId={}", resolved);
      } else {
        log.info("픽토그램 폴백 적용: response={}", json);
      }
      return resolved;
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      log.warn("픽토그램 고르기 중단 — 폴백을 쓴다", e);
      return catalog.fallbackId();
    } catch (Exception e) {
      // 타임아웃·호출 실패·파싱 실패·제공자 사용 불가 전부 같다 — 카드는 폴백 그림으로 만든다.
      log.warn("픽토그램 고르기 실패 — 폴백을 쓴다: title={}", title, e);
      return catalog.fallbackId();
    }
  }

  // 요청 스레드가 아닌 가상 스레드라 회원 맥락을 다시 세워야 호출 기록에 회원이 남는다.
  private String callModel(String memberId, String title, String description) {
    AiCallContext.setMemberId(memberId);
    try {
      return textClientRouter.current().pickPictogramJson(title, description);
    } finally {
      AiCallContext.clear();
    }
  }

  private String readPictogramId(String json) throws Exception {
    JsonNode node = objectMapper.readTree(json).path("pictogramId");
    return node.isTextual() ? node.asText() : null;
  }
}
