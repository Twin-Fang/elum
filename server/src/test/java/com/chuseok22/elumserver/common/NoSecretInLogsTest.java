package com.chuseok22.elumserver.common;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 로그에 비밀 값이 들어가지 않는지 소스를 훑는다 (이슈 #397).
 *
 * <p>Gemini 그림 호출이 {@code apiKey={}} 로 API 키 원문을 info 로그에 남겼고, 운영 로그 파일과
 * 관리자 서버 로그 화면에 그대로 드러났다. 로그 호출은 여러 줄에 걸치므로 {@code log.xxx(} 부터
 * 짝이 맞는 닫는 괄호까지를 한 덩이로 보고, 그 안에서 키·시크릿을 꺼내는 호출을 찾는다.
 */
class NoSecretInLogsTest {

  private static final Pattern LOG_CALL = Pattern.compile("\\blog\\.(trace|debug|info|warn|error)\\(");
  private static final Pattern SECRET_ACCESS = Pattern.compile(
    "(?i)\\.(apiKey|secret|masterKey|password|clientSecret|getApiKey|getSecret|getPassword)\\(\\)");

  @Test
  @DisplayName("로그 호출 인자에 API 키·시크릿·비밀번호를 꺼내 넣지 않는다 (이슈 #397)")
  void logCalls_doNotIncludeSecrets() throws IOException {
    List<String> offenders = new ArrayList<>();
    try (Stream<Path> files = Files.walk(Path.of("src/main/java"))) {
      for (Path file : files.filter(p -> p.toString().endsWith(".java")).toList()) {
        String src = Files.readString(file);
        Matcher m = LOG_CALL.matcher(src);
        while (m.find()) {
          String call = balancedCall(src, m.end() - 1);
          if (SECRET_ACCESS.matcher(call).find()) {
            offenders.add(file + " : " + call.replaceAll("\\s+", " "));
          }
        }
      }
    }
    assertThat(offenders).as("로그에 비밀 값이 들어간다").isEmpty();
  }

  /** 여는 괄호 위치부터 짝이 맞는 닫는 괄호까지. 문자열 안의 괄호는 세지 않는다. */
  private static String balancedCall(String src, int openIdx) {
    int depth = 0;
    boolean inString = false;
    for (int i = openIdx; i < src.length(); i++) {
      char c = src.charAt(i);
      if (c == '"' && src.charAt(i - 1) != '\\') {
        inString = !inString;
      } else if (!inString && c == '(') {
        depth++;
      } else if (!inString && c == ')' && --depth == 0) {
        return src.substring(openIdx, i + 1);
      }
    }
    return src.substring(openIdx);
  }
}
