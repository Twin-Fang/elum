package com.chuseok22.elumserver.expertroutine.infrastructure;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.ai.application.service.PictogramCatalog;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 시드 초안: 없는 픽토그램 id 로 그림이 비거나, 검수 전 콘텐츠가 배포와 함께 앱에 나가는 것을 막는다.
class ExpertRoutineSeedMigrationTest {

  private static final Path MIGRATION = Path.of("src/main/resources/db/migration/V65__create_expert_routine_tables.sql");
  // 카드 줄: (id, 일과 id, 순서, '문장', '픽토그램 id')
  private static final Pattern STEP_ROW = Pattern.compile("\\('[^']+', '[^']+', \\d+, '[^']+', '([^']+)'\\)");
  // 일과 줄의 검수 상태·공개 칸: 'DRAFT', '메모', FALSE
  private static final Pattern ROUTINE_FLAGS = Pattern.compile("'(DRAFT|REVIEWED)', '[^']*', (TRUE|FALSE),");

  @Test
  @DisplayName("시드 카드의 픽토그램 id 는 전부 서버 카탈로그(앱과 같은 원본)에 있다")
  void seedPictogramsExistInCatalog() throws IOException {
    String sql = Files.readString(MIGRATION, StandardCharsets.UTF_8);
    PictogramCatalog catalog = new PictogramCatalog();
    List<String> ids = new ArrayList<>();
    Matcher matcher = STEP_ROW.matcher(sql);
    while (matcher.find()) {
      ids.add(matcher.group(1));
    }

    assertThat(ids).hasSizeGreaterThanOrEqualTo(15);
    assertThat(ids).allSatisfy(id -> assertThat(catalog.contains(id)).as(id).isTrue());
  }

  @Test
  @DisplayName("시드 일과 3~5개는 모두 초안 · 숨김이다 (전문가 검수 전)")
  void seedRoutinesAreUnpublishedDrafts() throws IOException {
    String sql = Files.readString(MIGRATION, StandardCharsets.UTF_8);
    Matcher matcher = ROUTINE_FLAGS.matcher(sql);
    int count = 0;
    while (matcher.find()) {
      count++;
      assertThat(matcher.group(1)).isEqualTo("DRAFT");
      assertThat(matcher.group(2)).isEqualTo("FALSE");
    }
    assertThat(count).isBetween(3, 5);
  }
}
