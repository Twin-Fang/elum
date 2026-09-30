package com.chuseok22.elumserver.ai.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;

/**
 * 픽토그램 카탈로그 (#247). 앱이 같은 파일을 복사해 동기 테스트를 하므로, 파일 자체의 무결성을 여기서 지킨다.
 */
class PictogramCatalogTest {

  private static final int EXPECTED_SYMBOL_COUNT = 811;

  private JsonNode realCatalog() throws Exception {
    try (InputStream in = new ClassPathResource(PictogramCatalog.RESOURCE_PATH).getInputStream()) {
      return new ObjectMapper().readTree(in);
    }
  }

  // --- 카탈로그 파일 무결성 ---

  @Test
  @DisplayName("카탈로그는 811개이고 id 는 중복이 없다")
  void realCatalog_has811UniqueIds() throws Exception {
    List<String> ids = new ArrayList<>();
    realCatalog().path("symbols").forEach(symbol -> ids.add(symbol.path("id").asText()));

    assertThat(ids).hasSize(EXPECTED_SYMBOL_COUNT);
    assertThat(new HashSet<>(ids)).as("중복 id 없음").hasSameSizeAs(ids);
  }

  @Test
  @DisplayName("fallbackId 는 목록 안에 있다")
  void realCatalog_fallbackIsInList() throws Exception {
    JsonNode root = realCatalog();
    Set<String> ids = new HashSet<>();
    root.path("symbols").forEach(symbol -> ids.add(symbol.path("id").asText()));

    assertThat(root.path("fallbackId").asText()).isEqualTo("go_,_to");
    assertThat(ids).contains(root.path("fallbackId").asText());
  }

  @Test
  @DisplayName("id 에 경로 위험 문자(/ \\ 공백 따옴표)와 빈 값이 없다 — 앱이 id 로 SVG 경로를 만든다")
  void realCatalog_idsAreSafeForPaths() throws Exception {
    realCatalog().path("symbols").forEach(symbol -> {
      String id = symbol.path("id").asText();
      assertThat(id).as("id=%s", id).isNotBlank().doesNotContainPattern("[/\\\\\\s\"'`]").doesNotContain("..");
    });
  }

  @Test
  @DisplayName("서버가 뜰 때 실제 파일을 읽어 811개를 올리고 폴백은 go_,_to 다")
  void defaultConstructor_loadsRealCatalog() {
    PictogramCatalog catalog = new PictogramCatalog();

    assertThat(catalog.isEmpty()).isFalse();
    assertThat(catalog.ids()).hasSize(EXPECTED_SYMBOL_COUNT);
    assertThat(catalog.fallbackId()).isEqualTo("go_,_to");
    assertThat(catalog.contains("get_dressed_,_to")).isTrue();
  }

  // --- 로딩 실패는 서버를 죽이지 않는다 ---

  @Test
  @DisplayName("파일이 없으면 빈 카탈로그 — 던지지 않고 resolve 는 null 이다")
  void missingFile_givesEmptyCatalog() {
    PictogramCatalog catalog = PictogramCatalog.fromClasspath("pictograms/does-not-exist.json");

    assertThat(catalog.isEmpty()).isTrue();
    assertThat(catalog.fallbackId()).isNull();
    assertThat(catalog.resolve("brush_teeth")).isNull();
    assertThat(catalog.resolve(null)).isNull();
  }

  @Test
  @DisplayName("JSON 이 깨져 있어도 빈 카탈로그 — 서버는 뜬다")
  void brokenFile_givesEmptyCatalog() {
    PictogramCatalog catalog = PictogramCatalog.fromClasspath("pictograms/broken.json");

    assertThat(catalog.isEmpty()).isTrue();
    assertThat(catalog.resolve("a")).isNull();
  }

  @Test
  @DisplayName("폴백 id 가 목록에 없으면 폴백 없음으로 둔다 — 없는 그림 id 를 저장하지 않는다")
  void fallbackNotInList_isDropped() {
    PictogramCatalog catalog = PictogramCatalog.fromClasspath("pictograms/bad-fallback.json");

    assertThat(catalog.fallbackId()).isNull();
    assertThat(catalog.resolve("brush_teeth")).isEqualTo("brush_teeth");
    assertThat(catalog.resolve("unknown")).isNull();
  }

  @Test
  @DisplayName("모델이 꼬리(,_to)를 잘라 낸 id 는 접두어가 하나로 걸리면 살리고, 모호하면 폴백이다")
  void truncatedId_resolvesByUniquePrefix() {
    PictogramCatalog catalog = new PictogramCatalog(
      java.util.List.of("get_dressed_,_to", "go_outside_,_to", "go_,_to", "wash_face_,_to", "wash_hands_,_to"),
      "go_,_to");

    assertThat(catalog.resolve("get_dressed_")).isEqualTo("get_dressed_,_to");
    assertThat(catalog.resolve("go_outside_")).isEqualTo("go_outside_,_to");
    // wash_ 는 둘에 걸려 모호하다
    assertThat(catalog.resolve("wash_")).isEqualTo("go_,_to");
    // 너무 짧은 접두어는 우연히 걸릴 수 있어 쓰지 않는다
    assertThat(catalog.resolve("get")).isEqualTo("go_,_to");
  }

  @Test
  @DisplayName("중복 id 는 한 번만 올린다")
  void duplicateIds_areDeduplicated() {
    PictogramCatalog catalog = PictogramCatalog.fromClasspath("pictograms/small.json");

    assertThat(catalog.ids()).containsExactly("brush_teeth", "go_,_to");
  }

  // --- resolve ---

  private final PictogramCatalog small = new PictogramCatalog(List.of("brush_teeth", "go_,_to"), "go_,_to");

  @Test
  @DisplayName("유효한 id 는 그대로, 앞뒤 공백은 다듬는다")
  void resolve_validIsKept() {
    assertThat(small.resolve("brush_teeth")).isEqualTo("brush_teeth");
    assertThat(small.resolve("  brush_teeth ")).isEqualTo("brush_teeth");
  }

  @Test
  @DisplayName("null · 빈 값 · 목록에 없는 값(환각)은 폴백 id 로 바뀐다")
  void resolve_invalidFallsBack() {
    assertThat(small.resolve(null)).isEqualTo("go_,_to");
    assertThat(small.resolve("")).isEqualTo("go_,_to");
    assertThat(small.resolve("teleport_to_moon")).isEqualTo("go_,_to");
    assertThat(small.resolve("../etc/passwd")).isEqualTo("go_,_to");
  }
}
