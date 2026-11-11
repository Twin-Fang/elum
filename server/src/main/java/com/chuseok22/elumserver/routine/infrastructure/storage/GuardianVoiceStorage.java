package com.chuseok22.elumserver.routine.infrastructure.storage;

import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 보호자 목소리 녹음 저장소: 저장, 조회, 삭제, 보호자별 전체 삭제 (#787)
 * 열쇠 {memberId}/{UUID}.m4a > DB routine_step.guardian_voice_path. 그림 저장소와 같은 열쇠 방식
 */
public interface GuardianVoiceStorage {

  // 열쇠 모양: {녹음한 보호자 memberId}/{UUID}.m4a (save 가 만드는 모양)
  Pattern VOICE_KEY = Pattern.compile("^([^/]+)/[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}\\.m4a$");

  /**
   * 열쇠 > 녹음한 보호자 memberId. 모양이 다르면 빈 값
   */
  static Optional<String> ownerOf(String key) {
    if (key == null) {
      return Optional.empty();
    }
    Matcher matcher = VOICE_KEY.matcher(key);
    return matcher.matches() ? Optional.of(matcher.group(1)) : Optional.empty();
  }

  /**
   * 녹음 저장 > 새 열쇠 (매번 새 열쇠라 앱 캐시가 옛 녹음을 틀지 않음)
   *
   * @throws com.chuseok22.elumserver.common.infrastructure.exception.CustomException 쓰기 실패 시
   *         {@code GUARDIAN_VOICE_SAVE_FAILED}
   */
  String save(String memberId, byte[] audio);

  /**
   * 열쇠 > 녹음. 없거나 폴더 밖 열쇠면 빈 값
   */
  Optional<byte[]> read(String key);

  /**
   * 파일 1개 삭제 (없거나 실패해도 던지지 않음, 기록만)
   */
  void delete(String key);

  /**
   * 보호자 녹음 전체 삭제 (탈퇴 시)
   */
  void deleteAllOf(String memberId);
}
