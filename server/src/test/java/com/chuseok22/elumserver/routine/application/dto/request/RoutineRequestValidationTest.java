package com.chuseok22.elumserver.routine.application.dto.request;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.ai.application.dto.request.SensitiveInfoCheckRequest;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import java.util.Set;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * AI를 부르는 입구의 요청 검증 (이슈 #215).
 *
 * <p>제약이 없던 시절에는 빈 요청 하나가 DLP·텍스트·이미지 생성을 <b>18.7초</b> 동안
 * 다 돌린 뒤 DB 제약에서 터졌다. 돈은 나가고 사용자는 500만 봤다.
 *
 * <p>컨트롤러에 {@code @Valid}는 이미 붙어 있었고 예외 핸들러도 있었다.
 * <b>기록(record)에 제약 어노테이션이 하나도 없어서 검사할 것이 없었을 뿐이다.</b>
 * 그래서 이 테스트는 어노테이션이 실제로 걸리는지를 본다.
 */
class RoutineRequestValidationTest {

  private static Validator validator;

  @BeforeAll
  static void setUp() {
    try (ValidatorFactory factory = Validation.buildDefaultValidatorFactory()) {
      validator = factory.getValidator();
    }
  }

  @Test
  @DisplayName("일과 생성 — 원문이 없으면 걸린다 (이슈 #215)")
  void create_blankRawInput_isRejected() {
    for (String blank : new String[]{null, "", "   "}) {
      Set<ConstraintViolation<RoutineCreateRequest>> violations = validator.validate(
        new RoutineCreateRequest(blank, null, null, null, null)
      );

      assertThat(violations)
        .as("원문이 [%s]인데 통과했다 — AI가 그대로 호출된다", blank)
        .isNotEmpty();
    }
  }

  @Test
  @DisplayName("일과 생성 — scheduledAt은 없어도 통과한다. 서버가 채운다 (이슈 #215)")
  void create_nullScheduledAt_isAllowed() {
    // 필수로 만들면 빠뜨린 호출 하나가 다시 AI를 태운 뒤 DB에서 터진다.
    // 클라이언트도 지금 시각을 그대로 넣고 있었으므로 서버가 채우는 편이 맞다.
    Set<ConstraintViolation<RoutineCreateRequest>> violations = validator.validate(
      new RoutineCreateRequest("아침에 회사에 가요", null, null, null, null)
    );

    assertThat(violations).isEmpty();
  }

  @Test
  @DisplayName("일과 생성 — 1000자를 넘으면 걸린다")
  void create_tooLongRawInput_isRejected() {
    String tooLong = "가".repeat(1001);

    assertThat(validator.validate(new RoutineCreateRequest(tooLong, null, null, null, null)))
      .isNotEmpty();
  }

  @Test
  @DisplayName("추가 질문 — 원문이 없으면 걸린다 (이슈 #215)")
  void question_blankRawInput_isRejected() {
    assertThat(validator.validate(new RoutineQuestionRequest("  "))).isNotEmpty();
    assertThat(validator.validate(new RoutineQuestionRequest("비 오는 날 학교 가기"))).isEmpty();
  }

  @Test
  @DisplayName("민감정보 검사 — 빈 텍스트는 걸린다 (이슈 #215)")
  void sensitiveCheck_blankText_isRejected() {
    assertThat(validator.validate(new SensitiveInfoCheckRequest(null))).isNotEmpty();
    assertThat(validator.validate(new SensitiveInfoCheckRequest("홍길동 010-1234-5678"))).isEmpty();
  }
}
