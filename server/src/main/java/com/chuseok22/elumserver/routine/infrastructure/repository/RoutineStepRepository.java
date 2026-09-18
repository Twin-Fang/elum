package com.chuseok22.elumserver.routine.infrastructure.repository;

import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 카드 한 장만 집어 고칠 때 쓴다 (이슈 #199).
 *
 * <p>추가한 카드의 이미지 경로를 나중에 채우는 경로에서 필요하다. 그때는 일과 전체를
 * 들고 있을 필요가 없고, 카드가 그새 지워졌을 수도 있다.
 */
public interface RoutineStepRepository extends JpaRepository<RoutineStep, String> {

}
