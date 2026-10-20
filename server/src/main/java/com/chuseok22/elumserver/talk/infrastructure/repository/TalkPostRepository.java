package com.chuseok22.elumserver.talk.infrastructure.repository;

import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import com.chuseok22.elumserver.talk.core.TalkPostStatus;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TalkPostRepository extends JpaRepository<TalkPost, String> {

  // 같은 원본으로 올린 글이 이미 있는가 (원본 하나당 보이는 글은 하나)
  boolean existsBySourceRoutineIdAndStatus(String sourceRoutineId, TalkPostStatus status);
}
