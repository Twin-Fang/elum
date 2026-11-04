package com.chuseok22.elumserver.migration.application.dto.response;

/**
 * 상태 JSON 1개 읽은 결과 (#1062): 없음, 읽음, 읽을 수 없음
 * report 는 읽었을 때만, errorMessage 는 읽을 수 없을 때만 값 ("... (E-MIG-006)")
 */
public record MigrationStatusFileView<T>(State state, T report, String errorMessage) {

  public enum State {
    MISSING,
    READ,
    UNREADABLE,
  }

  public static <T> MigrationStatusFileView<T> missing() {
    return new MigrationStatusFileView<>(State.MISSING, null, null);
  }

  public static <T> MigrationStatusFileView<T> read(T report) {
    return new MigrationStatusFileView<>(State.READ, report, null);
  }

  public static <T> MigrationStatusFileView<T> unreadable(String errorMessage) {
    return new MigrationStatusFileView<>(State.UNREADABLE, null, errorMessage);
  }

  public boolean isMissing() {
    return state == State.MISSING;
  }

  public boolean isRead() {
    return state == State.READ;
  }

  public boolean isUnreadable() {
    return state == State.UNREADABLE;
  }
}
