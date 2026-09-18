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
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class RoutineImageStorage {

  private final RoutineProperties routineProperties;

  public String save(String batchId, Integer stepOrder, GeneratedImage image) {
    try {
      Path dir = Path.of(routineProperties.imageStoragePath(), batchId);
      Files.createDirectories(dir);
      Path file = dir.resolve(stepOrder + "." + image.extension());
      Files.write(file, image.bytes());
      return file.toString();
    } catch (IOException e) {
      log.warn("일과 이미지 저장 실패: batchId={}, stepOrder={}", batchId, stepOrder, e);
      throw new CustomException(ErrorCode.ROUTINE_AI_GENERATION_FAILED);
    }
  }

  /**
   * 한 번의 생성에서 만든 이미지를 통째로 지운다 (이슈 #215).
   *
   * <p>이미지는 엔티티를 저장하기 <b>전에</b> 디스크에 쓰인다. 저장이 실패하면
   * 아무도 참조하지 않는 파일이 남아 디스크가 계속 불어난다. 실패 경로에서 불러
   * 방금 쓴 것만 되돌린다.
   *
   * <p>지우다 실패해도 예외를 밖으로 내지 않는다 — 이미 다른 실패를 처리하는 중이라,
   * 여기서 예외를 던지면 진짜 원인이 가려진다.
   */
  public void deleteBatch(String batchId) {
    if (batchId == null || batchId.isBlank()) {
      return;
    }
    Path dir = Path.of(routineProperties.imageStoragePath(), batchId);
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

  public ImageContent read(String imagePath) {
    Path path = Path.of(imagePath);
    try {
      byte[] bytes = Files.readAllBytes(path);
      String contentType = Files.probeContentType(path);
      return new ImageContent(bytes, contentType != null ? contentType : "application/octet-stream");
    } catch (IOException e) {
      log.warn("일과 이미지 조회 실패: path={}", imagePath, e);
      throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_NOT_FOUND);
    }
  }

  public record ImageContent(byte[] bytes, String contentType) {

  }
}
