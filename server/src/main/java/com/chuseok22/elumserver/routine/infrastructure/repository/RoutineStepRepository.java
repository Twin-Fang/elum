package com.chuseok22.elumserver.routine.infrastructure.repository;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

/**
 * 카드 한 장만 집어 고칠 때 쓴다.
 *
 * <p>추가한 카드의 이미지 경로를 나중에 채우는 경로에서 필요하다. 그때는 일과 전체를
 * 들고 있을 필요가 없고, 카드가 그새 지워졌을 수도 있다.
 */
public interface RoutineStepRepository extends JpaRepository<RoutineStep, String> {

  /**
   * 그림 경로만 채운다.
   *
   * <p>그림은 커밋 뒤 다른 스레드에서 만들어져 트랜잭션이 없다. 엔티티를 읽어 setter 로 고치면 읽기가
   * 끝나는 순간 분리돼 아무것도 저장되지 않는다. 한 줄 UPDATE 로 저장하고, 고친 행 수로 카드가 그새
   * 지워졌는지 안다.
   *
   * <p><b>그림이 비어 있을 때만 채운다</b>. 보호자가 찍은 사진으로 이미 바꿨는데 늦게 도착한
   * AI 그림이 덮으면 사진이 사라진다. 반환 0 은 "카드가 지워졌거나 이미 그림이 있다" 둘 중 하나다.
   */
  @Transactional
  @Modifying
  @Query("update RoutineStep s set s.imagePath = :imagePath where s.id = :stepId and s.imagePath is null")
  int updateImagePath(@Param("stepId") String stepId, @Param("imagePath") String imagePath);

  /**
   * 다른 카드가 같은 그림 파일을 가리키는지 본다.
   *
   * <p>일과 복제는 그림 파일을 새로 만들지 않고 같은 열쇠를 공유한다. 옛 그림을 지우기 전에 이것으로
   * 확인하지 않으면 복제본의 그림이 깨진다.
   */
  boolean existsByImagePathAndIdNot(String imagePath, String id);

  /**
   * 카드가 쓰는 그림 열쇠 전체 (쓰지 않는 그림 정리용, #1216)
   */
  @Query("select s.imagePath from RoutineStep s where s.imagePath is not null")
  List<String> findAllImagePaths();

  /**
   * 카드가 쓰는 그림 후보 열쇠 전체 (쓰지 않는 그림 정리용, #1216)
   */
  @Query("select s.imageCandidatePath from RoutineStep s where s.imageCandidatePath is not null")
  List<String> findAllImageCandidatePaths();

  // 보호자 목소리 열쇠를 아직 가리키는 카드가 있는가 (일과 복제는 같은 열쇠를 공유, #787)
  boolean existsByGuardianVoicePath(String guardianVoicePath);

  /**
   * 음성 열쇠 저장 (트랜잭션 없는 대기열 스레드용 한 줄 UPDATE). 0 이면 그새 단계가 지워짐
   */
  @Transactional
  @Modifying
  @Query("update RoutineStep s set s.speechPath = :speechPath where s.id = :stepId")
  int updateSpeechPath(@Param("stepId") String stepId, @Param("speechPath") String speechPath);

  /**
   * 합성에 쓴 제목·설명이 지금도 같을 때만 열쇠 저장. 0 이면 그새 글이 바뀌었거나 단계가 지워짐
   * 확인과 저장을 한 문장으로 묶어 그 사이에 끼어든 글 수정이 옛 음성을 붙이지 못하게 함
   * 제목 null 은 빈 문자열로 비교 (JPQL null 파라미터 타입 모호성 회피)
   */
  @Transactional
  @Modifying
  @Query("update RoutineStep s set s.speechPath = :speechPath where s.id = :stepId "
    + "and s.description = :description and coalesce(s.title, '') = :title")
  int updateSpeechPathIfTextUnchanged(
    @Param("stepId") String stepId, @Param("speechPath") String speechPath,
    @Param("title") String titleOrEmpty, @Param("description") String description);

  /**
   * 음성을 만들 문장 재료: 제목, 설명, 일과 언어 (지연 로딩 없이 한 번에)
   */
  @Query("select s.title as title, s.description as description, r.language as language "
    + "from RoutineStep s join s.routine r where s.id = :stepId")
  Optional<SpeechTextSource> findSpeechTextSource(@Param("stepId") String stepId);

  /**
   * 음성이 빠진 단계 id (주기 작업용, 최근 단계 먼저)
   */
  @Query("select s.id from RoutineStep s join s.routine r "
    + "where s.speechPath is null and s.description <> '' and r.language = :language "
    + "order by s.createdAt desc")
  List<String> findIdsMissingSpeech(@Param("language") AppLocale language, Pageable pageable);

  /**
   * 아직 WAV 로 저장된 음성 (압축 전환용, #1211). 최근 단계 먼저
   */
  @Query("select s.id as stepId, s.speechPath as speechPath from RoutineStep s "
    + "where s.speechPath like '%.wav' order by s.createdAt desc")
  List<StoredSpeechPath> findWavSpeechPaths(Pageable pageable);

  /**
   * 열쇠가 지금도 옛 열쇠일 때만 새 열쇠로 교체 (#1211). 0 이면 그새 글 수정·삭제로 열쇠가 바뀜
   */
  @Transactional
  @Modifying
  @Query("update RoutineStep s set s.speechPath = :newSpeechPath where s.id = :stepId and s.speechPath = :oldSpeechPath")
  int replaceSpeechPath(
    @Param("stepId") String stepId, @Param("oldSpeechPath") String oldSpeechPath,
    @Param("newSpeechPath") String newSpeechPath);

  /// 저장된 음성 열쇠 projection: 단계 id, 열쇠
  interface StoredSpeechPath {

    String getStepId();

    String getSpeechPath();
  }

  /**
   * 카드가 쓰는 음성 열쇠 전체 (쓰지 않는 파일 정리용, #1212)
   */
  @Query("select s.speechPath from RoutineStep s where s.speechPath is not null")
  List<String> findAllSpeechPaths();

  /// 음성 문장 재료 projection
  interface SpeechTextSource {

    String getTitle();

    String getDescription();

    AppLocale getLanguage();
  }
}
