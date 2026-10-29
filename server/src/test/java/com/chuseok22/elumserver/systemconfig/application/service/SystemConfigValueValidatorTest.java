package com.chuseok22.elumserver.systemconfig.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 설정 값 형식·범위 검사 (#909, #912). 잘못된 값이 저장되면 강제 업데이트·광고 노출·남용 방지가 조용히 어긋난다.
 */
class SystemConfigValueValidatorTest {

  private static final String MEMBER_ID_A = "0f8fad5b-d9cb-469f-a165-70867728950e";
  private static final String MEMBER_ID_B = "7c9e6679-7425-40de-944b-e07fc1f90ae7";

  @Test
  @DisplayName("앱 버전은 숫자.숫자(.숫자)만 받는다 — v·빌드번호·글자가 섞이면 앱이 버전을 못 읽어 업데이트 안내가 빠진다")
  void appVersion_acceptsNumbersOnly() {
    assertThat(SystemConfigValueValidator.check(ConfigKey.MIN_APP_VERSION_IOS, " 2.69.1 ").normalizedValue())
      .isEqualTo("2.69.1");
    assertThat(SystemConfigValueValidator.check(ConfigKey.LATEST_APP_VERSION_ANDROID, "2.70").isValid()).isTrue();
    for (String bad : List.of("v2.69.1", "2.69.1+329", "2", "2.x.1", "최신")) {
      ConfigValueCheck check = SystemConfigValueValidator.check(ConfigKey.MIN_APP_VERSION_ANDROID, bad);
      assertThat(check.isValid()).as(bad).isFalse();
      assertThat(check.rejectReason()).as(bad).contains("2.69.1");
    }
  }

  @Test
  @DisplayName("광고 단위 목록은 항목마다 형식을 보고 공백·중복을 정리한다 — 틀린 항목은 이유에 이름이 나온다")
  void adUnitList_checksEachItem() {
    ConfigValueCheck accepted = SystemConfigValueValidator.check(ConfigKey.AD_REWARD_ALLOWED_AD_UNITS,
      " 8857966475 , ca-app-pub-1234567890123456/6517734434 ,8857966475,");
    assertThat(accepted.normalizedValue()).isEqualTo("8857966475,ca-app-pub-1234567890123456/6517734434");

    ConfigValueCheck rejected = SystemConfigValueValidator.check(ConfigKey.AD_REWARD_ALLOWED_AD_UNITS, "8857966475,abc");
    assertThat(rejected.isValid()).isFalse();
    assertThat(rejected.rejectReason()).contains("abc");
    assertThat(SystemConfigValueValidator.check(ConfigKey.AD_REWARD_ALLOWED_AD_UNITS, " , ").isValid()).isFalse();
  }

  @Test
  @DisplayName("회원 ID 목록은 UUID 만 받고 비울 수 있다 — 비우지 못하면 마지막 시험 회원을 뺄 수 없다")
  void memberIdList_acceptsUuidsAndEmpty() {
    assertThat(SystemConfigValueValidator.check(ConfigKey.ADS_ALWAYS_SHOWN_MEMBER_IDS,
      MEMBER_ID_A + ", " + MEMBER_ID_B + "," + MEMBER_ID_A).normalizedValue())
      .isEqualTo(MEMBER_ID_A + "," + MEMBER_ID_B);
    assertThat(SystemConfigValueValidator.check(ConfigKey.ADS_ALWAYS_SHOWN_MEMBER_IDS, "").normalizedValue()).isEmpty();
    assertThat(SystemConfigValueValidator.check(ConfigKey.ADS_ALWAYS_SHOWN_MEMBER_IDS, "member-1").isValid()).isFalse();
  }

  @Test
  @DisplayName("비우면 앱 기본 동작인 키만 빈 값을 받는다 — 그 외 문자열 설정은 빈 값을 거부한다")
  void blankValue_onlyForBlankAllowedKeys() {
    for (ConfigKey key : List.of(ConfigKey.MIN_APP_VERSION_IOS, ConfigKey.IOS_STORE_URL, ConfigKey.ANDROID_STORE_URL)) {
      assertThat(SystemConfigValueValidator.check(key, " ").isValid()).as(key.name()).isTrue();
    }
    assertThat(SystemConfigValueValidator.check(ConfigKey.GEMINI_TEXT_MODEL, " ").isValid()).isFalse();
    assertThat(SystemConfigValueValidator.check(ConfigKey.AD_REWARD_ALLOWED_AD_UNITS, "").isValid()).isFalse();
  }

  @Test
  @DisplayName("사용 한도는 범위 밖(0·음수·너무 큰 값)을 거부하고 이유에 범위를 보인다 — 0 이면 기능이 멈춘다")
  void usageLimit_rejectsOutOfRange() {
    for (String bad : List.of("0", "-1", "601")) {
      ConfigValueCheck check = SystemConfigValueValidator.check(ConfigKey.ROUTINE_REQUEST_COOLDOWN_SECONDS, bad);
      assertThat(check.isValid()).as(bad).isFalse();
      assertThat(check.rejectReason()).as(bad).contains("1 ~ 600");
    }
    assertThat(SystemConfigValueValidator.check(ConfigKey.TTS_ON_DEMAND_MAX_CONCURRENT, "5").isValid()).isFalse();
    assertThat(SystemConfigValueValidator.check(ConfigKey.TTS_ON_DEMAND_MAX_CONCURRENT, "4").isValid()).isTrue();
  }

  @Test
  @DisplayName("사용 한도 기본값은 옮기기 전 코드 값과 같다 — 배포만으로 남용 방지 동작이 바뀌지 않는다")
  void usageLimitDefaults_matchFormerConstants() {
    Map<ConfigKey, String> formerValueByKey = Map.of(
      ConfigKey.ROUTINE_REQUEST_COOLDOWN_SECONDS, "30",
      ConfigKey.ROUTINE_STEP_IMAGE_LIMIT_PER_10_MINUTES, "10",
      ConfigKey.FEEDBACK_DAILY_LIMIT, "20",
      ConfigKey.PROFILE_INVITE_ISSUE_LIMIT_PER_10_MINUTES, "10",
      ConfigKey.PROFILE_INVITE_REDEEM_LIMIT_PER_10_MINUTES, "10",
      ConfigKey.LINK_REDEEM_LIMIT_PER_MINUTE, "10",
      ConfigKey.TTS_ON_DEMAND_MAX_CONCURRENT, "2",
      ConfigKey.TTS_FAILURE_COOLDOWN_MINUTES, "30");
    formerValueByKey.forEach((key, formerValue) ->
      assertThat(key.getDefaultValue()).as(key.name()).isEqualTo(formerValue));
  }

  @Test
  @DisplayName("값이 있는 기본값은 모두 자기 규칙을 통과한다 — 걸리면 기본값 복원이 실패한다")
  void nonEmptyDefaults_passOwnRules() {
    for (ConfigKey key : ConfigKey.values()) {
      if (key.getDefaultValue().isEmpty()) {
        continue;
      }
      ConfigValueCheck check = SystemConfigValueValidator.check(key, key.getDefaultValue());
      assertThat(check.isValid()).as(key.name() + " : " + check.rejectReason()).isTrue();
    }
  }
}
