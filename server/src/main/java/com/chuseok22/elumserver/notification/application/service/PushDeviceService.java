package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.CurrentLocale;
import com.chuseok22.elumserver.notification.application.dto.request.PushDeviceRegisterRequest;
import com.chuseok22.elumserver.notification.core.NotificationTime;
import com.chuseok22.elumserver.notification.infrastructure.entity.PushDevice;
import com.chuseok22.elumserver.notification.infrastructure.repository.PushDeviceRepository;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/// 푸시 기기: 등록(토큰 소유자 이전 포함), 해제, 연결 끊긴 이룸이 기기 정리
/// linkId: 이룸이 기기면 연결 ID (토큰에서 읽은 값만), 보호자 기기면 null
@Service
public class PushDeviceService {

  // 유니크 인덱스(btree)가 약 2.7KB 를 넘으면 실패하므로 컬럼 길이(4096)보다 낮게 막는다
  static final int TOKEN_MAX_LENGTH = 2048;
  private static final ZoneId NOTIFICATION_ZONE = NotificationTime.ZONE_ID;

  private final PushDeviceRepository pushDeviceRepository;
  private final Clock clock;

  @Autowired
  public PushDeviceService(PushDeviceRepository pushDeviceRepository) {
    this(pushDeviceRepository, Clock.system(NOTIFICATION_ZONE));
  }

  PushDeviceService(PushDeviceRepository pushDeviceRepository, Clock clock) {
    this.pushDeviceRepository = pushDeviceRepository;
    this.clock = clock;
  }

  /// 보호자 기기 등록
  @Transactional
  public void register(String memberId, PushDeviceRegisterRequest request) {
    register(memberId, null, request);
  }

  /// 기기 등록: 토큰 검사 > 같은 토큰 있으면 소유자·기기 종류·언어·시각 갱신, 없으면 새 행
  /// 한 기기는 한때 한 역할이라 마지막 등록이 이김 (보호자 > 이룸이로 바뀌면 보호자 푸시 끊김)
  @Transactional
  public void register(String memberId, String linkId, PushDeviceRegisterRequest request) {
    // 토큰 검사 (null, 공백, 길이)
    if (request == null || request.token() == null || request.token().isBlank()
      || request.token().length() > TOKEN_MAX_LENGTH || request.platform() == null) {
      throw new CustomException(ErrorCode.PUSH_TOKEN_INVALID);
    }

    // 같은 토큰이 다른 회원 것이면 그대로 이전 (기기 주인이 바뀐 경우)
    PushDevice device = pushDeviceRepository.findByToken(request.token()).orElseGet(PushDevice::new);
    device.setMemberId(memberId);
    device.setLinkId(linkId);
    device.setToken(request.token());
    device.setPlatform(request.platform());
    device.setLocale(CurrentLocale.get());
    device.setLastRegisteredAt(LocalDateTime.now(clock));
    pushDeviceRepository.save(device);
  }

  /// 관리자 회원 상세: 이 회원의 푸시 기기 전부 (마지막 등록 최신순)
  @Transactional(readOnly = true)
  public List<PushDevice> devicesOf(String memberId) {
    return pushDeviceRepository.findAllByMemberId(memberId).stream()
      .sorted(Comparator.comparing(PushDevice::getLastRegisteredAt, Comparator.nullsLast(Comparator.reverseOrder())))
      .toList();
  }

  /// 보호자 기기 해제
  @Transactional
  public void unregister(String memberId, String token) {
    unregister(memberId, null, token);
  }

  /// 기기 해제: 회원·기기 종류가 모두 같을 때만 지움 (이룸이 기기가 같은 회원의 보호자 토큰을 못 지움)
  @Transactional
  public void unregister(String memberId, String linkId, String token) {
    pushDeviceRepository.findByToken(token)
      .filter(device -> memberId.equals(device.getMemberId()))
      .filter(device -> Objects.equals(linkId, device.getLinkId()))
      .ifPresent(pushDeviceRepository::delete);
  }

  /// 연결 끊김: 그 이룸이 기기 토큰 전부 삭제 > 지운 수
  @Transactional
  public int removeLinkDevices(String linkId) {
    if (linkId == null) {
      return 0;
    }
    return pushDeviceRepository.deleteAllByLinkId(linkId);
  }
}
