package com.chuseok22.elumserver.routine.infrastructure.ai;

import com.chuseok22.elumserver.ai.core.NicknamePlaceholder;
import com.chuseok22.elumserver.ai.core.RoutineTranslationDraft;
import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.json.DefaultJsonMapper;
import com.chuseok22.elumserver.common.infrastructure.logging.LogTextLength;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.text.ObjectParticleFixer;
import com.fasterxml.jackson.databind.JsonNode;
import java.util.ArrayList;
import java.util.List;
import java.util.function.UnaryOperator;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 일과 글 번역 (#1077): 이름 가리기 > 텍스트 제공자 호출 > 응답 검증(단계 수·빈 글) > 이름 되돌리기
 * 실패는 전부 ROUTINE_TRANSLATE_FAILED 하나로 던짐 (부르는 쪽이 사본을 만들지 않고 크레딧을 돌려줌)
 * 로그에는 글 대신 개수·길이만 남김
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class RoutineTranslationAi {

  private final TextClientRouter textClientRouter;

  /**
   * @param nickname 이룸이 이름. AI 로 나가기 전에 원문 언어 자리표시로 바꾸고, 응답은 대상 언어 자리표시를 이름으로 되돌림
   */
  public RoutineTranslationDraft translate(
    RoutineTranslationDraft source, String nickname, AppLocale sourceLanguage, AppLocale targetLanguage
  ) {
    RoutineTranslationDraft masked = mapTexts(source, text -> NicknamePlaceholder.mask(text, nickname, sourceLanguage));
    String json;
    try {
      json = textClientRouter.current().translateRoutineJson(masked, sourceLanguage, targetLanguage);
    } catch (CustomException e) {
      // 제공자 없음(TEXT_PROVIDER_UNAVAILABLE) 등은 원래 코드 그대로 (관리자가 원인을 바로 봄)
      throw e;
    } catch (RuntimeException e) {
      log.warn("[routine translate] failed 502 : provider call failed, target={}, error={}",
        targetLanguage.code(), e.getClass().getSimpleName());
      throw new CustomException(ErrorCode.ROUTINE_TRANSLATE_FAILED);
    }
    RoutineTranslationDraft translated = parse(json, source);
    return mapTexts(translated, text -> toSavedText(NicknamePlaceholder.restore(text, nickname, targetLanguage), targetLanguage));
  }

  // ko 대상은 목적격 조사 보정 (#1190)
  private static String toSavedText(String restoredText, AppLocale targetLanguage) {
    return targetLanguage == AppLocale.KO ? ObjectParticleFixer.fix(restoredText) : restoredText;
  }

  /**
   * 응답 검증 4개: JSON 객체, 제목 있음, 단계 수 = 원문 단계 수, 단계마다 설명 있음
   * 보상은 원문에 있을 때만 받음 (원문에 없는데 AI 가 지어낸 보상은 버림), 카드 제목이 비면 원문 제목 칸처럼 null
   */
  RoutineTranslationDraft parse(String json, RoutineTranslationDraft source) {
    JsonNode root = readTree(json);
    String title = textOf(root.path("title"));
    JsonNode stepsNode = root.path("steps");
    int receivedStepCount = stepsNode.isArray() ? stepsNode.size() : -1;
    if (root.isMissingNode() || !root.isObject() || title == null || receivedStepCount != source.steps().size()) {
      log.warn("[routine translate] failed 502 : invalid response, expectedSteps={}, receivedSteps={}, titleLength={}",
        source.steps().size(), receivedStepCount, LogTextLength.of(title));
      throw new CustomException(ErrorCode.ROUTINE_TRANSLATE_FAILED);
    }
    List<RoutineTranslationDraft.StepText> steps = new ArrayList<>();
    for (int index = 0; index < receivedStepCount; index++) {
      JsonNode stepNode = stepsNode.get(index);
      String description = textOf(stepNode.path("description"));
      if (description == null) {
        log.warn("[routine translate] failed 502 : empty step description, stepIndex={}", index);
        throw new CustomException(ErrorCode.ROUTINE_TRANSLATE_FAILED);
      }
      steps.add(new RoutineTranslationDraft.StepText(textOf(stepNode.path("title")), description));
    }
    String rewardText = source.rewardText() == null ? null : textOf(root.path("rewardText"));
    return new RoutineTranslationDraft(title, rewardText, steps);
  }

  private static JsonNode readTree(String json) {
    if (json == null || json.isBlank()) {
      log.warn("[routine translate] failed 502 : empty response");
      throw new CustomException(ErrorCode.ROUTINE_TRANSLATE_FAILED);
    }
    try {
      return DefaultJsonMapper.SHARED.readTree(json);
    } catch (Exception e) {
      log.warn("[routine translate] failed 502 : unreadable json, responseLength={}", LogTextLength.of(json));
      throw new CustomException(ErrorCode.ROUTINE_TRANSLATE_FAILED);
    }
  }

  /// 글 칸 > 앞뒤 공백·줄바꿈 정리한 문자열 (없거나 비면 null)
  private static String textOf(JsonNode node) {
    if (node == null || !node.isTextual()) {
      return null;
    }
    String text = node.asText().replaceAll("\\s+", " ").trim();
    return text.isEmpty() ? null : text;
  }

  /// 제목·보상·카드 글 전부에 같은 변환 (null 은 그대로)
  private static RoutineTranslationDraft mapTexts(
    RoutineTranslationDraft draft, UnaryOperator<String> transform
  ) {
    List<RoutineTranslationDraft.StepText> steps = draft.steps().stream()
      .map(step -> new RoutineTranslationDraft.StepText(
        applyIfPresent(step.title(), transform), applyIfPresent(step.description(), transform)))
      .toList();
    return new RoutineTranslationDraft(
      applyIfPresent(draft.title(), transform), applyIfPresent(draft.rewardText(), transform), steps);
  }

  private static String applyIfPresent(String text, UnaryOperator<String> transform) {
    return text == null ? null : transform.apply(text);
  }
}
