package com.chuseok22.elumserver.expertroutine.application.service;

import com.chuseok22.elumserver.ai.application.service.PictogramCatalog;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.expertroutine.application.dto.request.ExpertRoutineInput;
import com.chuseok22.elumserver.expertroutine.application.dto.request.ExpertRoutineInput.StepInput;
import com.chuseok22.elumserver.expertroutine.core.ExpertRoutineReviewStatus;
import com.chuseok22.elumserver.expertroutine.infrastructure.entity.ExpertRoutine;
import com.chuseok22.elumserver.expertroutine.infrastructure.entity.ExpertRoutineStep;
import com.chuseok22.elumserver.routine.core.RoutineStepLimits;
import com.chuseok22.elumserver.routine.infrastructure.constant.RewardPreset;
import com.chuseok22.elumserver.talk.core.TalkCategory;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * 관리자 입력 검증: 다듬기(제어문자·앞뒤 공백) > 칸별 검사 > 거절 이유 하나 (detail)
 * 이유 코드는 관리자 화면이 문구·추적 코드(E-EXR-0NN)로 바꿈
 */
@Component
@RequiredArgsConstructor
public class ExpertRoutineInputRules {

  // 거절 이유 (CustomException detail)
  public static final String REASON_TITLE_REQUIRED = "TITLE_REQUIRED";
  public static final String REASON_TITLE_TOO_LONG = "TITLE_TOO_LONG";
  public static final String REASON_SUMMARY_TOO_LONG = "SUMMARY_TOO_LONG";
  public static final String REASON_CATEGORY_INVALID = "CATEGORY_INVALID";
  public static final String REASON_LANGUAGE_INVALID = "LANGUAGE_INVALID";
  public static final String REASON_REWARD_TOO_LONG = "REWARD_TOO_LONG";
  public static final String REASON_SORT_ORDER_INVALID = "SORT_ORDER_INVALID";
  public static final String REASON_STEPS_REQUIRED = "STEPS_REQUIRED";
  public static final String REASON_STEPS_TOO_MANY = "STEPS_TOO_MANY";
  public static final String REASON_STEP_TEXT_TOO_LONG = "STEP_TEXT_TOO_LONG";
  public static final String REASON_PICTOGRAM_UNKNOWN = "PICTOGRAM_UNKNOWN";
  public static final String REASON_EXAMPLE_IMAGE_INVALID = "EXAMPLE_IMAGE_INVALID";
  public static final String REASON_NOT_REVIEWED = "NOT_REVIEWED";

  // 예시 이미지 id 모양 (앱 번들 파일 이름: 소문자·숫자·밑줄)
  private static final Pattern EXAMPLE_IMAGE_ID = Pattern.compile("^[a-z0-9_]{1,100}$");

  private final PictogramCatalog pictogramCatalog;

  /// 검증을 통과한 값 (빈 값은 null, 카드는 빈 줄을 뺀 순서 그대로)
  public record Validated(
    String title,
    String summary,
    TalkCategory category,
    AppLocale language,
    String rewardText,
    String rewardPresetKey,
    int sortOrder,
    ExpertRoutineReviewStatus reviewStatus,
    String reviewNote,
    List<StepInput> steps
  ) {

  }

  /**
   * 입력 검증: 제목 > 설명 > 분류 > 언어 > 보상 > 순서 > 카드 (첫 거절 이유로 멈춤)
   *
   * @throws CustomException EXPERT_ROUTINE_INVALID (detail = REASON_*)
   */
  public Validated validate(ExpertRoutineInput input) {
    String title = clean(input.title());
    if (title == null) {
      throw invalid(REASON_TITLE_REQUIRED);
    }
    if (lengthOf(title) > ExpertRoutine.TITLE_MAX_LENGTH) {
      throw invalid(REASON_TITLE_TOO_LONG);
    }
    String summary = clean(input.summary());
    if (summary != null && lengthOf(summary) > ExpertRoutine.SUMMARY_MAX_LENGTH) {
      throw invalid(REASON_SUMMARY_TOO_LONG);
    }
    String rewardText = clean(input.rewardText());
    if (rewardText != null && lengthOf(rewardText) > ExpertRoutine.REWARD_TEXT_MAX_LENGTH) {
      throw invalid(REASON_REWARD_TOO_LONG);
    }
    return new Validated(title, summary, categoryOf(input.category()), languageOf(input.language()), rewardText,
      RewardPreset.normalize(input.rewardPresetKey()), sortOrderOf(input.sortOrder()),
      ExpertRoutineReviewStatus.parseOrDraft(input.reviewStatus()), clean(input.reviewNote()), stepsOf(input.steps()));
  }

  private static TalkCategory categoryOf(String raw) {
    try {
      return TalkCategory.parse(raw);
    } catch (CustomException e) {
      throw invalid(REASON_CATEGORY_INVALID);
    }
  }

  private static AppLocale languageOf(String raw) {
    return AppLocale.findByCode(raw == null ? null : raw.trim()).orElseThrow(() -> invalid(REASON_LANGUAGE_INVALID));
  }

  // 비우면 0
  private static int sortOrderOf(String raw) {
    String sortOrderText = clean(raw);
    if (sortOrderText == null) {
      return 0;
    }
    try {
      return Integer.parseInt(sortOrderText);
    } catch (NumberFormatException e) {
      throw invalid(REASON_SORT_ORDER_INVALID);
    }
  }

  // 카드 검사 (빈 문장 줄은 뺌, 1~10장, 문장 길이, 픽토그램은 카탈로그에 있는 id, 예시 이미지는 파일 이름 모양)
  private List<StepInput> stepsOf(List<StepInput> rawSteps) {
    List<StepInput> steps = new ArrayList<>();
    for (StepInput raw : rawSteps == null ? List.<StepInput>of() : rawSteps) {
      String text = clean(raw.text());
      if (text == null) {
        continue;
      }
      if (lengthOf(text) > ExpertRoutineStep.TEXT_MAX_LENGTH) {
        throw invalid(REASON_STEP_TEXT_TOO_LONG);
      }
      String pictogramId = clean(raw.pictogramId());
      if (pictogramId != null && !pictogramCatalog.contains(pictogramId)) {
        throw invalid(REASON_PICTOGRAM_UNKNOWN);
      }
      String exampleImageId = clean(raw.exampleImageId());
      if (exampleImageId != null && !EXAMPLE_IMAGE_ID.matcher(exampleImageId).matches()) {
        throw invalid(REASON_EXAMPLE_IMAGE_INVALID);
      }
      steps.add(new StepInput(text, pictogramId, exampleImageId));
    }
    if (steps.isEmpty()) {
      throw invalid(REASON_STEPS_REQUIRED);
    }
    if (steps.size() > RoutineStepLimits.MAX_STEP_COUNT) {
      throw invalid(REASON_STEPS_TOO_MANY);
    }
    return steps;
  }

  // 제어문자 제거(줄바꿈 포함) > 앞뒤 공백 제거 > 빈 값은 null
  private static String clean(String raw) {
    if (raw == null) {
      return null;
    }
    StringBuilder cleaned = new StringBuilder(raw.length());
    raw.codePoints().filter(codePoint -> !Character.isISOControl(codePoint)).forEach(cleaned::appendCodePoint);
    String cleanedText = cleaned.toString().strip();
    return cleanedText.isEmpty() ? null : cleanedText;
  }

  private static int lengthOf(String text) {
    return text.codePointCount(0, text.length());
  }

  private static CustomException invalid(String reason) {
    return new CustomException(ErrorCode.EXPERT_ROUTINE_INVALID, reason);
  }
}
