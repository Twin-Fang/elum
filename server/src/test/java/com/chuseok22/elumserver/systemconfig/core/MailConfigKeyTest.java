package com.chuseok22.elumserver.systemconfig.core;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Arrays;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 신고 메일 설정이 관리자 화면에 한 묶음으로 나오고, 배포만으로는 메일이 나가지 않으며, 비밀번호는 암호화 대상이다.
class MailConfigKeyTest {

  @Test
  @DisplayName("신고 메일 그룹은 6개 키이고 켜기는 기본 꺼짐, 비밀번호만 SECRET")
  void mailGroup_hasSixKeys_disabledByDefault_passwordIsSecret() {
    List<ConfigKey> mailKeys = Arrays.stream(ConfigKey.values()).filter(key -> key.getGroup() == ConfigGroup.MAIL).toList();

    assertThat(mailKeys).containsExactly(
      ConfigKey.TALK_REPORT_MAIL_ENABLED, ConfigKey.TALK_REPORT_MAIL_TO, ConfigKey.MAIL_SMTP_HOST,
      ConfigKey.MAIL_SMTP_PORT, ConfigKey.MAIL_SMTP_USERNAME, ConfigKey.MAIL_SMTP_PASSWORD);
    assertThat(ConfigKey.TALK_REPORT_MAIL_ENABLED.getValueType()).isEqualTo(ConfigValueType.BOOLEAN);
    assertThat(ConfigKey.TALK_REPORT_MAIL_ENABLED.getDefaultValue()).isEqualTo("false");
    assertThat(ConfigKey.MAIL_SMTP_PORT.getDefaultValue()).isEqualTo("587");
    assertThat(mailKeys.stream().filter(key -> key.getValueType() == ConfigValueType.SECRET).toList())
      .containsExactly(ConfigKey.MAIL_SMTP_PASSWORD);
    assertThat(ConfigKey.MAIL_SMTP_PASSWORD.getDefaultValue()).isEmpty();
  }
}
