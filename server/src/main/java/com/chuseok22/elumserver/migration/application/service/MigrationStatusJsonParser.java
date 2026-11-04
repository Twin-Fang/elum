package com.chuseok22.elumserver.migration.application.service;

import com.chuseok22.elumserver.common.infrastructure.json.DefaultJsonMapper;
import com.chuseok22.elumserver.migration.core.MigrationSyncReport;
import com.chuseok22.elumserver.migration.core.MigrationSyncResult;
import com.chuseok22.elumserver.migration.core.MigrationVerifyReport;
import com.chuseok22.elumserver.migration.core.MigrationVerifyReport.Difference;
import com.chuseok22.elumserver.migration.core.MigrationVerifyResult;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.List;

/**
 * NAS 상태 JSON 2종 > 결과 record (#1062): 객체 확인 > 칸별 형식 확인 > 시각은 이 서버 시간대로
 * 없는 칸은 null, 형식이 틀린 칸은 MalformedStatusException (화면에서 "읽을 수 없어요")
 */
final class MigrationStatusJsonParser {

  // 화면에 보일 로그 꼬리 최대 줄 수·한 줄 최대 길이 (자)
  static final int MAX_LOG_TAIL_LINES = 200;
  static final int MAX_LOG_LINE_LENGTH = 500;
  // 차이 표 최대 줄 수
  static final int MAX_DIFFERENCE_ROWS = 100;
  private static final String TRUNCATED_SUFFIX = "…";

  private MigrationStatusJsonParser() {
  }

  /// 상태 JSON 형식이 약속과 다름 (깨진 JSON, 객체 아님, 칸 형식 다름)
  static final class MalformedStatusException extends Exception {

    MalformedStatusException(String reason) {
      super(reason);
    }

    MalformedStatusException(String reason, Throwable cause) {
      super(reason, cause);
    }
  }

  /// sync-status.json 본문 > 동기화 결과
  static MigrationSyncReport parseSyncStatus(String json, ZoneId zone) throws MalformedStatusException {
    JsonNode root = readObject(json);
    String rawResult = textOrNull(root, "result");
    return new MigrationSyncReport(
      dateTimeOrNull(root, "startedAt", zone),
      dateTimeOrNull(root, "finishedAt", zone),
      MigrationSyncResult.fromCode(rawResult),
      rawResult,
      longOrNull(root, "durationSeconds"),
      textOrNull(root, "trigger"),
      textOrNull(root, "message"),
      logTailOf(root)
    );
  }

  /// verify-status.json 본문 > 정합성 검사 결과
  static MigrationVerifyReport parseVerifyStatus(String json, ZoneId zone) throws MalformedStatusException {
    JsonNode root = readObject(json);
    String rawResult = textOrNull(root, "result");
    Long differenceCount = longOrNull(root, "differenceCount");
    return new MigrationVerifyReport(
      dateTimeOrNull(root, "checkedAt", zone),
      MigrationVerifyResult.fromCode(rawResult),
      rawResult,
      differenceCount == null ? null : Math.toIntExact(Math.min(differenceCount, Integer.MAX_VALUE)),
      differencesOf(root),
      textOrNull(root, "files"),
      booleanOrNull(root, "isLiveAllowed")
    );
  }

  private static JsonNode readObject(String json) throws MalformedStatusException {
    JsonNode root;
    try {
      root = DefaultJsonMapper.SHARED.readTree(json);
    } catch (JsonProcessingException e) {
      throw new MalformedStatusException("invalid json", e);
    }
    if (root == null || !root.isObject()) {
      throw new MalformedStatusException("root is not an object");
    }
    return root;
  }

  private static String textOrNull(JsonNode parent, String field) throws MalformedStatusException {
    JsonNode node = parent.get(field);
    if (node == null || node.isNull()) {
      return null;
    }
    if (!node.isTextual()) {
      throw new MalformedStatusException(field + " is not text");
    }
    return node.asText();
  }

  private static Long longOrNull(JsonNode parent, String field) throws MalformedStatusException {
    JsonNode node = parent.get(field);
    if (node == null || node.isNull()) {
      return null;
    }
    if (!node.isIntegralNumber() || !node.canConvertToLong()) {
      throw new MalformedStatusException(field + " is not an integer");
    }
    return node.asLong();
  }

  private static Boolean booleanOrNull(JsonNode parent, String field) throws MalformedStatusException {
    JsonNode node = parent.get(field);
    if (node == null || node.isNull()) {
      return null;
    }
    if (!node.isBoolean()) {
      throw new MalformedStatusException(field + " is not a boolean");
    }
    return node.asBoolean();
  }

  /// ISO 시각(+09:00 등 오프셋 포함) > 이 서버 시간대 LocalDateTime
  private static LocalDateTime dateTimeOrNull(JsonNode parent, String field, ZoneId zone)
    throws MalformedStatusException {
    String text = textOrNull(parent, field);
    if (text == null || text.isBlank()) {
      return null;
    }
    try {
      return OffsetDateTime.parse(text.trim()).atZoneSameInstant(zone).toLocalDateTime();
    } catch (DateTimeParseException e) {
      throw new MalformedStatusException(field + " is not an ISO offset date-time", e);
    }
  }

  /// logTail: 글 배열 (마지막 MAX_LOG_TAIL_LINES 줄, 줄마다 길이 상한)
  private static List<String> logTailOf(JsonNode root) throws MalformedStatusException {
    JsonNode node = root.get("logTail");
    if (node == null || node.isNull()) {
      return List.of();
    }
    if (!node.isArray()) {
      throw new MalformedStatusException("logTail is not an array");
    }
    List<String> lines = new ArrayList<>();
    int firstIndex = Math.max(0, node.size() - MAX_LOG_TAIL_LINES);
    for (int index = firstIndex; index < node.size(); index++) {
      JsonNode line = node.get(index);
      if (!line.isTextual()) {
        throw new MalformedStatusException("logTail line is not text");
      }
      lines.add(truncate(line.asText(), MAX_LOG_LINE_LENGTH));
    }
    return List.copyOf(lines);
  }

  /// differences: {item, source, target} 객체 배열 (앞 MAX_DIFFERENCE_ROWS 줄)
  private static List<Difference> differencesOf(JsonNode root) throws MalformedStatusException {
    JsonNode node = root.get("differences");
    if (node == null || node.isNull()) {
      return List.of();
    }
    if (!node.isArray()) {
      throw new MalformedStatusException("differences is not an array");
    }
    List<Difference> differences = new ArrayList<>();
    for (int index = 0; index < node.size() && index < MAX_DIFFERENCE_ROWS; index++) {
      JsonNode difference = node.get(index);
      if (!difference.isObject()) {
        throw new MalformedStatusException("difference row is not an object");
      }
      differences.add(new Difference(
        truncate(textOrNull(difference, "item"), MAX_LOG_LINE_LENGTH),
        truncate(textOrNull(difference, "source"), MAX_LOG_LINE_LENGTH),
        truncate(textOrNull(difference, "target"), MAX_LOG_LINE_LENGTH)
      ));
    }
    return List.copyOf(differences);
  }

  private static String truncate(String value, int maxLength) {
    if (value == null || value.length() <= maxLength) {
      return value;
    }
    return value.substring(0, maxLength - TRUNCATED_SUFFIX.length()) + TRUNCATED_SUFFIX;
  }
}
