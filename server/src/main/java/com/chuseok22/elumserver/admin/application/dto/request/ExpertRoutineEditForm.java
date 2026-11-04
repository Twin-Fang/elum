package com.chuseok22.elumserver.admin.application.dto.request;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.expertroutine.application.dto.request.ExpertRoutineInput;
import com.chuseok22.elumserver.expertroutine.application.dto.request.ExpertRoutineInput.StepInput;
import com.chuseok22.elumserver.expertroutine.core.ExpertRoutineReviewStatus;
import com.chuseok22.elumserver.expertroutine.infrastructure.entity.ExpertRoutine;
import com.chuseok22.elumserver.expertroutine.infrastructure.entity.ExpertRoutineStep;
import com.chuseok22.elumserver.talk.core.TalkCategory;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;

/**
 * 전문가 일과 편집 화면 입력값: 검증에 걸리면 입력 그대로 다시 그리려고 숫자·코드도 문자열
 * 카드 칸 stepsText: 한 줄에 카드 1장, `문장 | 픽토그램 id | 예시 이미지 id` (뒤 둘은 비워도 됨)
 */
public record ExpertRoutineEditForm(
  String title,
  String summary,
  String category,
  String language,
  String rewardText,
  String rewardPresetKey,
  String sortOrder,
  String reviewStatus,
  String reviewNote,
  String stepsText
) {

  // 카드 한 줄 칸 구분자
  public static final String STEP_FIELD_DELIMITER = "|";
  private static final Pattern STEP_FIELD_SPLIT = Pattern.compile("\\s*\\|\\s*");
  private static final Pattern LINE_SPLIT = Pattern.compile("\\r?\\n");

  /// 새 일과: 초안, 한국어, 하루 순서 분류
  public static ExpertRoutineEditForm blank() {
    return new ExpertRoutineEditForm("", "", TalkCategory.DAILY_FLOW.name(), AppLocale.KO.code(), "", "", "0",
      ExpertRoutineReviewStatus.DRAFT.name(), "", "");
  }

  public static ExpertRoutineEditForm of(ExpertRoutine routine, List<ExpertRoutineStep> steps) {
    List<String> lines = new ArrayList<>();
    for (ExpertRoutineStep step : steps) {
      lines.add(String.join(" " + STEP_FIELD_DELIMITER + " ",
        step.getText(), nullToEmpty(step.getPictogramId()), nullToEmpty(step.getExampleImageId())).strip());
    }
    return new ExpertRoutineEditForm(routine.getTitle(), nullToEmpty(routine.getSummary()), routine.getCategory().name(),
      routine.getLanguage().code(), nullToEmpty(routine.getRewardText()), nullToEmpty(routine.getRewardPresetKey()),
      String.valueOf(routine.getSortOrder()), routine.getReviewStatus().name(), nullToEmpty(routine.getReviewNote()),
      String.join("\n", lines));
  }

  /// 입력값 > 서비스 입력 (카드 줄 나누기만, 검증은 서비스)
  public ExpertRoutineInput toInput() {
    return new ExpertRoutineInput(title, summary, category, language, rewardText, rewardPresetKey, sortOrder,
      reviewStatus, reviewNote, stepsOf(stepsText));
  }

  // 줄 > 카드 (빈 줄은 서비스가 뺌), 칸이 모자라면 빈 칸
  private static List<StepInput> stepsOf(String text) {
    List<StepInput> steps = new ArrayList<>();
    if (text == null) {
      return steps;
    }
    for (String line : LINE_SPLIT.split(text)) {
      String[] fields = STEP_FIELD_SPLIT.split(line.strip(), 3);
      steps.add(new StepInput(fieldAt(fields, 0), fieldAt(fields, 1), fieldAt(fields, 2)));
    }
    return steps;
  }

  private static String fieldAt(String[] fields, int index) {
    return index < fields.length ? fields[index] : null;
  }

  private static String nullToEmpty(String value) {
    return value == null ? "" : value;
  }
}
