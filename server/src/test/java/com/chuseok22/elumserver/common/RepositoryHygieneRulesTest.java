package com.chuseok22.elumserver.common;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;
import java.util.stream.Stream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.yaml.snakeyaml.Yaml;

/**
 * 레포 위생 규칙: 공통 설정 내용, 설정 파일 이름, 지운 이름의 재등장
 * 스프링을 띄우지 않고 파일만 읽음 (server 폴더 기준 상대 경로)
 */
class RepositoryHygieneRulesTest {

  private static final Path RESOURCES = Path.of("src/main/resources");
  private static final Path REPOSITORY_ROOT = Path.of("..");

  // 설정 파일 허용 이름 3개: 공통, 운영(시크릿 원본), 로컬 개발
  private static final Set<String> ALLOWED_CONFIG_FILES =
    Set.of("application.yml", "application-prod.yml", "application-dev.yml");

  // 공통 application.yml 에 값으로 두면 안 되는 키 끝 이름 (${...} 자리표시는 허용)
  private static final Pattern SECRET_KEY_NAME =
    Pattern.compile("(?i)(password|secret|secret-key|api-key|apikey|token|private-key|credentials?)$");

  // 지운 이름 목록: 옛 서버 주소, 덮어쓰기 설정 파일, 지운 시크릿
  private static final List<Pattern> REMOVED_NAMES = List.of(
    Pattern.compile("api\\.elum\\.chuseok22\\.com"),
    Pattern.compile("chuseok22\\.synology\\.me"),
    Pattern.compile("application-nas\\.ya?ml"),
    Pattern.compile("secrets\\.(SERVER_(HOST|USER|PASSWORD|PORT)|DOCKERHUB_(TOKEN|USERNAME)|APPLE_TEAM_ID"
      + "|CLIENT_ADMOB_ENV_STAGED|ENV_FILE|ENV|SECRETS_XCCONFIG)\\b")
  );

  // 검사 폴더 (레포 루트 기준). 지난 설계·회의·감사 문서는 기록이라 제외
  private static final List<String> SCANNED_ROOTS = List.of(
    ".github", "scripts", "client/lib", "client/tool", "client/android/app/src", "client/ios/Runner",
    "server/src/main", "server/tool", "server/Dockerfile", "server/build.gradle", "docs/setup"
  );

  private static final Set<String> SCANNED_EXTENSIONS = Set.of(
    "java", "kt", "kts", "gradle", "yml", "yaml", "json", "properties", "xml", "plist", "html", "js",
    "dart", "py", "sh", "md", "sql", "txt", "entitlements", "xcconfig"
  );

  @Test
  @DisplayName("공통 application.yml 은 활성 프로필과 비밀값을 정하지 않는다")
  void commonConfigHasNoActiveProfileOrSecrets() throws IOException {
    Map<String, Object> flattened = flatten(loadYaml(RESOURCES.resolve("application.yml")));

    assertThat(flattened).doesNotContainKey("spring.profiles.active");
    assertThat(flattened).containsEntry("spring.profiles.default", "dev");
    List<String> literalSecrets = flattened.entrySet().stream()
      .filter(entry -> SECRET_KEY_NAME.matcher(lastSegment(entry.getKey())).find())
      .filter(entry -> isLiteralValue(entry.getValue()))
      .map(Map.Entry::getKey)
      .toList();
    assertThat(literalSecrets).as("비밀값은 application-prod.yml(시크릿)·application-dev.yml(로컬)에만").isEmpty();
  }

  @Test
  @DisplayName("설정 파일은 application.yml · application-prod.yml · application-dev.yml 세 개뿐이다")
  void onlyThreeConfigFiles() throws IOException {
    try (Stream<Path> files = Files.list(RESOURCES)) {
      List<String> extraConfigFiles = files
        .map(path -> path.getFileName().toString())
        .filter(name -> name.matches("application(-[\\w.]+)?\\.(ya?ml|properties)"))
        .filter(name -> !ALLOWED_CONFIG_FILES.contains(name))
        .toList();
      assertThat(extraConfigFiles).as("덮어쓰기용 설정 파일·프로필 금지").isEmpty();
    }
  }

  @Test
  @DisplayName("지운 이름(옛 서버 주소, application-nas.yml, 지운 시크릿)이 다시 들어오지 않는다")
  void removedNamesDoNotReturn() throws IOException {
    assumeTrue(Files.exists(REPOSITORY_ROOT.resolve(".github")), "레포 루트 없음 (서버만 체크아웃)");
    List<String> violations = new ArrayList<>();
    for (String root : SCANNED_ROOTS) {
      Path start = REPOSITORY_ROOT.resolve(root);
      if (!Files.exists(start)) {
        continue;
      }
      try (Stream<Path> paths = Files.walk(start)) {
        for (Path path : paths.filter(Files::isRegularFile).filter(this::isScannedFile).toList()) {
          collectViolations(path, violations);
        }
      }
    }
    assertThat(violations).isEmpty();
  }

  // 파일 한 개: 줄마다 지운 이름 검사 > "경로:줄 : 이름"
  private void collectViolations(Path path, List<String> violations) throws IOException {
    List<String> lines = Files.readAllLines(path, StandardCharsets.UTF_8);
    for (int index = 0; index < lines.size(); index++) {
      for (Pattern removedName : REMOVED_NAMES) {
        if (removedName.matcher(lines.get(index)).find()) {
          violations.add(REPOSITORY_ROOT.relativize(path) + ":" + (index + 1) + " : " + removedName.pattern());
        }
      }
    }
  }

  // 확장자 검사 대상 + 빌드 산출물·외부 패키지 제외
  private boolean isScannedFile(Path path) {
    String normalized = path.toString().replace('\\', '/');
    if (normalized.contains("/build/") || normalized.contains("/.dart_tool/") || normalized.contains("/node_modules/")
      || normalized.contains("/Pods/") || normalized.contains("/vendor/")) {
      return false;
    }
    String name = path.getFileName().toString();
    if (name.equals("Dockerfile") || name.equals("build.gradle")) {
      return true;
    }
    int dot = name.lastIndexOf('.');
    return dot > 0 && SCANNED_EXTENSIONS.contains(name.substring(dot + 1));
  }

  private static Map<String, Object> loadYaml(Path path) throws IOException {
    try (InputStream input = Files.newInputStream(path)) {
      Map<String, Object> loaded = new Yaml().load(input);
      return loaded == null ? Map.of() : loaded;
    }
  }

  // 중첩 맵 > "a.b.c" 키
  @SuppressWarnings("unchecked")
  private static Map<String, Object> flatten(Map<String, Object> source) {
    Map<String, Object> flattened = new LinkedHashMap<>();
    source.forEach((key, value) -> {
      if (value instanceof Map<?, ?> nested) {
        flatten((Map<String, Object>) nested).forEach((childKey, childValue) ->
          flattened.put(key + "." + childKey, childValue));
      } else {
        flattened.put(String.valueOf(key), value);
      }
    });
    return flattened;
  }

  private static String lastSegment(String key) {
    return key.substring(key.lastIndexOf('.') + 1);
  }

  // 빈 값·${...} 자리표시가 아닌 실제 값인가
  private static boolean isLiteralValue(Object value) {
    if (value == null) {
      return false;
    }
    String text = String.valueOf(value).trim();
    return !text.isEmpty() && !text.startsWith("${");
  }
}
