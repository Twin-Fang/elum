package com.chuseok22.elumserver.common;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.link.core.LinkCode;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.ImageStyle;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutineExampleCategory;
import com.chuseok22.elumserver.talk.core.TalkCategory;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.function.Function;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 스택 간 계약: 마이그레이션 번호 중복 없음, 서버 enum·상수 <-> 앱(client/lib) 값 일치
 * 앱 테스트가 없어 서버 쪽에서 앱 소스를 글자로 읽어 대조 (모노레포가 아니면 건너뜀)
 */
class CrossStackContractTest {

  // 테스트는 server/ 에서 돈다
  private static final Path MIGRATION_DIR = Path.of("src/main/resources/db/migration");
  private static final Path CLIENT_LIB = Path.of("../client/lib");

  // Flyway 파일명: V{버전}__{설명}.sql
  private static final Pattern MIGRATION_VERSION = Pattern.compile("^V(\\d+)__.+\\.sql$");
  // 다트 enum 항목: name('API_VALUE' ...
  private static final Pattern DART_ENUM_VALUE = Pattern.compile("^\\s*\\w+\\('([A-Z0-9_]*)'", Pattern.MULTILINE);

  @Test
  @DisplayName("마이그레이션 버전이 겹치지 않는다 — 같은 번호 둘이면 운영 서버가 기동하지 못한다")
  void migrationVersionsAreUnique() throws IOException {
    try (Stream<Path> files = Files.list(MIGRATION_DIR)) {
      Map<String, List<String>> byVersion = files
        .map(path -> path.getFileName().toString())
        .map(MIGRATION_VERSION::matcher)
        .filter(Matcher::matches)
        .collect(Collectors.groupingBy(m -> m.group(1), Collectors.mapping(m -> m.group(0), Collectors.toList())));

      assertThat(byVersion.entrySet().stream().filter(e -> e.getValue().size() > 1).map(Map.Entry::getValue))
        .as("같은 버전의 마이그레이션")
        .isEmpty();
    }
  }

  @Test
  @DisplayName("에러 코드 이름이 앱과 같다 — 다르면 앱이 실패 이유를 못 알아본다")
  void errorCodesMatchClient() throws IOException {
    assertSameValues("core/network/server_error_code.dart", ErrorCode.values(), ErrorCode::name);
  }

  @Test
  @DisplayName("온보딩·카드 enum 값이 앱과 같다 — 다르면 저장이 400 으로 거절된다")
  void sharedEnumsMatchClient() throws IOException {
    assertSameValues("shared/models/support_goal.dart", SupportGoal.values(), SupportGoal::name);
    assertSameValues("shared/models/character.dart", CharacterType.values(), CharacterType::name);
    assertSameValues("features/onboarding/domain/image_style.dart", ImageStyle.values(), ImageStyle::name);
    assertSameValues("shared/models/routine_example_category.dart", RoutineExampleCategory.values(),
      RoutineExampleCategory::name);
    assertSameValues("features/guardian/domain/routine_template.dart", TalkCategory.values(), Enum::name);
  }

  @Test
  @DisplayName("연결 암호 글자 집합·길이가 앱과 같다 — 다르면 이룸이 기기가 맞는 암호를 거절한다")
  void linkCodeMatchesClient() throws IOException {
    String dart = readClient("features/link/domain/link_code.dart");

    assertThat(dart).contains("static const alphabet = '" + LinkCode.ALPHABET + "'");
    assertThat(dart).contains("static const length = " + LinkCode.LENGTH + ";");
  }

  @Test
  @DisplayName("의견 기록 구역 표지가 앱과 같다 — 다르면 관리자 화면이 오류 건수를 0으로 센다")
  void feedbackSectionMarkersMatchClient() throws IOException {
    String dart = readClient("core/logger/app_log_buffer.dart");

    assertThat(dart).contains("errorSectionTitle = '== 최근 오류 =='");
    assertThat(dart).contains("logSectionTitle = '== 기록 =='");
  }

  /**
   * 서버 enum 이름 집합 <-> 다트 enum 항목 값 집합 (빈 값 unknown 제외)
   */
  private static <E> void assertSameValues(String clientFile, E[] serverValues, Function<E, String> nameOf)
    throws IOException {
    Set<String> server = Arrays.stream(serverValues).map(nameOf).collect(Collectors.toCollection(TreeSet::new));
    Set<String> client = new TreeSet<>();
    Matcher matcher = DART_ENUM_VALUE.matcher(readClient(clientFile));
    while (matcher.find()) {
      if (!matcher.group(1).isEmpty()) {
        client.add(matcher.group(1));
      }
    }
    assertThat(client).as(clientFile).isEqualTo(server);
  }

  private static String readClient(String relativePath) throws IOException {
    Path path = CLIENT_LIB.resolve(relativePath);
    assumeTrue(Files.exists(path), "앱 소스 없음 (서버만 체크아웃): " + path);
    return Files.readString(path, StandardCharsets.UTF_8);
  }
}
