package com.chuseok22.elumserver.common;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 패키지 의존 방향 규칙. 스프링을 띄우지 않고 소스의 import 줄만 훑는다.
 *
 * <p>common 은 모든 도메인이 쓰는 바닥이라 도메인을 알면 순환이 생긴다. 도메인끼리는 서로의 서비스를 거친다 —
 * 남의 repository 를 직접 쓰면 그 도메인의 스키마가 바뀔 때 함께 깨진다.
 */
class ArchitectureRulesTest {

  private static final Path SOURCE_ROOT = Path.of("src/main/java/com/chuseok22/elumserver");
  private static final String BASE = "com.chuseok22.elumserver.";
  private static final String REPOSITORY_PACKAGE = "infrastructure.repository.";
  private static final Pattern DOMAIN_IMPORT = Pattern.compile(
    "^import " + Pattern.quote(BASE) + "([a-z]+)\\.([\\w.]+);", Pattern.MULTILINE);

  /// common 안에서 도메인을 알아도 되는 곳과 그 이유. 앱 전체를 조립하는 설정만 둔다.
  private static final Map<String, String> COMMON_ALLOWED = Map.of(
    "common/infrastructure/config/SecurityConfig.java", "필터 체인을 조립하는 곳이라 점검 모드 필터를 직접 만든다"
  );

  @Test
  @DisplayName("common 은 도메인 패키지를 import 하지 않는다")
  void commonDoesNotDependOnDomains() throws IOException {
    List<String> violations = new ArrayList<>();
    for (Path file : javaFiles(SOURCE_ROOT.resolve("common"))) {
      String relative = SOURCE_ROOT.relativize(file).toString();
      if (COMMON_ALLOWED.containsKey(relative)) {
        continue;
      }
      Matcher m = DOMAIN_IMPORT.matcher(Files.readString(file));
      while (m.find()) {
        if (!m.group(1).equals("common")) {
          violations.add(relative + " -> " + m.group(1) + "." + m.group(2));
        }
      }
    }
    assertThat(violations).as("common 이 도메인을 알게 됐다. 그 클래스를 도메인 쪽으로 옮기거나 common 에 인터페이스를 둔다").isEmpty();
  }

  @Test
  @DisplayName("다른 도메인의 repository 직접 사용은 동결 목록보다 늘지 않는다")
  void crossDomainRepositoryUseDoesNotGrow() throws IOException {
    Set<String> actual = crossDomainRepositoryUses();
    Set<String> allowed = allowlist();

    Set<String> added = new TreeSet<>(actual);
    added.removeAll(allowed);
    assertThat(added).as("다른 도메인의 repository 대신 그 도메인의 서비스를 쓴다").isEmpty();

    Set<String> stale = new TreeSet<>(allowed);
    stale.removeAll(actual);
    assertThat(stale).as("더는 없는 사용이다. 동결 목록에서 이 줄을 지운다").isEmpty();
  }

  private static Set<String> crossDomainRepositoryUses() throws IOException {
    Set<String> uses = new TreeSet<>();
    for (Path file : javaFiles(SOURCE_ROOT)) {
      String domain = SOURCE_ROOT.relativize(file).getName(0).toString();
      String className = file.getFileName().toString().replace(".java", "");
      Matcher m = DOMAIN_IMPORT.matcher(Files.readString(file));
      while (m.find()) {
        String target = m.group(1);
        String rest = m.group(2);
        if (!target.equals(domain) && rest.startsWith(REPOSITORY_PACKAGE)) {
          // 내부 투영 타입(Repository.Row)을 import 해도 같은 repository 사용으로 센다
          String repository = rest.substring(REPOSITORY_PACKAGE.length()).split("\\.")[0];
          uses.add(domain + " " + className + " -> " + target + "." + repository);
        }
      }
    }
    return uses;
  }

  private static Set<String> allowlist() throws IOException {
    try (InputStream in = ArchitectureRulesTest.class.getResourceAsStream(
      "/architecture/cross-domain-repository-allowlist.txt")) {
      assertThat(in).as("동결 목록 파일이 없다").isNotNull();
      Set<String> lines = new TreeSet<>();
      for (String line : new String(in.readAllBytes(), StandardCharsets.UTF_8).split("\n")) {
        String trimmed = line.strip();
        if (!trimmed.isEmpty() && !trimmed.startsWith("#")) {
          lines.add(trimmed);
        }
      }
      return lines;
    }
  }

  private static List<Path> javaFiles(Path root) throws IOException {
    try (Stream<Path> walk = Files.walk(root)) {
      List<Path> files = walk.filter(p -> p.toString().endsWith(".java")).sorted().toList();
      assertThat(files).as("훑은 파일이 없으면 이 테스트가 아무것도 보지 않은 것이다").isNotEmpty();
      return files;
    }
  }
}
