package com.chuseok22.elumserver.common;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 새 코드는 {@code profile.member_id}(옛 서버 호환용 대표 보호자)를 읽지 않는다 (다중 보호자 명세 5장).
 *
 * <p>4단계(#364, V32)가 이 컬럼을 지웠다. 읽는 곳이 하나라도 남으면 운영(validate)이 뜨지 않거나 쿼리가 터진다.
 * 허용 목록은 비었고 늘리지 않는다. 엔티티 필드가 없어 자바 코드는 컴파일에서 막히지만, 네이티브 SQL 문자열과
 * 옛 접근 이름은 컴파일이 못 잡아 글로 막는다.
 */
class ProfileOwnerColumnReadsTest {

  private static final Pattern OWNER_READ = Pattern.compile(
    "getProfile\\(\\)\\.getMember\\(\\)|\\bp\\.member\\b|\\br\\.profile\\.member\\b"
      + "|ProfileMemberId|findFirstByMemberIdOrderByCreatedAtAsc|findAllByMemberIdIn\\("
      + "|\\bp\\.member_id\\b|profile\\.member_id");

  /** 허용 목록은 비었다 — 마지막 두 곳(관리자 일과 화면)은 created_by 로 옮겼다. */
  private static final Set<String> ALLOWED = Set.of();

  @Test
  @DisplayName("대표 보호자 컬럼을 읽는 코드는 없다")
  void nobodyReadsProfileOwnerOutsideAllowList() throws IOException {
    List<String> offenders = new ArrayList<>();
    try (Stream<Path> files = Files.walk(Path.of("src/main/java"))) {
      for (Path file : files.filter(p -> p.toString().endsWith(".java")).toList()) {
        if (ALLOWED.contains(file.getFileName().toString())) {
          continue;
        }
        // 주석은 빼고 본다 — 설명 문장이 검사를 속이지 않게.
        String code = Files.readAllLines(file).stream()
          .filter(line -> !line.trim().startsWith("*") && !line.trim().startsWith("//") && !line.trim().startsWith("///"))
          .collect(Collectors.joining("\n"));
        if (OWNER_READ.matcher(code).find()) {
          offenders.add(file.getFileName().toString());
        }
      }
    }
    assertThat(offenders).as("관계(profile_guardian)나 created_by 로 읽는다").isEmpty();
  }
}
