package com.chuseok22.elumserver.talk.infrastructure.repository;

import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPostStep;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TalkPostStepRepository extends JpaRepository<TalkPostStep, String> {
}
