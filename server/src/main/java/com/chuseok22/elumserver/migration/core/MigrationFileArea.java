package com.chuseok22.elumserver.migration.core;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import java.util.Arrays;
import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 내보낼 수 있는 파일 종류 4개: 카드 그림, 이야기 그림, 공지 그림, 음성
 * 기준 폴더는 각 저장소 설정값 (MigrationFileExportService)
 */
@Getter
@AllArgsConstructor
public enum MigrationFileArea {

  ROUTINE_IMAGES("routine-images"),
  TALK_IMAGES("talk-images"),
  NOTICE_IMAGES("notice-images"),
  ROUTINE_SPEECH("routine-speech"),
  ;

  private final String code;

  /// 요청 값 > 종류 (모르면 INVALID_MIGRATION_FILE_AREA)
  public static MigrationFileArea fromCode(String code) {
    return Arrays.stream(values())
      .filter(area -> area.code.equals(code))
      .findFirst()
      .orElseThrow(() -> new CustomException(ErrorCode.INVALID_MIGRATION_FILE_AREA));
  }
}
