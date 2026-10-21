package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.link.infrastructure.entity.DeviceLink;
import java.time.LocalDateTime;
import java.util.Map;

/**
 * 관리자 회원 상세: 이룸이 기기 연결(또는 연결 암호 발급) 한 줄 (암호 원문은 서버에 없어 표시하지 않음)
 *
 * @param linkedByName  암호를 낸 보호자 이름. 이룸이에서 나간 사람이면 null
 * @param deviceName    이룸이 기기 모델명. 옛 앱이 연결했으면 null
 * @param lastSessionAt 그 기기에 마지막으로 토큰을 발급한 시각 (마지막 접속에 가까움). 기록이 없으면 null
 */
public record AdminDeviceLinkLine(
  String id,
  AdminDeviceLinkStatus status,
  String linkedByMemberId,
  String linkedByName,
  String deviceName,
  LocalDateTime issuedAt,
  LocalDateTime expiresAt,
  LocalDateTime linkedAt,
  LocalDateTime revokedAt,
  int failedAttempts,
  LocalDateTime lastSessionAt
) {

  /** 연결 행 + 보호자 이름표(memberId > 이름) + 마지막 접속 시각 > 한 줄 */
  public static AdminDeviceLinkLine of(
    DeviceLink link, Map<String, String> nameByMemberId, LocalDateTime lastSessionAt, LocalDateTime now
  ) {
    return new AdminDeviceLinkLine(
      link.getId(),
      AdminDeviceLinkStatus.of(link, now),
      link.getMemberId(),
      nameByMemberId.get(link.getMemberId()),
      link.getDeviceName(),
      link.getCreatedAt(),
      link.getExpiresAt(),
      link.getRedeemedAt(),
      link.getRevokedAt(),
      link.getFailedAttempts(),
      lastSessionAt
    );
  }

  /** 관리자가 끊을 수 있는 줄인가 (지금 연결됨) */
  public boolean canUnlink() {
    return status == AdminDeviceLinkStatus.LINKED;
  }
}
