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
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/// 보호자 푸시 기기: 등록(토큰 소유자 이전 포함), 해제
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

  /// 기기 등록: 토큰 검사 > 같은 토큰 있으면 소유자·언어·시각 갱신, 없으면 새 행
  @Transactional
  public void register(String memberId, PushDeviceRegisterRequest request) {
    // 토큰 검사 (null, 공백, 길이)
    if (request == null || request.token() == null || request.token().isBlank()
      || request.token().length() > TOKEN_MAX_LENGTH || request.platform() == null) {
      throw new CustomException(ErrorCode.PUSH_TOKEN_INVALID);
    }

    // 같은 토큰이 다른 회원 것이면 그대로 이전 (기기 주인이 바뀐 경우)
    PushDevice device = pushDeviceRepository.findByToken(request.token()).orElseGet(PushDevice::new);
    device.setMemberId(memberId);
    device.setToken(request.token());
    device.setPlatform(request.platform());
    device.setLocale(CurrentLocale.get());
    device.setLastRegisteredAt(LocalDateTime.now(clock));
    pushDeviceRepository.save(device);
  }

  /// 기기 해제: 내 토큰일 때만 지운다 (남의 토큰·없는 토큰은 아무 일 없음)
  @Transactional
  public void unregister(String memberId, String token) {
    pushDeviceRepository.findByToken(token)
      .filter(device -> memberId.equals(device.getMemberId()))
      .ifPresent(pushDeviceRepository::delete);
  }
}
