package com.chuseok22.elumserver.talk.infrastructure.repository;

import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPostStep;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TalkPostStepRepository extends JpaRepository<TalkPostStep, String> {

  List<TalkPostStep> findByPostIdOrderByStepOrderAsc(String postId);

  // 여러 글의 앞쪽 카드 (stepOrder 는 0부터 이어짐)
  List<TalkPostStep> findByPostIdInAndStepOrderLessThanOrderByStepOrderAsc(Collection<String> postIds, int stepOrder);

  Optional<TalkPostStep> findByPostIdAndStepOrder(String postId, int stepOrder);
}
