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
   * 지워졌는지 안다.
   *
   * <p><b>그림이 비어 있을 때만 채운다</b> (이슈 #455). 보호자가 찍은 사진으로 이미 바꿨는데 늦게 도착한
   * AI 그림이 덮으면 사진이 사라진다. 반환 0 은 "카드가 지워졌거나 이미 그림이 있다" 둘 중 하나다.
   */
  @Transactional
  @Modifying
  @Query("update RoutineStep s set s.imagePath = :imagePath where s.id = :stepId and s.imagePath is null")
  int updateImagePath(@Param("stepId") String stepId, @Param("imagePath") String imagePath);

  /**
   * 다른 카드가 같은 그림 파일을 가리키는지 본다 (이슈 #455).
   *
   * <p>일과 복제는 그림 파일을 새로 만들지 않고 같은 열쇠를 공유한다. 옛 그림을 지우기 전에 이것으로
   * 확인하지 않으면 복제본의 그림이 깨진다.
   */
  boolean existsByImagePathAndIdNot(String imagePath, String id);
}
