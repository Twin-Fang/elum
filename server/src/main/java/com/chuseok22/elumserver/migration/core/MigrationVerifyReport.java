package com.chuseok22.elumserver.migration.core;

import java.time.LocalDateTime;
import java.util.List;

/**
 * NAS 마지막 정합성 검사 결과 (verify-status.json, #1062)
 * 값이 없던 칸은 null
 */
public record MigrationVerifyReport(
  LocalDateTime checkedAt,
  MigrationVerifyResult result,
  String rawResult,
  Integer differenceCount,
  List<Difference> differences,
  // 파일 비교: same 같음, DIFF 다름, skipped 건너뜀
  String files,
  // 운영 중 검사(--allow-live)였는가
  Boolean isLiveAllowed
) {

  private static final String FILES_SAME = "same";
  private static final String FILES_DIFFERENT = "DIFF";
  private static final String FILES_SKIPPED = "skipped";

  /// 차이 1건: 항목(표 이름 등), 옛 서버 값, 새 서버 값 (건수·해시 요약)
  public record Difference(String item, String source, String target) {
  }

  /// 파일 비교 > 표시 이름 (모르는 값은 그대로)
  public String filesLabel() {
    if (FILES_SAME.equals(files)) {
      return "같음";
    }
    if (FILES_DIFFERENT.equals(files)) {
      return "다름";
    }
    if (FILES_SKIPPED.equals(files)) {
      return "건너뜀";
    }
    return files;
  }

  public boolean hasDifferences() {
    return differences != null && !differences.isEmpty();
  }
}
