package com.chuseok22.elumserver.routine.infrastructure.storage;

import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.storage.StoredImageFormat;
import com.chuseok22.elumserver.common.infrastructure.properties.RoutineProperties;
import java.io.IOException;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.Instant;
import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.Comparator;
import java.util.Locale;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Stream;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * 서버의 로컬 디스크에 담는 구현.
 *
 * <p><b>서버가 한 대일 때만 온전히 동작한다.</b> 여러 대가 되면 A가 저장한 그림을 B가
 * 읽지 못해 조회의 상당수가 "이미지를 찾을 수 없습니다"로 떨어진다. 그때는 공유
 * 저장소 구현체로 바꾼다.
 *
 * <p><b>구현체는 설정으로 고른다.</b> {@code elum.store.image} 값이 없거나
 * {@code local}이면 이것이 쓰인다. 다른 구현체를 추가해도 등록되는 것은 하나뿐이라
 * 충돌하지 않는다.
 *
 * <p>다만 <b>구현체를 바꾸는 것만으로는 부족하다</b> — 이미 디스크에 있는 그림을 새
 * 저장소로 옮기는 일이 남는다. DB 값은 열쇠라 그대로 쓸 수 있으니 파일만 옮기면 된다.
 */
@Slf4j
@Component
@ConditionalOnProperty(name = "elum.store.image", havingValue = "local", matchIfMissing = true)
public class LocalFileRoutineImageStorage implements RoutineImageStorage {

  private final RoutineProperties routineProperties;
  // AI 그림 저장 직전 webp 압축 (#1219)
  private final CardImageCompressor cardImageCompressor;

  @Autowired
  public LocalFileRoutineImageStorage(RoutineProperties routineProperties, CardImageCompressor cardImageCompressor) {
    this.routineProperties = routineProperties;
    this.cardImageCompressor = cardImageCompressor;
  }

  /// 압축 없이 (MinIO 안의 로컬 사본·시험용)
  public LocalFileRoutineImageStorage(RoutineProperties routineProperties) {
    this(routineProperties, CardImageCompressor.NONE);
  }

  @Override
  public String save(String batchId, Integer stepOrder, GeneratedImage generatedImage) {
    GeneratedImage image = compress(generatedImage);
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
  public String saveUploaded(String stepId, byte[] bytes) {
    return writeNewKey(stepId, UUID.randomUUID() + ".jpg", bytes);
  }

  @Override
  public String saveImported(String stepId, ImageContent content) {
    String extension = StoredImageFormat.extensionOf(content.contentType());
    return writeNewKey(stepId, "talk-" + UUID.randomUUID() + "." + extension, content.bytes());
  }

  @Override
  public String saveRegenerated(String stepId, GeneratedImage generatedImage) {
    GeneratedImage image = compress(generatedImage);
    return writeNewKey(stepId, "ai-" + UUID.randomUUID() + "." + image.extension(), image.bytes());
  }

  /**
   * 저장된 그림 > 같은 폴더·같은 이름의 .webp 사본 > 새 열쇠 (옛 열쇠의 확장자만 바꿈)
   */
  @Override
  public Optional<String> saveWebpCopy(String key) {
    int extensionStart = key.lastIndexOf('.');
    if (extensionStart < 0 || key.lastIndexOf('/') > extensionStart) {
      return Optional.empty();
    }
    try {
      Path source = resolve(key);
      if (!Files.isRegularFile(source)) {
        return Optional.empty();
      }
      GeneratedImage original = new GeneratedImage(Files.readAllBytes(source), key.substring(extensionStart + 1));
      Optional<GeneratedImage> webp = cardImageCompressor.toWebp(original);
      if (webp.isEmpty()) {
        return Optional.empty();
      }
      String webpKey = key.substring(0, extensionStart + 1) + webp.get().extension();
      writeAtomically(resolve(webpKey), webp.get().bytes());
      return Optional.of(webpKey);
    } catch (IOException e) {
      log.warn("[routine image] webp copy failed : cause={}", e.getClass().getSimpleName());
      return Optional.empty();
    }
  }

  /// 임시 파일에 다 쓴 뒤 옮김 (끊겨도 반쪽 파일이 열쇠 자리에 남지 않음)
  private static void writeAtomically(Path file, byte[] bytes) throws IOException {
    Path tempFile = Files.createTempFile(file.getParent(), ".webp-", ".tmp");
    try {
      Files.write(tempFile, bytes);
      try {
        Files.move(tempFile, file, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
      } catch (AtomicMoveNotSupportedException e) {
        Files.move(tempFile, file, StandardCopyOption.REPLACE_EXISTING);
      }
    } finally {
      Files.deleteIfExists(tempFile);
    }
  }

  /// AI 그림 > webp. 실패면 원본 그대로 (그림이 빠지지 않게)
  private GeneratedImage compress(GeneratedImage image) {
    return cardImageCompressor.toWebp(image).orElse(image);
  }

  /**
   * 새 열쇠 파일 쓰기: 임시 파일 > 옮기기 (실패 시 임시 파일 정리)
   */
  private String writeNewKey(String stepId, String fileName, byte[] bytes) {
    String key = stepId + "/" + fileName;
    Path temp = null;
    try {
      Path file = resolve(key);
      Files.createDirectories(file.getParent());
      // 임시 파일에 다 쓴 뒤 옮긴다 — 쓰다 끊겨도 반쪽짜리 파일이 열쇠 자리에 남지 않는다.
      temp = Files.createTempFile(file.getParent(), ".upload-", ".tmp");
      Files.write(temp, bytes);
      try {
        Files.move(temp, file, StandardCopyOption.ATOMIC_MOVE);
      } catch (AtomicMoveNotSupportedException e) {
        Files.move(temp, file);
      }
      return key;
    } catch (IOException | RuntimeException e) {
      log.warn("카드 사진 저장 실패: stepId={}", stepId, e);
      if (temp != null) {
        try {
          Files.deleteIfExists(temp);
        } catch (IOException cleanup) {
          log.warn("카드 사진 임시 파일 정리 실패: path={}", temp, cleanup);
        }
      }
      throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_SAVE_FAILED);
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
      log.warn("카드 그림 삭제 실패: key={}", key, e);
    }
  }

  @Override
  public ImageContent read(String key) {
    try {
      Path path = resolve(key);
      byte[] bytes = Files.readAllBytes(path);
      // 운영체제의 형식 추측(probeContentType)은 환경마다 달라 확장자로 정한다 — 저장할 때 정한 확장자다.
      return new ImageContent(bytes, StoredImageFormat.contentTypeOf(key));
    } catch (IOException e) {
      log.warn("일과 이미지 조회 실패: key={}", key, e);
      throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_NOT_FOUND);
    }
  }

  /**
   * 쓰지 않는 그림 정리: 열쇠 > 실제 위치 > 오래된 파일 중 위치에 없는 것 삭제 > 빈 폴더 삭제
   * 보호자 녹음 폴더는 건드리지 않음 (GuardianVoiceFiles 가 따로 정리)
   */
  @Override
  public int deleteUnreferenced(Collection<String> referencedKeys, Instant cutoff) {
    Path base = base();
    if (!Files.isDirectory(base)) {
      return 0;
    }
    // 열쇠를 실제 위치로 비교 (옛 형식 전체 경로 열쇠도 같은 파일로 맞춤)
    Set<Path> referencedFiles = new HashSet<>();
    for (String key : referencedKeys) {
      try {
        referencedFiles.add(resolve(key));
      } catch (IOException e) {
        log.warn("[routine image] orphan clean skipped key : reason={}", e.getMessage());
      }
    }
    Path voiceDirectory = base.resolve(LocalFileGuardianVoiceStorage.VOICE_DIRECTORY_NAME);
    List<Path> orphanFiles;
    try (Stream<Path> paths = Files.walk(base)) {
      orphanFiles = paths.filter(Files::isRegularFile)
        .filter(path -> !path.startsWith(voiceDirectory))
        .filter(path -> !referencedFiles.contains(path))
        .filter(path -> isModifiedBefore(path, cutoff))
        .toList();
    } catch (IOException e) {
      throw new IllegalStateException("image list failed", e);
    }
    int deletedCount = 0;
    for (Path orphanFile : orphanFiles) {
      try {
        Files.deleteIfExists(orphanFile);
        deletedCount++;
      } catch (IOException e) {
        log.warn("[routine image] orphan delete failed : path={}", base.relativize(orphanFile));
      }
    }
    deleteEmptyFolders(base, voiceDirectory);
    return deletedCount;
  }

  private static boolean isModifiedBefore(Path path, Instant cutoff) {
    try {
      return Files.getLastModifiedTime(path).toInstant().isBefore(cutoff);
    } catch (IOException e) {
      // 시각을 못 읽으면 지우지 않는 쪽
      return false;
    }
  }

  /// 빈 폴더 삭제 (깊은 곳부터, 저장 폴더·녹음 폴더 자체는 남김)
  private static void deleteEmptyFolders(Path base, Path voiceDirectory) {
    try (Stream<Path> paths = Files.walk(base)) {
      paths.filter(Files::isDirectory)
        .filter(path -> !path.equals(base) && !path.startsWith(voiceDirectory))
        .sorted(Comparator.reverseOrder())
        .forEach(LocalFileRoutineImageStorage::deleteIfEmpty);
    } catch (IOException e) {
      log.warn("[routine image] empty folder clean failed : cause={}", e.getClass().getSimpleName());
    }
  }

  private static void deleteIfEmpty(Path folder) {
    try (Stream<Path> children = Files.list(folder)) {
      if (children.findAny().isEmpty()) {
        Files.deleteIfExists(folder);
      }
    } catch (IOException e) {
      log.warn("[routine image] empty folder delete failed : cause={}", e.getClass().getSimpleName());
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
