package com.chuseok22.elumserver.routine.infrastructure.storage;

import com.chuseok22.elumserver.common.infrastructure.properties.TtsProperties;
import java.io.IOException;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.NoSuchFileException;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Comparator;
import java.util.Optional;
import java.util.stream.Stream;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 단계 음성 로컬 디스크 구현: 임시 파일 > 이동 저장, 폴더 밖 열쇠 차단
 * 서버 한 대 전제 (그림 저장소와 같음)
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class LocalFileRoutineStepSpeechStorage implements RoutineStepSpeechStorage {

  private static final String SPEECH_EXTENSION = ".wav";

  private final TtsProperties ttsProperties;

  @Override
  public String save(String stepId, String textHash, byte[] wav) {
    String key = stepId + "/" + textHash + SPEECH_EXTENSION;
    Path temp = null;
    try {
      Path file = resolve(key);
      Files.createDirectories(file.getParent());
      // 임시 파일에 다 쓴 뒤 옮김 (끊겨도 반쪽 파일이 열쇠 자리에 남지 않음)
      temp = Files.createTempFile(file.getParent(), ".speech-", ".tmp");
      Files.write(temp, wav);
      try {
        Files.move(temp, file, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
      } catch (AtomicMoveNotSupportedException e) {
        Files.move(temp, file, StandardCopyOption.REPLACE_EXISTING);
      }
      temp = null;
      return key;
    } catch (IOException e) {
      throw new IllegalStateException("speech save failed: stepId=" + stepId, e);
    } finally {
      // 실패 시 임시 파일 정리 (성공·실패 공통 확인)
      if (temp != null) {
        try {
          Files.deleteIfExists(temp);
        } catch (IOException cleanup) {
          log.warn("[routine speech] temp cleanup failed : path={}", temp, cleanup);
        }
      }
    }
  }

  @Override
  public Optional<byte[]> read(String key) {
    try {
      return Optional.of(Files.readAllBytes(resolve(key)));
    } catch (IOException e) {
      log.warn("[routine speech] read failed : key={}, cause={}", key, e.getClass().getSimpleName());
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
      log.warn("[routine speech] delete failed : key={}", key, e);
    }
  }

  @Override
  public void deleteStep(String stepId) {
    if (stepId == null || stepId.isBlank()) {
      return;
    }
    Path dir = base().resolve(stepId).normalize();
    // 폴더 밖이거나 저장 폴더 자체면 지우지 않음
    if (!dir.startsWith(base()) || dir.equals(base())) {
      log.warn("[routine speech] rejected delete outside base : stepId={}", stepId);
      return;
    }
    try (Stream<Path> paths = Files.walk(dir)) {
      paths.sorted(Comparator.reverseOrder()).forEach(path -> {
        try {
          Files.deleteIfExists(path);
        } catch (IOException e) {
          log.warn("[routine speech] delete failed : path={}", path, e);
        }
      });
    } catch (NoSuchFileException e) {
      // 음성을 한 번도 안 만든 단계는 폴더가 없음 (정상)
    } catch (IOException e) {
      log.warn("[routine speech] step folder delete failed : stepId={}", stepId, e);
    }
  }

  private Path base() {
    return Path.of(ttsProperties.speechStoragePath()).toAbsolutePath().normalize();
  }

  /**
   * 열쇠 > 파일 위치 (../ 섞인 열쇠로 폴더 밖 접근 차단)
   */
  private Path resolve(String key) throws IOException {
    if (key == null || key.isBlank()) {
      throw new IOException("empty speech key");
    }
    Path resolved = base().resolve(key).normalize();
    if (!resolved.startsWith(base()) || Path.of(key).isAbsolute()) {
      throw new IOException("speech key outside base: " + key);
    }
    return resolved;
  }
}
