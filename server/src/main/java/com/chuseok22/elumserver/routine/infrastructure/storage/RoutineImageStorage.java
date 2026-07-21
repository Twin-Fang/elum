package com.chuseok22.elumserver.routine.infrastructure.storage;

import com.chuseok22.elumserver.ai.infrastructure.client.GeminiImageClient;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.RoutineProperties;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class RoutineImageStorage {

  private final RoutineProperties routineProperties;

  public String save(String batchId, Integer stepOrder, GeminiImageClient.GeneratedImage image) {
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
