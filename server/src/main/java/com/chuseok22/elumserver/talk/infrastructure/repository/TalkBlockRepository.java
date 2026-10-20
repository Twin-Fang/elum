package com.chuseok22.elumserver.talk.infrastructure.repository;

import com.chuseok22.elumserver.talk.infrastructure.entity.TalkBlock;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TalkBlockRepository extends JpaRepository<TalkBlock, String> {
}
