package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.LogSearchResponse;
import com.chuseok22.elumserver.admin.application.dto.response.LogSearchResponse.Entry;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.OffsetDateTime;
import java.time.format.DateTimeParseException;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Deque;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.zip.GZIPInputStream;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * 로그 파일(압축 포함)을 처음부터 읽어 레벨·키워드·시각으로 거른다.
 * 시각+레벨로 시작하는 줄이 새 항목이고, 그렇지 않은 줄(스택트레이스·요청 덤프)은 앞 항목에 붙인다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AdminLogSearchService {

  static final int DEFAULT_LIMIT = 200;
  static final int MAX_LIMIT = 500;
  // 한 항목이 수 MB 짜리 덤프여도 응답이 터지지 않게 자른다. 원문은 다운로드로 본다.
  static final int MAX_ENTRY_CHARS = 20_000;

  private static final Pattern ENTRY_START =
    Pattern.compile("^(\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\S*)\\s+(TRACE|DEBUG|INFO|WARN|ERROR)\\s");
  private static final Map<String, Integer> LEVEL_RANK =
    Map.of("TRACE", 0, "DEBUG", 1, "INFO", 2, "WARN", 3, "ERROR", 4);

  private final LogFileLocator locator;

  /**
   * @param level 최소 레벨 (WARN 이면 WARN·ERROR). 비우면 전부
   * @param from  이 시각 이후 항목만 (ISO-8601, 예: 2026-10-08T09:12:03+09:00)
   */
  public LogSearchResponse search(String path, String level, String query, String from, Integer limit) {
    String target = path == null || path.isBlank() ? locator.currentLogPath() : path;
    Path file = locator.resolveExisting(target);
    Filter filter = new Filter(minRank(level), normalizeQuery(query), parseFrom(from));
    int max = clampLimit(limit);

    Deque<Entry> kept = new ArrayDeque<>();
    long scanned = 0;
    long matched = 0;
    try (BufferedReader reader = open(file)) {
      Builder current = null;
      String line;
      while ((line = reader.readLine()) != null) {
        Matcher start = ENTRY_START.matcher(line);
        if (start.find()) {
          if (current != null) {
            scanned++;
            matched += keepIfMatches(current, filter, kept, max);
          }
          current = new Builder(start.group(1), start.group(2), line);
        } else if (current != null) {
          current.append(line);
        } else {
          current = new Builder(null, null, line);
        }
      }
      if (current != null) {
        scanned++;
        matched += keepIfMatches(current, filter, kept, max);
      }
    } catch (IOException e) {
      log.warn("[관리자 로그] 로그 검색 중 읽기 실패: path={}", target, e);
      throw new CustomException(ErrorCode.LOG_FILE_READ_FAILED);
    }

    List<Entry> newestFirst = new ArrayList<>(kept);
    Collections.reverse(newestFirst);
    return new LogSearchResponse(target, scanned, matched, newestFirst);
  }

  private int keepIfMatches(Builder builder, Filter filter, Deque<Entry> kept, int max) {
    if (!filter.matches(builder)) {
      return 0;
    }
    kept.addLast(builder.build());
    if (kept.size() > max) {
      kept.pollFirst();
    }
    return 1;
  }

  private BufferedReader open(Path file) throws IOException {
    InputStream in = Files.newInputStream(file);
    try {
      InputStream source = file.getFileName().toString().endsWith(".gz") ? new GZIPInputStream(in) : in;
      // 깨진 UTF-8 바이트는 대체 문자로 바꿔 읽는다 — 한 바이트 때문에 검색 전체가 실패하지 않게.
      return new BufferedReader(new InputStreamReader(source, StandardCharsets.UTF_8));
    } catch (IOException e) {
      in.close();
      throw e;
    }
  }

  private int minRank(String level) {
    if (level == null || level.isBlank() || "ALL".equalsIgnoreCase(level)) {
      return -1;
    }
    Integer rank = LEVEL_RANK.get(level.trim().toUpperCase(Locale.ROOT));
    if (rank == null) {
      throw new CustomException(ErrorCode.INVALID_LOG_LEVEL);
    }
    return rank;
  }

  private String normalizeQuery(String query) {
    return query == null || query.isBlank() ? null : query.trim().toLowerCase(Locale.ROOT);
  }

  private OffsetDateTime parseFrom(String from) {
    if (from == null || from.isBlank()) {
      return null;
    }
    try {
      return OffsetDateTime.parse(from.trim());
    } catch (DateTimeParseException e) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
  }

  private int clampLimit(Integer limit) {
    if (limit == null || limit <= 0) {
      return DEFAULT_LIMIT;
    }
    return Math.min(limit, MAX_LIMIT);
  }

  private record Filter(int minRank, String query, OffsetDateTime from) {

    boolean matches(Builder entry) {
      if (minRank >= 0 && (entry.level == null || LEVEL_RANK.get(entry.level) < minRank)) {
        return false;
      }
      if (from != null && (entry.timestamp == null || parse(entry.timestamp).isBefore(from))) {
        return false;
      }
      return query == null || entry.text.toString().toLowerCase(Locale.ROOT).contains(query);
    }

    private static OffsetDateTime parse(String timestamp) {
      try {
        return OffsetDateTime.parse(timestamp);
      } catch (DateTimeParseException e) {
        return OffsetDateTime.MIN;
      }
    }
  }

  private static final class Builder {

    private final String timestamp;
    private final String level;
    private final StringBuilder text;
    private boolean truncated;

    Builder(String timestamp, String level, String firstLine) {
      this.timestamp = timestamp;
      this.level = level;
      this.text = new StringBuilder();
      append(firstLine);
    }

    void append(String line) {
      if (truncated) {
        return;
      }
      if (!text.isEmpty()) {
        text.append('\n');
      }
      int room = MAX_ENTRY_CHARS - text.length();
      if (line.length() > room) {
        text.append(line, 0, Math.max(room, 0));
        truncated = true;
      } else {
        text.append(line);
      }
    }

    Entry build() {
      return new Entry(timestamp, level, text.toString(), truncated);
    }
  }
}
