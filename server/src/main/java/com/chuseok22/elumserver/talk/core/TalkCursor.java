package com.chuseok22.elumserver.talk.core;

import java.time.LocalDateTime;
import java.time.format.DateTimeParseException;
import java.util.Optional;

/**
 * 피드 cursor: 마지막으로 준 글의 (올린 시각, id) 위치
 * 형식 "{ISO-8601}|{id}", 틀리면 empty (호출부가 첫 쪽으로 본다)
 */
public record TalkCursor(LocalDateTime createdAt, String id) {

  private static final String DELIMITER = "|";

  public static String encode(LocalDateTime createdAt, String id) {
    return createdAt + DELIMITER + id;
  }

  public static Optional<TalkCursor> decode(String raw) {
    if (raw == null || raw.isBlank()) {
      return Optional.empty();
    }
    int delimiterIndex = raw.indexOf(DELIMITER);
    if (delimiterIndex <= 0 || delimiterIndex == raw.length() - 1) {
      return Optional.empty();
    }
    try {
      return Optional.of(new TalkCursor(
        LocalDateTime.parse(raw.substring(0, delimiterIndex)), raw.substring(delimiterIndex + 1)));
    } catch (DateTimeParseException e) {
      return Optional.empty();
    }
  }
}
