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
 * <p>4단계(#364, 명세의 V23)가 이 컬럼을 지운다. 읽는 곳이 하나라도 남으면 그 배포에서 터진다. 허용 목록은
 * 그 전에 옮겨야 할 곳이다 — 줄어들기만 해야 한다.
 */
class ProfileOwnerColumnReadsTest {

  private static final Pattern OWNER_READ = Pattern.compile(
    "getProfile\\(\\)\\.getMember\\(\\)|\\bp\\.member\\b|\\br\\.profile\\.member\\b"
      + "|ProfileMemberId|findFirstByMemberIdOrderByCreatedAtAsc|findAllByMemberIdIn\\(");

  /** 관리자 일과 화면의 "보호자" 칸. 1단계 동안은 대표 보호자를 계속 채우므로 동작한다. 4단계(#364) 전에 created_by 로 옮긴다. */
  private static final Set<String> ALLOWED_UNTIL_PHASE4 = Set.of(
    "AdminRoutineResponse.java", "AdminRoutineDetailResponse.java");

  @Test
  @DisplayName("대표 보호자 컬럼을 읽는 코드는 허용 목록(4단계 전 할 일) 밖에 없다")
  void nobodyReadsProfileOwnerOutsideAllowList() throws IOException {
    List<String> offenders = new ArrayList<>();
    try (Stream<Path> files = Files.walk(Path.of("src/main/java"))) {
      for (Path file : files.filter(p -> p.toString().endsWith(".java")).toList()) {
        if (ALLOWED_UNTIL_PHASE4.contains(file.getFileName().toString())) {
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
