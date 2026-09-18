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
 * 읽기 전용 서비스에서 쓰기를 하는데 트랜잭션을 열지 않은 자리를 찾는다.
 *
 * <p>클래스에 {@code @Transactional(readOnly = true)}가 걸려 있으면 메서드도 기본으로
 * 읽기 전용이 된다. 그 안에서 저장하면 <b>flush가 생략되어 조용히 사라진다.</b> 예외도
 * 나지 않고 로그도 정상으로 찍혀, 눌렀는데 아무 일도 안 일어나는 상태가 된다.
 *
 * <p>실제로 겪었다 — 관리자 Pro 발급이 이 상태로 배포됐다. 화면은 성공 메시지를 띄우고
 * 서버 로그도 "발급했습니다"라고 남겼는데 DB는 그대로였다. 단위 테스트도 컴파일도
 * 전부 통과한 뒤였다.
 *
 * <p>소스를 글로 훑는다. 스프링을 띄우지 않으므로 빠르고 단위 테스트 범위를 지킨다.
 */
class ReadOnlyTransactionWriteTest {

  private static final Path SOURCE_ROOT = Path.of("src/main/java");

  /// 클래스 선언 바로 위에 읽기 전용이 붙어 있는가
  private static final Pattern READ_ONLY_CLASS =
    Pattern.compile("@Transactional\\(readOnly = true\\)\\s*\\npublic class");

  /// 메서드 앞에 붙은 어노테이션 묶음과 메서드 이름
  private static final Pattern PUBLIC_METHOD =
    Pattern.compile("\\n(  (?:@\\w+(?:\\([^)]*\\))?\\s*\\n  )*)public [\\w<>,\\[\\] ]+ (\\w+)\\(");

  /// 저장을 일으킬 법한 호출
  private static final Pattern WRITE_CALL =
    Pattern.compile("\\.(save|saveAll|delete|deleteAll|deleteById|grantPro|revokePro)\\(");

  @Test
  @DisplayName("읽기 전용 서비스의 쓰기 메서드는 트랜잭션을 따로 열어야 한다")
  void writeMethodsInReadOnlyServiceDeclareTransaction() throws IOException {
    List<String> offenders = new ArrayList<>();

    try (Stream<Path> files = Files.walk(SOURCE_ROOT)) {
      for (Path file : files.filter(p -> p.toString().endsWith(".java")).toList()) {
        String source = Files.readString(file);
        if (!READ_ONLY_CLASS.matcher(source).find()) {
          continue;
        }
        Matcher method = PUBLIC_METHOD.matcher(source);
        while (method.find()) {
          String annotations = method.group(1);
          String name = method.group(2);
          if (annotations.contains("@Transactional")) {
            continue;
          }
          String body = bodyOf(source, method.end());
          if (WRITE_CALL.matcher(body).find()) {
            offenders.add("%s#%s".formatted(file.getFileName(), name));
          }
        }
      }
    }

    assertThat(offenders)
      .as("읽기 전용 클래스 안에서 저장하려면 @Transactional 을 붙여야 한다. "
        + "빠뜨리면 저장이 조용히 사라진다")
      .isEmpty();
  }

  private String bodyOf(String source, int from) {
    int end = source.indexOf("\n  }", from);
    return end > 0 ? source.substring(from, end) : source.substring(from);
  }
}
