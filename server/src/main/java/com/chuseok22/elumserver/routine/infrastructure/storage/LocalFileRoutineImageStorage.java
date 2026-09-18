package com.chuseok22.elumserver.routine.infrastructure.storage;

import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.RoutineProperties;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;
import java.util.stream.Stream;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * 서버의 로컬 디스크에 담는 구현.
 *
 * <p><b>서버가 한 대일 때만 온전히 동작한다.</b> 여러 대가 되면 A가 저장한 그림을 B가
 * 읽지 못해 조회의 상당수가 "이미지를 찾을 수 없습니다"로 떨어진다. 그때는 공유
 * 저장소 구현체로 바꾼다.
 *
 * <p><b>구현체는 설정으로 고른다.</b> {@code elum.store.routine-image} 값이 없거나
 * {@code local}이면 이것이 쓰인다. 다른 구현체를 추가해도 등록되는 것은 하나뿐이라
 * 충돌하지 않는다.
 *
 * <p>다만 <b>구현체를 바꾸는 것만으로는 부족하다</b> — 이미 디스크에 있는 그림을 새
 * 저장소로 옮기는 일이 남는다. DB 값은 열쇠라 그대로 쓸 수 있으니 파일만 옮기면 된다.
 */
@Slf4j
@Component
@ConditionalOnProperty(name = "elum.store.routine-image", havingValue = "local", matchIfMissing = true)
@RequiredArgsConstructor
public class LocalFileRoutineImageStorage implements RoutineImageStorage {

  private final RoutineProperties routineProperties;

  @Override
  public String save(String batchId, Integer stepOrder, GeneratedImage image) {
    String key = batchId + "/" + stepOrder + "." + image.extension();
    try {
      Path file = resolve(key);
      Files.createDirectories(file.getParent());
      Files.write(file, image.bytes());
      return key;
    } catch (IOException e) {
      log.warn("일과 이미지 저장 실패: batchId={}, stepOrder={}", batchId, stepOrder, e);
      throw new CustomException(ErrorCode.ROUTINE_AI_GENERATION_FAILED);
    }
  }

  @Override
  public void deleteBatch(String batchId) {
    if (batchId == null || batchId.isBlank()) {
      return;
    }
    Path dir = base().resolve(batchId).normalize();
    if (!dir.startsWith(base())) {
      log.warn("허용 범위 밖의 경로라 삭제하지 않습니다: batchId={}", batchId);
      return;
    }
    try (Stream<Path> paths = Files.walk(dir)) {
      paths.sorted(Comparator.reverseOrder()).forEach(path -> {
        try {
          Files.deleteIfExists(path);
        } catch (IOException e) {
          log.warn("고아 이미지 삭제 실패: path={}", path, e);
        }
      });
      log.info("저장 실패로 생성 이미지를 정리했습니다: batchId={}", batchId);
    } catch (java.nio.file.NoSuchFileException e) {
      // 이미지가 한 장도 안 만들어졌으면 폴더 자체가 없다. 정상이다.
    } catch (IOException e) {
      log.warn("고아 이미지 정리 실패: batchId={}", batchId, e);
    }
  }

  @Override
  public ImageContent read(String key) {
    try {
      Path path = resolve(key);
      byte[] bytes = Files.readAllBytes(path);
      String contentType = Files.probeContentType(path);
      return new ImageContent(bytes, contentType != null ? contentType : "application/octet-stream");
    } catch (IOException e) {
      log.warn("일과 이미지 조회 실패: key={}", key, e);
      throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_NOT_FOUND);
    }
  }

  private Path base() {
    return Path.of(routineProperties.imageStoragePath()).toAbsolutePath().normalize();
  }

  /**
   * 열쇠를 실제 파일 위치로 바꾼다.
   *
   * <p>열쇠로 바꾸기 전에 저장된 값은 경로가 통째로 들어 있다. 그 값도 계속 열리도록
   * 함께 받는다 — 마이그레이션이 늦거나 일부가 남아도 과거 카드의 그림이 깨지지 않게
   * 하기 위해서다.
   *
   * <p>어느 쪽이든 마지막에 저장 폴더 안인지 확인한다. 열쇠에 {@code ../}가 섞여 들어오면
   * 폴더 밖 파일을 읽을 수 있기 때문이다.
   */
  private Path resolve(String key) throws IOException {
    if (key == null || key.isBlank()) {
      throw new IOException("이미지 열쇠가 비어 있음");
    }
    Path base = base();
    Path candidate = Path.of(key);
    Path resolved = (candidate.isAbsolute() || key.startsWith(routineProperties.imageStoragePath()))
      ? candidate.toAbsolutePath().normalize()
      : base.resolve(candidate).normalize();

    if (!resolved.startsWith(base)) {
      throw new IOException("저장 폴더 밖을 가리키는 열쇠: " + key);
    }
    return resolved;
  }
}
