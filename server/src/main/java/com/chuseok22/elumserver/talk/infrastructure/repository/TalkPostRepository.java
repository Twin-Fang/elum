package com.chuseok22.elumserver.talk.infrastructure.repository;

import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TalkPostRepository extends JpaRepository<TalkPost, String> {
}
