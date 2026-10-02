package com.chuseok22.elumserver.common;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.chuseok22.elumserver.common.application.exception.GlobalExceptionHandler;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorMessages;
import com.chuseok22.elumserver.common.locale.AcceptLanguageFilter;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineCreateRequest;
import jakarta.validation.Valid;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.context.support.StaticMessageSource;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.bind.annotation.RestController;

/**
 * 필터 → 컨트롤러 → 예외 어드바이스를 실제로 거친 응답 (다국어 #526).
 *
 * <p>단위 테스트가 핸들러를 직접 부르는 것과 달리, 여기서는 {@code Accept-Language} 가 실제 요청 헤더로 들어간다.
 * 헤더가 없으면 응답 본문이 이전과 <b>바이트 단위로 같아야</b> 한다 — 기대 문자열은 작업 전 응답을 손으로 적은 것이다.
 * 번역 리소스가 비어 있어 ja 도 ko 와 같은 글자가 나오므로, 배선은 가짜 일본어 문구를 끼워 따로 증명한다.
 */
class GlobalExceptionHandlerLocaleMvcTest {

  /**
   * standalone MockMvc 는 타입에 @Controller 계열이 있어야 핸들러로 인식한다(@RequestMapping 만으로는 404).
   * 테스트 클래스의 중첩 클래스라 Boot 의 TestTypeExcludeFilter 가 컴포넌트 스캔에서 제외한다(서버 전체 테스트로 확인).
   */
  @RestController
  @RequestMapping("/probe")
  public static class Probe {

    @GetMapping("/error")
    @ResponseBody
    public String error() {
      throw new CustomException(ErrorCode.ROUTINE_NOT_FOUND);
    }

    @PostMapping("/routine")
    @ResponseBody
    public String create(@RequestBody @Valid RoutineCreateRequest request) {
      return "ok";
    }
  }

  private MockMvc mockMvc;

  @BeforeEach
  void setUp() {
    mockMvc = buildMockMvc();
  }

  // 핸들러가 생성 시점의 ErrorMessages.standard() 를 쥐므로, 가짜 문구를 끼운 뒤에는 다시 만들어야 한다
  private static MockMvc buildMockMvc() {
    return MockMvcBuilders.standaloneSetup(new Probe())
      .setControllerAdvice(new GlobalExceptionHandler())
      .addFilters(new AcceptLanguageFilter())
      .build();
  }

  // 가짜 문구를 쓴 테스트가 다른 테스트로 새지 않게 항상 원복한다
  @AfterEach
  void restore() {
    ErrorMessages.resetStandardForTesting();
  }

  private String body(ResultActions actions) throws Exception {
    return actions.andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8);
  }

  @Test
  @DisplayName("헤더 없음: CustomException 응답이 이전과 바이트 단위로 같다")
  void headerless_customException_isLegacy() throws Exception {
    var result = mockMvc.perform(get("/probe/error")).andExpect(status().isNotFound());

    assertThat(body(result).getBytes(StandardCharsets.UTF_8)).isEqualTo(
      "{\"errorCode\":\"ROUTINE_NOT_FOUND\",\"errorMessage\":\"존재하지 않는 일과입니다.\"}".getBytes(StandardCharsets.UTF_8));
  }

  @Test
  @DisplayName("헤더 없음: 검증 오류 응답이 이전과 바이트 단위로 같다 — 필드 이름 + DTO 문구")
  void headerless_validation_isLegacy() throws Exception {
    var result = mockMvc.perform(post("/probe/routine").contentType(MediaType.APPLICATION_JSON)
      .content("{\"rawInputText\":\"\"}")).andExpect(status().isBadRequest());

    assertThat(body(result).getBytes(StandardCharsets.UTF_8)).isEqualTo(
      "{\"errorCode\":\"INVALID_INPUT_VALUE\",\"errorMessage\":\"rawInputText: 일과 내용을 입력해주세요.\"}"
        .getBytes(StandardCharsets.UTF_8));
  }

  @Test
  @DisplayName("헤더 없음: 본문을 읽을 수 없을 때 응답이 이전과 바이트 단위로 같다")
  void headerless_unreadableBody_isLegacy() throws Exception {
    var result = mockMvc.perform(post("/probe/routine").contentType(MediaType.APPLICATION_JSON)
      .content("{깨진 json")).andExpect(status().isBadRequest());

    assertThat(body(result).getBytes(StandardCharsets.UTF_8)).isEqualTo(
      "{\"errorCode\":\"INVALID_INPUT_VALUE\",\"errorMessage\":\"요청 본문을 읽을 수 없습니다.\"}"
        .getBytes(StandardCharsets.UTF_8));
  }

  @Test
  @DisplayName("일본어 요청: 상태·에러 코드는 그대로이고 필드 문구는 대체 순서가 고른 값이다")
  void jaRequest_validation_followsChain() throws Exception {
    String expectedMessage = ErrorMessages.standard()
      .of("validation.routineCreateRequest.rawInputText.NotBlank", AppLocale.JA, "<<없음>>");

    mockMvc.perform(post("/probe/routine").header("Accept-Language", "ja").contentType(MediaType.APPLICATION_JSON)
        .content("{\"rawInputText\":\"\"}"))
      .andExpect(status().isBadRequest())
      .andExpect(jsonPath("$.errorCode").value("INVALID_INPUT_VALUE"))
      .andExpect(jsonPath("$.errorMessage").value("rawInputText: " + expectedMessage));
  }

  @Test
  @DisplayName("가짜 일본어 문구: ja 요청의 검증 오류 문구가 응답에 나오고, 헤더 없는 요청은 DTO 한국어 그대로다")
  void fakeJapanese_validation_reachesResponse() throws Exception {
    StaticMessageSource source = new StaticMessageSource();
    source.addMessage("validation.routineCreateRequest.rawInputText.NotBlank", Locale.of("ja"),
      "JA-FAKE:rawInputText.NotBlank");
    ErrorMessages.overrideStandardForTesting(new ErrorMessages(source));
    mockMvc = buildMockMvc();

    mockMvc.perform(post("/probe/routine").header("Accept-Language", "ja").contentType(MediaType.APPLICATION_JSON)
        .content("{\"rawInputText\":\"\"}"))
      .andExpect(status().isBadRequest())
      .andExpect(jsonPath("$.errorMessage").value("rawInputText: JA-FAKE:rawInputText.NotBlank"));

    // 헤더가 없으면 가짜 ja 가 있어도 ko 경로라 DTO 문구가 그대로 나온다
    mockMvc.perform(post("/probe/routine").contentType(MediaType.APPLICATION_JSON).content("{\"rawInputText\":\"\"}"))
      .andExpect(jsonPath("$.errorMessage").value("rawInputText: 일과 내용을 입력해주세요."));
  }

  @Test
  @DisplayName("가짜 일본어 문구: ja 요청의 본문 읽기 실패 문구가 응답에 나오고, 헤더 없는 요청은 한국어 그대로다")
  void fakeJapanese_unreadableBody_reachesResponse() throws Exception {
    StaticMessageSource source = new StaticMessageSource();
    source.addMessage("detail.requestBodyUnreadable", Locale.of("ja"), "JA-FAKE:requestBodyUnreadable");
    ErrorMessages.overrideStandardForTesting(new ErrorMessages(source));
    mockMvc = buildMockMvc();

    mockMvc.perform(post("/probe/routine").header("Accept-Language", "ja").contentType(MediaType.APPLICATION_JSON)
        .content("{깨진 json"))
      .andExpect(status().isBadRequest())
      .andExpect(jsonPath("$.errorMessage").value("JA-FAKE:requestBodyUnreadable"));

    mockMvc.perform(post("/probe/routine").contentType(MediaType.APPLICATION_JSON).content("{깨진 json"))
      .andExpect(jsonPath("$.errorMessage").value("요청 본문을 읽을 수 없습니다."));
  }

  @ParameterizedTest
  @ValueSource(strings = {"*", "ar", "zh-TW", "zh-Hant", "zh-Hans", "en;q=0.1, ja;q=0.9", ";;;", "\u0000", "日本語"})
  @DisplayName("이상한 Accept-Language 도 500 이 아니라 정해진 응답이 나온다")
  void weirdHeaders_neverBreakTheResponse(String header) throws Exception {
    mockMvc.perform(get("/probe/error").header("Accept-Language", header))
      .andExpect(status().isNotFound())
      .andExpect(jsonPath("$.errorCode").value("ROUTINE_NOT_FOUND"))
      .andExpect(jsonPath("$.errorMessage").isNotEmpty());
  }
}
