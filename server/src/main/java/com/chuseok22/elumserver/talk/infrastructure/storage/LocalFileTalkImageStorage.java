package com.chuseok22.elumserver.talk.infrastructure.storage;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.TalkProperties;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.NoSuchFileException;
import java.nio.file.Path;
import java.util.Comparator;
import java.util.Locale;
import java.util.stream.Stream;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 서버 로컬 디스크 구현: 서버가 한 대일 때만 온전함 (여러 대면 공유 저장소 구현으로 교체)
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class LocalFileTalkImageStorage implements TalkImageStorage {

  private final TalkProperties talkProperties;

  @Override
  public String save(String postId, int stepOrder, byte[] bytes, String contentType) {
    String key = postId + "/" + stepOrder + "." + extensionOf(contentType);
    try {
      Path file = resolve(key);
      Files.createDirectories(file.getParent());
      Files.write(file, bytes);
      return key;
    } catch (IOException e) {
      log.warn("[talk image] save failed : postId={}, stepOrder={}", postId, stepOrder, e);
      throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_SAVE_FAILED);
    }
  }

  @Override
  public RoutineImageStorage.ImageContent read(String key) {
    try {
      byte[] bytes = Files.readAllBytes(resolve(key));
      // 저장할 때 정한 확장자로 형식을 돌려줌 (운영체제 추측은 환경마다 다름)
      return new RoutineImageStorage.ImageContent(bytes, contentTypeOf(key));
    } catch (IOException e) {
      log.warn("[talk image] read failed : key={}", key);
      throw new CustomException(ErrorCode.TALK_IMAGE_NOT_FOUND);
    }
  }

  @Override
  public void deletePost(String postId) {
    if (postId == null || postId.isBlank()) {
      return;
    }
    Path directory = base().resolve(postId).normalize();
    // 저장 폴더 밖이거나 저장 폴더 자체면 지우지 않음
    if (!directory.startsWith(base()) || directory.equals(base())) {
      log.warn("[talk image] delete skipped : outside storage, postId={}", postId);
      return;
    }
    try (Stream<Path> paths = Files.walk(directory)) {
      paths.sorted(Comparator.reverseOrder()).forEach(path -> {
        try {
          Files.deleteIfExists(path);
        } catch (IOException e) {
          log.warn("[talk image] delete failed : path={}", path, e);
        }
      });
    } catch (NoSuchFileException e) {
      // 그림이 없던 글은 폴더도 없음 (정상)
    } catch (IOException e) {
      log.warn("[talk image] delete post failed : postId={}", postId, e);
    }
  }

  private static String extensionOf(String contentType) {
    if (contentType == null) {
      return "jpg";
    }
    return switch (contentType.toLowerCase(Locale.ROOT)) {
      case "image/png" -> "png";
      case "image/webp" -> "webp";
      default -> "jpg";
    };
  }

  private static String contentTypeOf(String key) {
    int dot = key.lastIndexOf('.');
    String extension = dot < 0 ? "" : key.substring(dot + 1).toLowerCase(Locale.ROOT);
    return switch (extension) {
      case "jpg", "jpeg" -> "image/jpeg";
      case "png" -> "image/png";
      case "webp" -> "image/webp";
      default -> "application/octet-stream";
    };
  }

  private Path base() {
    return Path.of(talkProperties.imageStoragePath()).toAbsolutePath().normalize();
  }

  // 열쇠 > 파일 위치 (저장 폴더 밖이면 거절: ../ 섞인 값 차단)
  private Path resolve(String key) throws IOException {
    if (key == null || key.isBlank()) {
      throw new IOException("이미지 열쇠가 비어 있음");
    }
    Path base = base();
    Path resolved = base.resolve(key).normalize();
    if (!resolved.startsWith(base) || resolved.equals(base)) {
      throw new IOException("저장 폴더 밖을 가리키는 열쇠: " + key);
    }
    return resolved;
  }
}
