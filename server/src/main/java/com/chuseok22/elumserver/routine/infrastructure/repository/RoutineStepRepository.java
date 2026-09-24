package com.chuseok22.elumserver.routine.infrastructure.repository;

import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

/**
 * 카드 한 장만 집어 고칠 때 쓴다 (이슈 #199).
 *
 * <p>추가한 카드의 이미지 경로를 나중에 채우는 경로에서 필요하다. 그때는 일과 전체를
 * 들고 있을 필요가 없고, 카드가 그새 지워졌을 수도 있다.
 */
public interface RoutineStepRepository extends JpaRepository<RoutineStep, String> {

  /**
   * 그림 경로만 채운다 (이슈 #199, 다중 보호자 E18).
   *
   * <p>그림은 커밋 뒤 다른 스레드에서 만들어져 트랜잭션이 없다. 엔티티를 읽어 setter 로 고치면 읽기가
   * 끝나는 순간 분리돼 아무것도 저장되지 않는다. 한 줄 UPDATE 로 저장하고, 고친 행 수로 카드가 그새
   * 지워졌는지 안다 (0 이면 없다).
   */
  @Transactional
  @Modifying
  @Query("update RoutineStep s set s.imagePath = :imagePath where s.id = :stepId")
  int updateImagePath(@Param("stepId") String stepId, @Param("imagePath") String imagePath);
}
