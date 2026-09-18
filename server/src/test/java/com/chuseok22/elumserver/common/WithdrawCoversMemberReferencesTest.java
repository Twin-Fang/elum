package com.chuseok22.elumserver.common;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Stream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 회원을 외래키로 참조하는 표가 탈퇴 로직에서 전부 정리되는지 확인한다.
 *
 * <p>참조가 하나라도 남으면 계정 삭제가 제약에 걸려 <b>탈퇴가 통째로 실패한다.</b>
 * 한 기능이 덜 되는 게 아니라 사용자가 계정을 지울 수 없게 된다.
 *
 * <p>실제로 겪었다 — 구독 표를 새로 만들면서 탈퇴 로직을 고치지 않았고, 그대로
 * 배포돼 탈퇴가 500으로 죽었다. 표를 더할 때마다 반복될 수 있는 실수라 검사로 굳힌다.
 *
 * <p>소스를 글로 훑는다. 스프링도 DB도 띄우지 않는다.
 */
class WithdrawCoversMemberReferencesTest {

  private static final Path SOURCE_ROOT = Path.of("src/main/java");
  private static final Path MEMBER_SERVICE = SOURCE_ROOT.resolve(
    "com/chuseok22/elumserver/member/application/service/MemberService.java");

  @Test
  @DisplayName("회원을 외래키로 참조하는 표는 탈퇴할 때 모두 정리되어야 한다")
  void withdrawCleansEveryMemberReference() throws IOException {
    String withdrawBody = withdrawBody();
    List<String> uncovered = new ArrayList<>();

    for (String entity : entitiesReferencingMember()) {
      // Profile → profileRepository, Subscription → subscriptionRepository
      String repositoryCall = Character.toLowerCase(entity.charAt(0)) + entity.substring(1)
        + "Repository";
      if (!withdrawBody.contains(repositoryCall)) {
        uncovered.add("%s (%s 호출이 없다)".formatted(entity, repositoryCall));
      }
    }

    assertThat(uncovered)
      .as("회원을 외래키로 참조하는 표가 남아 있으면 계정이 지워지지 않아 탈퇴가 실패한다")
      .isEmpty();
  }

  /// member_id 를 외래키(JoinColumn)로 잡은 엔티티 이름들
  private List<String> entitiesReferencingMember() throws IOException {
    List<String> entities = new ArrayList<>();
    try (Stream<Path> files = Files.walk(SOURCE_ROOT)) {
      for (Path file : files.filter(p -> p.toString().endsWith(".java")).toList()) {
        String source = Files.readString(file);
        boolean isEntity = source.contains("@Entity");
        boolean joinsMember = source.contains("@JoinColumn(name = \"member_id\"");
        if (isEntity && joinsMember) {
          entities.add(file.getFileName().toString().replace(".java", ""));
        }
      }
    }
    assertThat(entities)
      .as("검사가 헛돌지 않도록 — 회원을 참조하는 엔티티가 하나도 안 잡히면 규칙이 깨진 것이다")
      .isNotEmpty();
    return entities;
  }

  private String withdrawBody() throws IOException {
    String source = Files.readString(MEMBER_SERVICE);
    int start = source.indexOf("public void withdraw(");
    assertThat(start).as("withdraw 메서드를 찾지 못했다 — 이름이 바뀌었다면 검사도 고쳐야 한다")
      .isGreaterThan(0);
    int end = source.indexOf("\n  }", start);
    return source.substring(start, end > 0 ? end : source.length());
  }
}
