package com.chuseok22.elumserver.talk.infrastructure.repository;

import com.chuseok22.elumserver.talk.infrastructure.entity.TalkComment;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TalkCommentRepository extends JpaRepository<TalkComment, String> {
}
