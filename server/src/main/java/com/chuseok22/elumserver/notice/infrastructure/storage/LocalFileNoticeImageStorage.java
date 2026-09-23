package com.chuseok22.elumserver.notice.infrastructure.storage;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.NoticeProperties;
import com.chuseok22.elumserver.notice.core.NoticeImageType;
import java.io.IOException;
import java.nio.file.DirectoryNotEmptyException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 서버 로컬 디스크에 담는 구현 (이슈 #370).
 *
 * <p>일과 이미지 저장소와 같은 한계를 가진다 — <b>서버가 한 대일 때만 온전하다.</b>
 * 여러 대가 되면 공유 저장소 구현으로 바꾼다. 이 인터페이스를 쓰는 쪽은 바뀌지 않는다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class LocalFileNoticeImageStorage implements NoticeImageStorage {

  private final NoticeProperties noticeProperties;

  @Override
  public String save(String noticeId, byte[] bytes, NoticeImageType type) {
    String key = noticeId + "/" + UUID.randomUUID().toString().replace("-", "") + "." + type.getExtension();
    try {
      Path file = resolve(key);
      Files.createDirectories(file.getParent());
      Files.write(file, bytes);
      return key;
    } catch (IOException e) {
      log.warn("공지 이미지 저장 실패: noticeId={}", noticeId, e);
      throw new CustomException(ErrorCode.NOTICE_IMAGE_SAVE_FAILED);
    }
  }

  @Override
  public ImageContent read(String key) {
    try {
      Path file = resolve(key);
      byte[] bytes = Files.readAllBytes(file);
      // 저장할 때 서명으로 정한 확장자다. 운영체제의 형식 추측(probeContentType)은
      // macOS 에서 webp 를 모르는 등 환경마다 달라 쓰지 않는다.
      String contentType = NoticeImageType.fromKey(key)
        .map(NoticeImageType::getContentType)
        .orElse("application/octet-stream");
      return new ImageContent(bytes, contentType);
    } catch (IOException e) {
      log.warn("공지 이미지 조회 실패: key={}", key);
      throw new CustomException(ErrorCode.NOTICE_IMAGE_NOT_FOUND);
    }
  }

  @Override
  public void delete(String key) {
    if (key == null || key.isBlank()) {
      return;
    }
    try {
      Path file = resolve(key);
      Files.deleteIfExists(file);
      // 공지마다 폴더가 하나다. 비었으면 함께 치운다 — 남겨 두면 지운 공지 수만큼 빈 폴더가 쌓인다.
      Path parent = file.getParent();
      if (parent != null && !parent.equals(base())) {
        try {
          Files.deleteIfExists(parent);
        } catch (DirectoryNotEmptyException ignored) {
          // 바꾸는 중이라 새 그림이 같은 폴더에 있다. 정상이다.
        }
      }
    } catch (IOException e) {
      log.warn("공지 이미지 삭제 실패(다음 흐름은 계속한다): key={}", key, e);
    }
  }

  private Path base() {
    return Path.of(noticeProperties.imageStoragePath()).toAbsolutePath().normalize();
  }

  /**
   * 열쇠를 실제 파일 위치로 바꾼다. 마지막에 저장 폴더 안인지 확인한다 — 열쇠에 {@code ../} 가
   * 섞여 들어오면 폴더 밖 파일을 읽거나 지울 수 있다.
   */
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
