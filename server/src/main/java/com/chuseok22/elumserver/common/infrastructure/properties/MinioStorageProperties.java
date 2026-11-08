package com.chuseok22.elumserver.common.infrastructure.properties;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * MinIO 이미지 저장소 설정: 접속 주소, 전용 계정, 버킷, 로컬 읽기 대체
 *
 * @param fallbackToLocal MinIO 에 없는 그림을 로컬 폴더에서 읽을지 (복사 검증 전 true)
 */
@ConfigurationProperties(prefix = "elum.store.minio")
public record MinioStorageProperties(
  String endpoint, String accessKey, String secretKey, String bucket, boolean fallbackToLocal
) {

  // 키가 로그에 찍히지 않게 가림
  @Override
  public String toString() {
    return "MinioStorageProperties[endpoint=" + endpoint + ", bucket=" + bucket
      + ", fallbackToLocal=" + fallbackToLocal + "]";
  }
}
