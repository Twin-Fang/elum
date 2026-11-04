package com.chuseok22.elumserver.routine.infrastructure.storage;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.RoutineProperties;
import java.io.IOException;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.NoSuchFileException;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Comparator;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Stream;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 보호자 목소리 로컬 디스크 구현: 임시 파일 > 이동 저장, 폴더 밖 열쇠 차단
 * 위치 {카드 그림 폴더}/guardian-voice/{memberId}/{UUID}.m4a — 그림 폴더 아래라 서버 이전 파일 내보내기에 함께 들어감
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class LocalFileGuardianVoiceStorage implements GuardianVoiceStorage {

  // 카드 그림 폴더 안 녹음 폴더 이름 (그림 열쇠는 UUID 묶음 폴더라 겹치지 않음)
  static final String VOICE_DIRECTORY_NAME = "guardian-voice";
  private static final String VOICE_EXTENSION = ".m4a";

  private final RoutineProperties routineProperties;

  @Override
  public String save(String memberId, byte[] audio) {
    String key = memberId + "/" + UUID.randomUUID() + VOICE_EXTENSION;
    Path partialFile = null;
    try {
      Path file = resolve(key);
      Files.createDirectories(file.getParent());
      // 임시 파일에 다 쓴 뒤 옮김 (끊겨도 반쪽 파일이 열쇠 자리에 남지 않음)
      partialFile = Files.createTempFile(file.getParent(), ".voice-", ".tmp");
      Files.write(partialFile, audio);
      try {
        Files.move(partialFile, file, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
      } catch (AtomicMoveNotSupportedException e) {
        Files.move(partialFile, file, StandardCopyOption.REPLACE_EXISTING);
      }
      partialFile = null;
      return key;
    } catch (IOException e) {
      log.warn("[guardian voice] save failed : memberId={}", memberId, e);
      throw new CustomException(ErrorCode.GUARDIAN_VOICE_SAVE_FAILED);
    } finally {
      // 실패 시 임시 파일 정리 (성공·실패 공통 확인)
      if (partialFile != null) {
        try {
          Files.deleteIfExists(partialFile);
        } catch (IOException cleanup) {
          log.warn("[guardian voice] partialFile cleanup failed : path={}", partialFile, cleanup);
        }
      }
    }
  }

  @Override
  public Optional<byte[]> read(String key) {
    try {
      return Optional.of(Files.readAllBytes(resolve(key)));
    } catch (IOException e) {
      log.warn("[guardian voice] read failed : key={}, cause={}", key, e.getClass().getSimpleName());
      return Optional.empty();
    }
  }

  @Override
  public void delete(String key) {
    if (key == null || key.isBlank()) {
      return;
    }
    try {
      Files.deleteIfExists(resolve(key));
    } catch (IOException e) {
      log.warn("[guardian voice] delete failed : key={}", key, e);
    }
  }

  @Override
  public void deleteAllOf(String memberId) {
    if (memberId == null || memberId.isBlank()) {
      return;
    }
    Path dir = base().resolve(memberId).normalize();
    // 폴더 밖이거나 녹음 폴더 자체면 지우지 않음
    if (!dir.startsWith(base()) || dir.equals(base())) {
      log.warn("[guardian voice] rejected delete outside base : memberId={}", memberId);
      return;
    }
    try (Stream<Path> paths = Files.walk(dir)) {
      paths.sorted(Comparator.reverseOrder()).forEach(path -> {
        try {
          Files.deleteIfExists(path);
        } catch (IOException e) {
          log.warn("[guardian voice] delete failed : path={}", path, e);
        }
      });
      log.info("[guardian voice] deleted all : memberId={}", memberId);
    } catch (NoSuchFileException e) {
      // 녹음을 한 번도 안 한 보호자는 폴더가 없음 (정상)
    } catch (IOException e) {
      log.warn("[guardian voice] member folder delete failed : memberId={}", memberId, e);
    }
  }

  private Path base() {
    return Path.of(routineProperties.imageStoragePath()).toAbsolutePath().normalize().resolve(VOICE_DIRECTORY_NAME);
  }

  /**
   * 열쇠 > 파일 위치 (../ 섞인 열쇠로 폴더 밖 접근 차단)
   */
  private Path resolve(String key) throws IOException {
    if (key == null || key.isBlank()) {
      throw new IOException("empty voice key");
    }
    Path resolved = base().resolve(key).normalize();
    if (!resolved.startsWith(base()) || Path.of(key).isAbsolute()) {
      throw new IOException("voice key outside base: " + key);
    }
    return resolved;
  }
}
