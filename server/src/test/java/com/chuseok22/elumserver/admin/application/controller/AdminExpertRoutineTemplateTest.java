package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.dto.request.ExpertRoutineEditForm;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.expertroutine.application.service.ExpertRoutineInputRules;
import com.chuseok22.elumserver.expertroutine.core.ExpertRoutineReviewStatus;
import com.chuseok22.elumserver.expertroutine.infrastructure.entity.ExpertRoutine;
import com.chuseok22.elumserver.expertroutine.infrastructure.entity.ExpertRoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.constant.RewardPreset;
import com.chuseok22.elumserver.talk.core.TalkCategory;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 관리자 전문가 일과 화면: 템플릿 오류로 화면이 500 이 되거나, 검수 상태가 안 보여 초안을 공개하는 일을 막는다.
class AdminExpertRoutineTemplateTest {

  private final AdminTemplateRenderSupport renderer = new AdminTemplateRenderSupport();

  @Test
  @DisplayName("목록: 초안은 '초안, 전문가 검수 필요'와 숨김, 공개·검수 완료는 '앱에 나감'으로 그린다")
  void listShowsReviewAndVisibility() {
    Map<String, Object> variables = new HashMap<>();
    variables.put("routines", List.of(routine("d1", ExpertRoutineReviewStatus.DRAFT, false),
      routine("r1", ExpertRoutineReviewStatus.REVIEWED, true)));
    variables.put("message", "저장했어요.");

    String html = renderer.render("admin/expert-routines", variables);

    assertThat(html).contains("초안, 전문가 검수 필요").contains("앱에 나감").contains("숨김")
      .contains("기존 일과에서 묶음 만들기").contains("/admin/expert-routines/from-routine")
      .contains("/admin/expert-routines/r1/published");
  }

  @Test
  @DisplayName("빈 목록은 빈 상태 줄을 그린다")
  void emptyListShowsEmptyRow() {
    String html = renderer.render("admin/expert-routines", Map.of("routines", List.of()));

    assertThat(html).contains("아직 전문가 일과가 없어요");
  }

  @Test
  @DisplayName("편집: 카드 칸은 '문장 | 픽토그램 id' 줄로 되돌려 그리고, 저장 실패 문구에 E-EXR 코드가 있다")
  void editRendersStepsAndError() {
    ExpertRoutine routine = routine("r1", ExpertRoutineReviewStatus.REVIEWED, true);
    ExpertRoutineStep step = new ExpertRoutineStep();
    step.setText("손을 씻어요");
    step.setPictogramId("wash_hands_,_to");
    Map<String, Object> variables = new HashMap<>();
    variables.put("form", ExpertRoutineEditForm.of(routine, List.of(step)));
    variables.put("routine", routine);
    variables.put("categories", TalkCategory.values());
    variables.put("languages", AppLocale.values());
    variables.put("reviewStatuses", ExpertRoutineReviewStatus.values());
    variables.put("rewardPresets", RewardPreset.values());
    variables.put("errorMessage", AdminExpertRoutineController.failureReason(
      new CustomException(ErrorCode.EXPERT_ROUTINE_INVALID, ExpertRoutineInputRules.REASON_PICTOGRAM_UNKNOWN)));

    String html = renderer.render("admin/expert-routine-edit", variables);

    assertThat(html).contains("손을 씻어요 | wash_hands_,_to").contains("(E-EXR-011)").contains("검수 완료");
  }

  @Test
  @DisplayName("편집 폼의 카드 줄 > 입력: 칸을 나누고, 빈 칸은 null 이 아니라 서비스가 다듬을 빈 값이다")
  void formParsesStepLines() {
    ExpertRoutineEditForm form = new ExpertRoutineEditForm("t", "", "DAILY_FLOW", "ko", "", "", "0", "DRAFT", "",
      "손을 씻어요 | wash_hands_,_to\n가방을 메요\n\n박수 |  | clap");

    assertThat(form.toInput().steps()).extracting(step -> step.text() + "/" + step.pictogramId() + "/" + step.exampleImageId())
      .containsExactly("손을 씻어요/wash_hands_,_to/null", "가방을 메요/null/null", "/null/null", "박수//clap");
  }

  private static ExpertRoutine routine(String id, ExpertRoutineReviewStatus status, boolean isPublished) {
    ExpertRoutine routine = new ExpertRoutine();
    routine.setId(id);
    routine.setTitle("등교 준비 " + id);
    routine.setSummary("한 줄");
    routine.setCategory(TalkCategory.DAILY_FLOW);
    routine.setLanguage(AppLocale.KO);
    routine.setReviewStatus(status);
    routine.setPublished(isPublished);
    routine.setStepCount(1);
    return routine;
  }
}
