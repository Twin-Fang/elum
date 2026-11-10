package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemorySetting;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemorySettingRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/// (이룸이, 보호자)별 AI 메모리 켜짐: 행이 없으면 켜짐. 쓰기는 부르는 쪽 트랜잭션 안에서
@Component
@RequiredArgsConstructor
public class RoutineMemorySettings {

  private final RoutineMemorySettingRepository routineMemorySettingRepository;

  public boolean isEnabled(String profileId, String memberId) {
    return routineMemorySettingRepository.findByProfileIdAndMemberId(profileId, memberId)
      .map(RoutineMemorySetting::isEnabled)
      .orElse(true);
  }

  void setEnabled(String profileId, String memberId, boolean isEnabled) {
    RoutineMemorySetting setting = routineMemorySettingRepository.findByProfileIdAndMemberId(profileId, memberId)
      .orElseGet(() -> {
        RoutineMemorySetting created = new RoutineMemorySetting();
        created.setProfileId(profileId);
        created.setMemberId(memberId);
        return created;
      });
    setting.setEnabled(isEnabled);
    routineMemorySettingRepository.save(setting);
  }
}
