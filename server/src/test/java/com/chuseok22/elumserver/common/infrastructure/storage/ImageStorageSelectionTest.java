package com.chuseok22.elumserver.common.infrastructure.storage;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.infrastructure.properties.MinioStorageProperties;
import com.chuseok22.elumserver.common.infrastructure.properties.NoticeProperties;
import com.chuseok22.elumserver.common.infrastructure.properties.RoutineProperties;
import com.chuseok22.elumserver.common.infrastructure.properties.TalkProperties;
import com.chuseok22.elumserver.notice.infrastructure.storage.LocalFileNoticeImageStorage;
import com.chuseok22.elumserver.notice.infrastructure.storage.MinioNoticeImageStorage;
import com.chuseok22.elumserver.notice.infrastructure.storage.NoticeImageStorage;
import com.chuseok22.elumserver.routine.infrastructure.storage.LocalFileRoutineImageStorage;
import com.chuseok22.elumserver.routine.infrastructure.storage.MinioRoutineImageStorage;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import com.chuseok22.elumserver.talk.infrastructure.storage.LocalFileTalkImageStorage;
import com.chuseok22.elumserver.talk.infrastructure.storage.MinioTalkImageStorage;
import com.chuseok22.elumserver.talk.infrastructure.storage.TalkImageStorage;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;

/**
 * 설정 하나로 저장소 3개가 함께 바뀌는지: 구현체가 둘 등록되면 서버가 뜨지 못함
 */
class ImageStorageSelectionTest {

  private final ApplicationContextRunner contextRunner = new ApplicationContextRunner()
    .withUserConfiguration(StorageBeans.class);

  @Test
  @DisplayName("설정이 없으면 지금처럼 로컬 구현이 쓰여 배포만으로 동작이 바뀌지 않는다")
  void noSetting_usesLocal() {
    contextRunner.run(context -> {
      assertThat(context.getBean(RoutineImageStorage.class)).isInstanceOf(LocalFileRoutineImageStorage.class);
      assertThat(context.getBean(TalkImageStorage.class)).isInstanceOf(LocalFileTalkImageStorage.class);
      assertThat(context.getBean(NoticeImageStorage.class)).isInstanceOf(LocalFileNoticeImageStorage.class);
      assertThat(context).doesNotHaveBean(ObjectStore.class);
    });
  }

  @Test
  @DisplayName("minio 를 고르면 저장소 3개가 함께 MinIO 구현으로 바뀐다")
  void minioSetting_usesMinioForAll() {
    contextRunner
      .withPropertyValues("elum.store.image=minio", "elum.store.minio.endpoint=http://127.0.0.1:1",
        "elum.store.minio.access-key=user", "elum.store.minio.secret-key=secret", "elum.store.minio.bucket=elum")
      .run(context -> {
        assertThat(context.getBean(RoutineImageStorage.class)).isInstanceOf(MinioRoutineImageStorage.class);
        assertThat(context.getBean(TalkImageStorage.class)).isInstanceOf(MinioTalkImageStorage.class);
        assertThat(context.getBean(NoticeImageStorage.class)).isInstanceOf(MinioNoticeImageStorage.class);
      });
  }

  @Test
  @DisplayName("minio 를 골랐는데 접속 정보가 비면 잘못된 상태로 뜨지 않고 기동이 실패한다")
  void minioSettingWithoutCredentials_failsStartup() {
    contextRunner
      .withPropertyValues("elum.store.image=minio", "elum.store.minio.endpoint=http://127.0.0.1:1")
      .run(context -> assertThat(context).hasFailed());
  }

  @Configuration
  @EnableConfigurationProperties({
    MinioStorageProperties.class, RoutineProperties.class, TalkProperties.class, NoticeProperties.class})
  @Import({
    MinioObjectStore.class,
    LocalFileRoutineImageStorage.class, LocalFileTalkImageStorage.class, LocalFileNoticeImageStorage.class,
    MinioRoutineImageStorage.class, MinioTalkImageStorage.class, MinioNoticeImageStorage.class})
  static class StorageBeans {
  }
}
