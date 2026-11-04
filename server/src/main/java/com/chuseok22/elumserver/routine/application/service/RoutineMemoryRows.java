package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemory;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryRepository;
import jakarta.persistence.EntityManager;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * 이룸이 메모 행 찾기/만들기 (#1082). 부르는 쪽 트랜잭션 안에서만 씀
 * 이룸이는 참조만 걸어 member 도메인 저장소를 직접 쓰지 않음 (이룸이 존재·권한은 부르는 쪽이 이미 확인)
 */
@Component
@RequiredArgsConstructor
class RoutineMemoryRows {

  private final RoutineMemoryRepository routineMemoryRepository;
  private final EntityManager entityManager;

  RoutineMemory findOrCreate(String profileId) {
    return routineMemoryRepository.findByProfileId(profileId).orElseGet(() -> {
      RoutineMemory created = new RoutineMemory();
      created.setProfile(entityManager.getReference(Profile.class, profileId));
      return routineMemoryRepository.save(created);
    });
  }
}
