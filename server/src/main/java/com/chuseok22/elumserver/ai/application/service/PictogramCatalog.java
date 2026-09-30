package com.chuseok22.elumserver.ai.application.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.io.InputStream;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

/**
 * 무료 픽토그램(Mulberry Symbols, CC BY-SA 4.0) 카탈로그 (#247).
 *
 * <p>서버는 SVG 를 서빙하지 않는다. SVG 는 앱에 번들되고, 서버는 카드에 {@code pictogramId}(SVG 파일명 stem)만
 * 저장한다. 이 카탈로그는 (1) AI 에게 "이 목록에서만 고르라"고 보여 줄 id 목록, (2) AI 가 돌려준 id 가
 * 실제로 있는지 검증하는 기준이다. 같은 파일을 앱도 복사해 동기 테스트를 하므로 수정하지 않는다.
 *
 * <p><b>파일이 없거나 깨져도 서버는 뜬다.</b> 빈 카탈로그(경고 로그)가 되고, 이때 {@link #resolve}는 항상
 * null 이다 — 카드는 그림 필드 없이 만들어진다. 픽토그램은 카드를 더 좋게 만들 뿐, 없어도 서비스가 죽으면 안 된다
 * (루트 CLAUDE.md 서비스 원칙 6).
 */
@Slf4j
@Component
public class PictogramCatalog {

  static final String RESOURCE_PATH = "pictograms/catalog.json";

  private final List<String> ids;
  private final Set<String> idSet;
  /// 카탈로그에 실제로 있는 폴백 id. 없으면 null — 그러면 resolve 도 폴백을 내지 않는다.
  private final String fallbackId;

  @Autowired
  public PictogramCatalog() {
    this(loadFromClasspath(RESOURCE_PATH));
  }

  private PictogramCatalog(Loaded loaded) {
    this(loaded.ids(), loaded.fallbackId());
  }

  /// 테스트·수동 구성용. 폴백이 목록에 없으면 폴백 없음으로 둔다.
  public PictogramCatalog(List<String> ids, String fallbackId) {
    this.ids = List.copyOf(ids);
    this.idSet = Set.copyOf(this.ids);
    if (fallbackId != null && !idSet.contains(fallbackId)) {
      log.warn("픽토그램 폴백 id 가 카탈로그에 없어 폴백 없이 동작한다: fallbackId={}", fallbackId);
      this.fallbackId = null;
    } else {
      this.fallbackId = fallbackId;
    }
  }

  /// 클래스패스의 다른 파일에서 읽는다(테스트용). 없거나 깨지면 빈 카탈로그.
  static PictogramCatalog fromClasspath(String path) {
    return new PictogramCatalog(loadFromClasspath(path));
  }

  public static PictogramCatalog empty() {
    return new PictogramCatalog(List.of(), null);
  }

  /// AI 요청에 실을 id 목록(파일 순서 그대로).
  public List<String> ids() {
    return ids;
  }

  public boolean isEmpty() {
    return ids.isEmpty();
  }

  public boolean contains(String id) {
    return id != null && idSet.contains(id);
  }

  /// 카탈로그에 있는 폴백 id. 카탈로그가 비었으면 null.
  public String fallbackId() {
    return fallbackId;
  }

  /**
   * AI 가 고른 id 를 저장할 값으로 바꾼다.
   *
   * <p>유효하면 그대로, null·빈 값·목록에 없는 값(환각)이면 폴백 id. 카드에는 항상 그림이 있어야 하므로
   * 개념이 없어도 비워 두지 않는다. 카탈로그가 비었으면 null.
   */
  public String resolve(String candidate) {
    if (candidate == null) {
      return fallbackId;
    }
    String trimmed = candidate.trim();
    if (idSet.contains(trimmed)) {
      return trimmed;
    }
    String matched = uniquePrefixMatch(trimmed);
    return matched != null ? matched : fallbackId;
  }

  /// 모델이 id 끝의 ",_to" 같은 꼬리를 잘라 내는 일이 실측으로 잦아(get_dressed_ → get_dressed_,_to),
  /// 접두어로 딱 하나만 걸리면 그 id 로 본다. 둘 이상이면 모호하니 고르지 않는다.
  private String uniquePrefixMatch(String prefix) {
    if (prefix.length() < 4) {
      return null;
    }
    String found = null;
    for (String id : ids) {
      if (id.startsWith(prefix)) {
        if (found != null) {
          return null;
        }
        found = id;
      }
    }
    return found;
  }

  private record Loaded(List<String> ids, String fallbackId) {

  }

  private static Loaded loadFromClasspath(String path) {
    ClassPathResource resource = new ClassPathResource(path);
    if (!resource.exists()) {
      log.warn("픽토그램 카탈로그 파일이 없어 빈 카탈로그로 시작한다 — 모든 카드의 pictogramId 는 null 이다: path={}",
        path);
      return new Loaded(List.of(), null);
    }
    try (InputStream in = resource.getInputStream()) {
      return parse(in);
    } catch (IOException | RuntimeException e) {
      log.warn("픽토그램 카탈로그를 읽지 못해 빈 카탈로그로 시작한다 — 모든 카드의 pictogramId 는 null 이다: path={}",
        path, e);
      return new Loaded(List.of(), null);
    }
  }

  private static Loaded parse(InputStream in) throws IOException {
    JsonNode root = new ObjectMapper().readTree(in);
    JsonNode symbols = root.path("symbols");
    if (!symbols.isArray()) {
      throw new IOException("symbols 배열이 없음");
    }
    // 중복은 한 번만 — 목록이 AI 에게 그대로 가므로 토큰을 아낀다. 무결성 테스트는 중복 자체를 막는다.
    Set<String> unique = new LinkedHashSet<>();
    for (JsonNode symbol : symbols) {
      String id = symbol.path("id").asText("");
      if (!id.isBlank()) {
        unique.add(id);
      }
    }
    String fallback = root.path("fallbackId").asText("");
    return new Loaded(List.copyOf(unique), fallback.isBlank() ? null : fallback);
  }
}
