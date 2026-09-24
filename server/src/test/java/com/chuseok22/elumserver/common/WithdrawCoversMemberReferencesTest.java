package com.chuseok22.elumserver.common;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 회원을 참조하는 표가 탈퇴와 완전 삭제에서 빠짐없이 다뤄지는지 확인한다.
 *
 * <p>탈퇴는 두 단계다 (이슈 #372).
 * <ul>
 *   <li><b>탈퇴</b>({@code MemberService#withdraw}) — 계정을 WITHDRAWN 으로 남기고, 재가입을 알아볼
 *       최소한만 보관한다. 그 밖의 표는 전부 즉시 지운다.</li>
 *   <li><b>완전 삭제</b>({@code WithdrawnMemberService#purge}) — 보관 기간이 지나거나 관리자가 요청을
 *       받으면 남긴 것까지 지운다.</li>
 * </ul>
 *
 * <p>표를 새로 만들면서 이 둘을 고치지 않으면 두 가지가 터진다. 탈퇴에서 빠지면 지운다고 약속한
 * 정보가 조용히 남는다. 완전 삭제에서 빠지면 계정 행이 외래키에 걸려 <b>삭제가 통째로 실패한다</b>
 * — 실제로 구독 표를 더하면서 탈퇴를 안 고쳐 탈퇴가 500 으로 죽은 채 배포됐다.
 *
 * <p>그래서 회원을 참조하는 표를 소스에서 모두 찾아, 탈퇴에서 지우는지 남기는지를 반드시 정하게 한다.
 * 남기는 표는 아래 목록에 이유와 함께 적는다. 목록에 없는 표는 탈퇴할 때 지워야 한다.
 *
 * <p>소스를 글로 훑는다. 스프링도 DB도 띄우지 않는다.
 */
class WithdrawCoversMemberReferencesTest {

  private static final Path SOURCE_ROOT = Path.of("src/main/java");
  private static final Path MEMBER_SERVICE = SOURCE_ROOT.resolve(
    "com/chuseok22/elumserver/member/application/service/MemberService.java");
  private static final Path WITHDRAWN_MEMBER_SERVICE = SOURCE_ROOT.resolve(
    "com/chuseok22/elumserver/member/application/service/WithdrawnMemberService.java");
  /// 탈퇴와 완전 삭제는 이룸이 정리를 "나가기"(GuardianshipService.leaveAll)에 맡긴다 (다중 보호자 4-3, #360).
  /// 관계·일과·이룸이·이룸이 휴대폰은 거기서 지워지므로 두 곳을 함께 본다.
  private static final Path GUARDIANSHIP_SERVICE = SOURCE_ROOT.resolve(
    "com/chuseok22/elumserver/member/application/service/GuardianshipService.java");

  /// 탈퇴해도 보관 기간 동안 남기는 표와 그 이유. 여기에 없는 표는 탈퇴할 때 지운다 (최소 보관).
  private static final Map<String, String> RETAINED_ON_WITHDRAW = Map.of(
    "AuthIdentity", "같은 소셜 계정이 다시 오면 이 행으로 이전 계정을 찾는다 — 이메일은 비운다",
    "AiCallLog", "하루·주간 한도를 잇는다 — 식별자를 떼면 재가입한 계정의 사용량이 0 이 된다"
  );

  @Test
  @DisplayName("탈퇴는 남기기로 정한 표 말고는 회원을 참조하는 표를 모두 지운다")
  void withdrawDeletesEveryReferenceExceptRetained() throws IOException {
    String withdraw = withdrawWithLeaving();
    List<String> uncovered = new ArrayList<>();

    for (String entity : entitiesReferencingMember()) {
      if (RETAINED_ON_WITHDRAW.containsKey(entity)) {
        continue;
      }
      String deleteCall = repositoryOf(entity) + ".delete";
      if (!withdraw.contains(deleteCall)) {
        uncovered.add("%s (%s 호출이 없다)".formatted(entity, deleteCall));
      }
    }

    assertThat(uncovered)
      .as("탈퇴에서 지우지도 않고 남긴다고 정하지도 않은 표다. 지우거나, 남길 이유를 "
        + "RETAINED_ON_WITHDRAW 에 적는다")
      .isEmpty();
  }

  @Test
  @DisplayName("탈퇴는 남기기로 정한 표를 지우거나 회원 식별자를 떼지 않는다")
  void withdrawKeepsRetainedTables() throws IOException {
    String withdraw = withdrawWithLeaving();
    List<String> violations = new ArrayList<>();

    for (String entity : RETAINED_ON_WITHDRAW.keySet()) {
      String repository = repositoryOf(entity);
      for (String forbidden : List.of(repository + ".delete", repository + ".detach")) {
        if (withdraw.contains(forbidden)) {
          violations.add("%s — %s".formatted(forbidden, RETAINED_ON_WITHDRAW.get(entity)));
        }
      }
    }
    // 계정 행이 사라지면 재가입을 알아볼 기준이 없다.
    if (withdraw.contains("memberRepository.delete")) {
      violations.add("memberRepository.delete — 계정 행은 WITHDRAWN 으로 남긴다");
    }

    assertThat(violations)
      .as("탈퇴 즉시 지우면 같은 소셜 계정으로 재가입해 무료 사용량을 0 부터 다시 받는다")
      .isEmpty();
  }

  @Test
  @DisplayName("남기기로 정한 표는 실제로 회원을 참조하는 표여야 한다")
  void retainedTablesStillReferenceMember() throws IOException {
    // 표 이름이 바뀌었는데 목록만 남아 있으면, 그 표는 검사 없이 탈퇴에서 빠진다.
    assertThat(entitiesReferencingMember()).containsAll(RETAINED_ON_WITHDRAW.keySet());
  }

  @Test
  @DisplayName("완전 삭제는 회원을 참조하는 표를 모두 정리한 뒤 계정 행을 지운다")
  void purgeCleansEveryMemberReference() throws IOException {
    String purge = methodBody(WITHDRAWN_MEMBER_SERVICE, "public void purge(");
    assertThat(purge).as("완전 삭제도 나가기 규칙으로 이룸이를 정리한다").contains("guardianshipService.leaveAll(");
    purge = purge + guardianshipSource();
    List<String> uncovered = new ArrayList<>();

    for (String entity : entitiesReferencingMember()) {
      // 지우든(delete…) 식별자를 떼든(detach…) 이 표의 저장소를 불러야 한다.
      String repositoryCall = repositoryOf(entity) + ".";
      if (!purge.contains(repositoryCall)) {
        uncovered.add("%s (%s 호출이 없다)".formatted(entity, repositoryCall));
      }
    }

    assertThat(uncovered)
      .as("외래키가 걸린 표가 남으면 계정 삭제가 실패하고, 외래키 없는 표가 남으면 "
        + "보관 기간이 지난 뒤에도 누구 것인지가 남는다")
      .isEmpty();
    assertThat(purge).contains("memberRepository.delete");
  }

  /// member_id 로 회원을 참조하는 엔티티 이름들. 외래키(JoinColumn)와 식별자 컬럼(Column) 둘 다 본다.
  private List<String> entitiesReferencingMember() throws IOException {
    List<String> entities = new ArrayList<>();
    try (Stream<Path> files = Files.walk(SOURCE_ROOT)) {
      for (Path file : files.filter(p -> p.toString().endsWith(".java")).toList()) {
        String source = Files.readString(file);
        boolean isEntity = source.contains("@Entity");
        // routine.created_by 도 member 를 외래키로 잡는다 (V25). 남기면 완전 삭제의 계정 삭제가 막힌다.
        boolean referencesMember = source.contains("@JoinColumn(name = \"member_id\"")
          || source.contains("@Column(name = \"member_id\"")
          || source.contains("@Column(name = \"created_by\"");
        if (isEntity && referencesMember) {
          entities.add(file.getFileName().toString().replace(".java", ""));
        }
      }
    }
    assertThat(entities)
      .as("검사가 헛돌지 않도록 — 회원을 참조하는 엔티티가 하나도 안 잡히면 규칙이 깨진 것이다")
      .isNotEmpty();
    return entities;
  }

  /// 탈퇴 본문 + 탈퇴가 부르는 나가기. 탈퇴가 나가기를 부르지 않으면 나가기 쪽 지우기는 세지 않는다.
  private static String withdrawWithLeaving() throws IOException {
    String withdraw = methodBody(MEMBER_SERVICE, "public void withdraw(");
    assertThat(withdraw).as("탈퇴는 나가기 규칙으로 이룸이를 정리한다").contains("guardianshipService.leaveAll(");
    return withdraw + guardianshipSource();
  }

  /// 나가기 서비스 전체(주석 뺀). 나가기·마지막 보호자 정리가 private 도우미에 나뉘어 있어 파일로 본다.
  private static String guardianshipSource() throws IOException {
    return Files.readString(GUARDIANSHIP_SERVICE).replaceAll("//[^\n]*", "");
  }

  /// Profile → profileRepository, AiCallLog → aiCallLogRepository
  private static String repositoryOf(String entity) {
    return Character.toLowerCase(entity.charAt(0)) + entity.substring(1) + "Repository";
  }

  /// 메서드 본문. 줄 주석은 뺀다 — 주석에 적힌 호출 이름이 검사를 속이지 않게 한다.
  private static String methodBody(Path file, String signature) throws IOException {
    String source = Files.readString(file);
    int start = source.indexOf(signature);
    assertThat(start).as("%s 에서 %s 를 찾지 못했다 — 이름이 바뀌었다면 검사도 고쳐야 한다",
      file.getFileName(), signature).isGreaterThan(0);
    int end = source.indexOf("\n  }", start);
    String body = source.substring(start, end > 0 ? end : source.length());
    return body.replaceAll("//[^\n]*", "");
  }
}
