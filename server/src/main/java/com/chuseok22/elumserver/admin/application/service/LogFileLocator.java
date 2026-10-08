package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.LogFileListResponse;
import com.chuseok22.elumserver.admin.application.dto.response.LogFileListResponse.FileItem;
import com.chuseok22.elumserver.admin.application.dto.response.LogFileListResponse.Group;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.logging.LogInstance;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.function.Predicate;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * 관리자 화면이 다루는 로그 파일의 위치를 정한다. 로그 폴더 밖은 절대 열지 않는다.
 *
 * <p>경로는 정해진 모양만 받는다 — 인스턴스 폴더/elum(-error)[.날짜.번호].log[.gz], 이전 형식
 * elum-server[.날짜.번호].log[.gz], deploy-history.log. 모양이 정해져 있으니 ".." 이나 절대경로는
 * 패턴에서 먼저 걸리고, 정규화 후 폴더 밖인지·심볼릭 링크인지를 한 번 더 본다.
 */
@Slf4j
@Component
public class LogFileLocator {

  public static final String DEPLOY_HISTORY = "deploy-history.log";
  static final String CURRENT_FILE = "elum.log";
  static final String CURRENT_ERROR_FILE = "elum-error.log";

  private static final String ROLLED = "(\\.\\d{4}-\\d{2}-\\d{2}\\.\\d+)";
  private static final Pattern INSTANCE_FILE =
    Pattern.compile("^(blue|green|local)/(elum(?:-error)?" + ROLLED + "?\\.log(?:\\.gz)?)$");
  private static final Pattern INSTANCE_FILE_NAME =
    Pattern.compile("^elum(?:-error)?" + ROLLED + "?\\.log(?:\\.gz)?$");
  private static final Pattern LEGACY_FILE =
    Pattern.compile("^elum-server" + ROLLED + "?\\.log(?:\\.gz)?$");
  private static final List<String> INSTANCES = List.of(LogInstance.BLUE, LogInstance.GREEN, LogInstance.LOCAL);

  private final Path root;
  private final String instance;

  // logback-spring.xml 과 같은 ELUM_LOG_DIR · ELUM_INSTANCE 를 읽는다 — 쓰는 쪽과 읽는 쪽이 함께 움직인다.
  public LogFileLocator(
    @Value("${ELUM_LOG_DIR:logs}") String logDir,
    @Value("${ELUM_INSTANCE:local}") String instance
  ) {
    this.root = Path.of(logDir).toAbsolutePath().normalize();
    this.instance = LogInstance.normalize(instance);
  }

  public Path root() {
    return root;
  }

  public String instance() {
    return instance;
  }

  public Optional<String> oppositeInstance() {
    return LogInstance.opposite(instance);
  }

  public String currentLogPath() {
    return instance + "/" + CURRENT_FILE;
  }

  /** 모양을 검사해 실제 경로로 바꾼다. 파일이 있는지는 보지 않는다. */
  public Path resolve(String relativePath) {
    if (relativePath == null || !isKnownShape(relativePath)) {
      throw new CustomException(ErrorCode.INVALID_LOG_PATH);
    }
    Path resolved = root.resolve(relativePath).normalize();
    if (!resolved.startsWith(root) || resolved.equals(root)) {
      throw new CustomException(ErrorCode.INVALID_LOG_PATH);
    }
    // 폴더나 파일이 링크면 로그 폴더 밖을 가리킬 수 있다.
    Path parent = resolved.getParent();
    if (Files.isSymbolicLink(resolved) || (!parent.equals(root) && Files.isSymbolicLink(parent))) {
      throw new CustomException(ErrorCode.INVALID_LOG_PATH);
    }
    return resolved;
  }

  public Path resolveExisting(String relativePath) {
    Path resolved = resolve(relativePath);
    if (!Files.isRegularFile(resolved, LinkOption.NOFOLLOW_LINKS)) {
      throw new CustomException(ErrorCode.LOG_FILE_NOT_FOUND);
    }
    return resolved;
  }

  /**
   * 지금 쓰이고 있을 수 있는 파일은 지우지 않는다. 배포 중에는 반대 색 JVM도 자기 elum.log 에 쓰므로
   * 색과 무관하게 elum.log · elum-error.log 를 막는다. 롤링된 파일과 이전 형식만 지울 수 있다.
   */
  public boolean isDeletable(String relativePath) {
    if (relativePath == null) {
      return false;
    }
    Matcher matcher = INSTANCE_FILE.matcher(relativePath);
    if (matcher.matches()) {
      return matcher.group(3) != null;
    }
    return LEGACY_FILE.matcher(relativePath).matches();
  }

  public LogFileListResponse list() {
    List<Group> groups = new ArrayList<>();
    groups.add(instanceGroup(instance, "지금 응답 중 (" + instance + ")"));
    oppositeInstance().ifPresent(other -> groups.add(instanceGroup(other, "직전 배포 (" + other + ")")));
    for (String other : INSTANCES) {
      boolean alreadyListed = other.equals(instance) || oppositeInstance().map(other::equals).orElse(false);
      if (!alreadyListed) {
        Group group = instanceGroup(other, other);
        if (!group.files().isEmpty()) {
          groups.add(group);
        }
      }
    }
    Group legacy = rootGroup("legacy", "이전 형식", name -> LEGACY_FILE.matcher(name).matches());
    if (!legacy.files().isEmpty()) {
      groups.add(legacy);
    }
    Group history = rootGroup("history", "배포 이력", DEPLOY_HISTORY::equals);
    if (!history.files().isEmpty()) {
      groups.add(history);
    }
    long total = groups.stream().mapToLong(Group::totalBytes).sum();
    return new LogFileListResponse(instance, total, groups);
  }

  private boolean isKnownShape(String relativePath) {
    return INSTANCE_FILE.matcher(relativePath).matches()
      || LEGACY_FILE.matcher(relativePath).matches()
      || DEPLOY_HISTORY.equals(relativePath);
  }

  private Group instanceGroup(String name, String label) {
    Path dir = root.resolve(name);
    List<FileItem> files = listFiles(dir, name + "/", fileName -> INSTANCE_FILE_NAME.matcher(fileName).matches());
    return new Group(name, label, files.stream().mapToLong(FileItem::size).sum(), files);
  }

  private Group rootGroup(String key, String label, Predicate<String> nameFilter) {
    List<FileItem> files = listFiles(root, "", nameFilter);
    return new Group(key, label, files.stream().mapToLong(FileItem::size).sum(), files);
  }

  private List<FileItem> listFiles(Path dir, String prefix, Predicate<String> nameFilter) {
    if (!Files.isDirectory(dir, LinkOption.NOFOLLOW_LINKS)) {
      return List.of();
    }
    try (Stream<Path> stream = Files.list(dir)) {
      return stream
        .filter(path -> Files.isRegularFile(path, LinkOption.NOFOLLOW_LINKS))
        .filter(path -> nameFilter.test(path.getFileName().toString()))
        .map(path -> toItem(path, prefix + path.getFileName()))
        .flatMap(Optional::stream)
        .sorted(Comparator.comparing(FileItem::lastModified).reversed())
        .toList();
    } catch (IOException e) {
      log.warn("[관리자 로그] 폴더 목록 읽기 실패: dir={}", dir, e);
      throw new CustomException(ErrorCode.LOG_FILE_READ_FAILED);
    }
  }

  // 목록을 읽는 사이 롤링으로 파일이 사라질 수 있다. 그 한 건만 빼고 나머지는 보여준다.
  private Optional<FileItem> toItem(Path path, String relativePath) {
    try {
      boolean deletable = isDeletable(relativePath);
      return Optional.of(new FileItem(
        relativePath,
        path.getFileName().toString(),
        Files.size(path),
        Files.getLastModifiedTime(path).toInstant(),
        relativePath.endsWith(".gz"),
        !deletable && !DEPLOY_HISTORY.equals(relativePath),
        deletable
      ));
    } catch (IOException e) {
      log.debug("[관리자 로그] 목록 중 사라진 파일: {}", path);
      return Optional.empty();
    }
  }
}
